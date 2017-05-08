#!/bin/bash

# render a template configuration file
# expand variables + preserve formatting
render_template() {
  eval "echo \"$(cat $1)\""
}

# Set SSL config variable if certs are available
sslConfig=""
if [ -e /etc/nginx/ssl/fullchain.pem ] && [ -s /etc/nginx/ssl/fullchain.pem ]
then
    sslConfig="    listen 443 ssl http2;

    ssl_protocols TLSv1.2;
    ssl_ciphers EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5;
    ssl_prefer_server_ciphers On;
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_trusted_certificate /etc/nginx/ssl/chain.pem;
    ssl_session_cache shared:SSL:128m;
    ssl_stapling on;
    ssl_stapling_verify on;"
fi

# Pull the http auth pwd for rethinkdb from etcd
rethinkdbpwd="$(/usr/bin/etcdctl get /rethinkdb/pwd)"

# Create the password file
echo -n 'admin:' > /usr/var/nginx/.htpasswd
echo $rethinkdbpwd | openssl passwd -stdin -apr1 >> /usr/var/nginx/.htpasswd

locations=""
upstreams=""
routes="$(/usr/bin/etcdctl ls /discovery)"
while read -r line; do
    # Break out of the loop, if nothing was registered under discovery
    if [[ $line == Error* ]]
    then
        break
    fi
    private="$(/usr/bin/etcdctl get /discovery/$line/private)"
    strip="$(/usr/bin/etcdctl get /discovery/$line/strip)"
    hosts="$(/usr/bin/etcdctl ls /discovery/$line/hosts)"
    upstream=""
    while read -r line2; do
        if [[ $line2 == Error* ]]
        then
            break
        fi
        upstream=$upstream$'\n'"        server $(/usr/bin/etcdctl get /discovery/$line/$line2/host):$(/usr/bin/etcdctl get /discovery/$line/$line2/port);"
    done <<< "$hosts"
    # If there were upstream host elements, concatenate them to the nginx upstreams element, and concatenate the location
    if [ -n "$upstream" ]
    then
       upstream="upstream $line {"$upstream$'\n'"    }"
       upstreams=$upstreams$'\n'$upstream$'\n'
       location=""
       if [ "$strip" = "true" ]
       then
           location="    location /$line/ {"
       else
           location="    location /$line {"
       fi
       location=$location$'\n'"        if (\$scheme = http) {"
       location=$location$'\n'"             return 301 https://\$server_name\$request_uri;"
       location=$location$'\n'"        }"
       if [ "$strip" = "true" ]
       then
           location=$location$'\n'"        proxy_pass http://$line/;"
       else
           location=$location$'\n'"        proxy_pass http://$line;"
       fi
       
       if [ "$private" = "true" ]
       then
           location=$location$'\n'"        auth_basic \"Restricted Content\";"
           location=$location$'\n'"        auth_basic_user_file /usr/var/nginx/.htpasswd;"
       fi
       location=$location$'\n'"    }"
       locations=$locations$'\n'$location$'\n'
    fi
done <<< "$routes"

# Pull the domain from etcd
domain="$(/usr/bin/etcdctl get /acme/domain)"
if [ $? -ne 0 ]
then
    domain="default"
fi

# Pull the thumbprint from etcd
thumbprint="$(/usr/bin/etcdctl get /acme/thumbprint)"
if [ $? -ne 0 ]
then
    thumbprint="default"
fi

# Pull the token from etcd
token="$(/usr/bin/etcdctl get /acme/token)"
if [ $? -ne 0 ]
then
    token="default"
fi

# Render the template with the values pulled
render_template /usr/var/nginx.conf.template > /usr/var/nginx/nginx.conf

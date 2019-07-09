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
routes="$(/usr/bin/etcdctl ls /route_discovery)"
if [ $? -eq 0 ]
then
    while read -r line; do
        if [ "$line" = "/route_discovery/watched" ]
        then
            continue
        fi
        private="$(/usr/bin/etcdctl get $line/private)"
        upstreamroute="$(/usr/bin/etcdctl get $line/upstreamRoute)"
        if [ $? -ne 0 ]
        then
            upstreamroute="";
        fi
        route=${line#/route_discovery/}
        upstream=""
        services="$(/usr/bin/etcdctl ls $line/services)"
        if [ $? -eq 0 ]
        then 
            while read -r line2; do
                host="$(/usr/bin/etcdctl get $line2/host)"
                if [ $? -ne 0 ]
                then
                    continue;
                fi
                port="$(/usr/bin/etcdctl get $line2/port)"
                if [ $? -ne 0 ]
                then
                    continue;
                fi
                upstream=$upstream$'\n'"        server $host:$port;"
            done <<< "$services"
        fi
        # If there were upstream host elements, concatenate them to the nginx upstreams element, and concatenate the location
        if [ -n "$upstream" ]
        then
            upstream="upstream $route {"$upstream$'\n'"    }"
            upstreams=$upstreams$'\n'$upstream$'\n'

            location="    location /$route$upstreamroute {"
            location=$location$'\n'"        if (\$scheme = http) {"
            location=$location$'\n'"             return 301 https://\$server_name\$request_uri;"
            location=$location$'\n'"        }"
            if [ "$strip" = "true" ]
            then
                location=$location$'\n'"        proxy_pass http://$route/;"
            else
                location=$location$'\n'"        proxy_pass http://$route;"
            fi
       
            if [ "$private" = "true" ]
            then
                location=$location$'\n'"        auth_basic \"Restricted Content\";"
                location=$location$'\n'"        auth_basic_user_file /usr/var/nginx/.htpasswd;"
                location=$location$'\n'"        proxy_set_header X-WEBAUTH-USER \$remote_user;"
                location=$location$'\n'"        proxy_set_header Authorization \"\";"
            fi
            location=$location$'\n'"    }"
            locations=$locations$'\n'$location$'\n'
        fi
    done <<< "$routes"
fi

# Pull the domain from etcd
domain="$(/usr/bin/etcdctl get /domain/name)"
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

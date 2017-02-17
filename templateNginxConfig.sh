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
sudo sh -c "echo -n 'admin:' >> /usr/var/nginx/.htpasswd"
sudo sh -c "openssl $rethinkdbpwd -apr1 >> /usr/var/nginx/.htpasswd"

# Pull the backend host(s) from etcd
backend_upstream="upstream backend {"
hosts="$(/usr/bin/etcdctl ls /discovery/backend)"
while read -r line; do
    backend_upstream=$backend_upstream$'\n'"        server "${line#/discovery/backend/}":8080;"
done <<< "$hosts"
backend_upstream=$backend_upstream$'\n'"    }"

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

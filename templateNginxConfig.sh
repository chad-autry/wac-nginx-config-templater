#!/bin/sh

# render a template configuration file
# expand variables + preserve formatting
render_template() {
  eval "echo \"$(cat $1)\""
}

# Pull the domain from etcd
domain= /usr/bin/etcdctl get /acme/domain
if [ $? -ne 0 ]
then
    domain="default"
fi

# Pull the thumbprint from etcd
thumbprint= /usr/bin/etcdctl get /acme/thumbprint
if [ $? -ne 0 ]
then
    thumbprint="default"
fi

# Pull the token from etcd
token= /usr/bin/etcdctl get /acme/token
if [ $? -ne 0 ]
then
    token="default"
fi

# Render the template with the values pulled
render_template /usr/var/nginx.conf.template > /usr/var/nginx.conf

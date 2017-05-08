# wac-nginx-config-templater
Configures nginx from a built in template and etcd values for the WAC stack

[Reference Article](https://letsecure.me/secure-web-deployment-with-lets-encrypt-and-nginx/)

### Status
[![Build Status](https://travis-ci.org/chad-autry/wac-nginx-config-templater.svg?branch=master)](https://travis-ci.org/chad-autry/wac-nginx-config-templater)
[![Docker Hub](https://img.shields.io/badge/docker-ready-blue.svg)](https://registry.hub.docker.com/u/chadautry/wac-nginx-config-templater/)

Discovers routes posted to etcd (watcher seperate)
```
/discovery/<route> : 
                 /private : true|false : Decides if a password is required to access the resource
                 /strip : true|false : Decides if the route key should be stripped before forwarding
                 /hosts
                      /<unique hostport id> : A list of hosts. Key doesn't matter other than that it is unique (which host and port is)
                                           /host : The host/ipaddress to route requests to
                                           /port : the port to route requests
```

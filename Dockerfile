FROM gliderlabs/alpine:3.4
RUN apk add --update curl
COPY templateNginxConfig.sh /usr/bin/templateNginxConfig.sh
RUN chmod +x /usr/bin/templateNginxConfig.sh
COPY nginx.conf.template /usr/var/nginx/nginx.conf.template
RUN curl -L https://github.com/coreos/etcd/releases/download/v2.3.7/etcd-v2.3.7-linux-amd64.tar.gz -o etcd-v2.3.7-linux-amd64.tar.gz
RUN tar xzvf etcd-v2.3.7-linux-amd64.tar.gz
RUN mv etcd-v2.3.7-linux-amd64/etcdctl /usr/bin/etcdctl
RUN rm -r etcd-v2.3.7-linux-amd64
RUN rm etcd-v2.3.7-linux-amd64.tar.gz
ENTRYPOINT ["/bin/sh", "/usr/bin/templateNginxConfig.sh", "start"]

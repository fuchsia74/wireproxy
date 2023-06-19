# Start by building the application.
FROM golang:1.18 as build

WORKDIR /usr/src/wireproxy
COPY . .

RUN export GO111MODULE=on && export GOPROXY=https://goproxy.cn && make

# Now copy it into our base image.
FROM alpine:3.18
COPY --from=build /usr/src/wireproxy/wireproxy /usr/bin/wireproxy
COPY wgproxy.sh /bin/wgproxy.sh
RUN mkdir /etc/wireproxy && chmod +x /bin/wgproxy.sh && \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add curl
VOLUME [ "/etc/wireproxy"]
ENTRYPOINT ["/bin/sh","/bin/wgproxy.sh"]


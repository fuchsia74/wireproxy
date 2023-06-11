# Start by building the application.
FROM golang:1.18 as build

WORKDIR /usr/src/wireproxy
COPY . .

RUN export GO111MODULE=on && export GOPROXY=https://goproxy.cn && make

# Now copy it into our base image.
FROM alpine:3.18
COPY --from=build /usr/src/wireproxy/wireproxy /usr/bin/wireproxy

RUN mkdir /etc/wireproxy
VOLUME [ "/etc/wireproxy"]
ENTRYPOINT [ "/usr/bin/wireproxy" ]
CMD [ "--config", "/etc/wireproxy/config" ]

LABEL org.opencontainers.image.title wireproxy
LABEL org.opencontainers.image.description "Wireguard client that exposes itself as a socks5 proxy"
LABEL org.opencontainers.image.licenses ISC

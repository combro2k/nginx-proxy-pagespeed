#!/bin/bash

if [ ! -z "$IPV6ADDR" ]; then
	echo  $IPV6ADDR
	ip -6 addr add "$IPV6ADDR" dev eth0
fi

sleep 2

if [ ! -z "$IPV6GW" ]; then
	echo $IPV6GW
	ip -6 route add  default via "$IPV6GW" dev eth0
fi

if [[ ! -d "/data/config" ]]; then
	mkdir -p /data/config
fi

if [[ ! -d "/data/ssl" ]]; then
	mkdir -p /data/ssl
fi

if [[ ! -e "/data/ssl/server.key" ]]; then
    openssl genrsa  -out server.key 4096
fi

if [[ ! -e "/data/ssl/server.csr" ]]; then
    RUN openssl req -new -batch -key server.key -out server.csr
fi

if [[ ! -e "/data/ssl/server.crt" ]]; then
    openssl x509 -req -days 10000 -in server.csr -signkey server.key -out server.crt
fi

if [[ ! -e "/data/ssl/dhparam.pem" ]]; then
    openssl dhparam -out dhparam.pem 4096
fi

if [[ ! -d "/data/logs" ]]; then
	mkdir -p /data/logs
fi

if [[ ! -e "/data/config/pagespeed-extra.conf" ]]; then
        touch /data/config/pagespeed-extra.conf
fi

if [[ ! -e "/data/config/proxy.conf" ]]; then
        touch /data/config/proxy.conf
fi

/usr/local/bin/forego start -r

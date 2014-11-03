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

if [[ ! -e "/data/config/pagespeed-extra.conf" ]]; then
	touch /data/config/pagespeed-extra.conf
fi

/usr/local/bin/forego start -r
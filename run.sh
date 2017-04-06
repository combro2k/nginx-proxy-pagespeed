#!/bin/bash

docker run -ti --rm --name nginx-proxy-pagespeed -p 80:80 -p 443:443 -v /var/run/docker.sock:/tmp/docker.sock:ro combro2k/nginx-proxy-pagespeed:libressl ${@}

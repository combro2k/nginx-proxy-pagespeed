#!/bin/bash

docker run -ti --rm --name nginx-proxy-pagespeed -v /var/run/docker.sock:/tmp/docker.sock:ro combro2k/nginx-proxy-pagespeed:libressl ${@}

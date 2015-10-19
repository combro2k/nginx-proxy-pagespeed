#!/bin/bash

docker run -ti --rm --name nginx-proxy-pagespeed combro2k/nginx-proxy-pagespeed:boringssl ${@}

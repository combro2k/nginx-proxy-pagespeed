FROM ubuntu:14.04
MAINTAINER Jason Wilder jwilder@litl.com

# Install Nginx.
RUN apt-get update &&  apt-get install nano git build-essential cmake zlib1g-dev libpcre3 libpcre3-dev unzip wget -y
RUN apt-get dist-upgrade -y

ENV NGINX_VERSION 1.7.9
ENV OPENSSL_VERSION openssl-1.0.2
ENV MODULESDIR /usr/src/nginx-modules
ENV NPS_VERSION 1.9.32.3

RUN mkdir -p ${MODULESDIR}
RUN mkdir -p /data/{config,ssl,logs}

RUN cd /usr/src/ && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar xf nginx-${NGINX_VERSION}.tar.gz && rm -f nginx-${NGINX_VERSION}.tar.gz
RUN cd /usr/src/ && wget http://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz && tar xvzf ${OPENSSL_VERSION}.tar.gz
RUN cd ${MODULESDIR} && git clone git://github.com/bpaquet/ngx_http_enhanced_memcached_module.git
RUN cd ${MODULESDIR} && git clone https://github.com/openresty/headers-more-nginx-module.git

RUN apt-get update && apt-get install -y build-essential zlib1g-dev libpcre3 libpcre3-dev unzip
RUN cd ${MODULESDIR} && \
    wget --no-check-certificate https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip && \
    unzip release-${NPS_VERSION}-beta.zip && \
    cd ngx_pagespeed-release-${NPS_VERSION}-beta/ && \
    wget --no-check-certificate https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz && \
    tar -xzvf ${NPS_VERSION}.tar.gz


# Compile nginx
RUN cd /usr/src/nginx-${NGINX_VERSION} && ./configure \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/data/logs/error.log \
	--http-log-path=/data/logs/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-file-aio \
	--with-http_spdy_module \
	--with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Wformat-security -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2' \
	--with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,--as-needed' \
	--with-ipv6 \
	--with-sha1='../${OPENSSL_VERSION}' \
 	--with-md5='../${OPENSSL_VERSION}' \
	--with-openssl='../${OPENSSL_VERSION}' \
	--add-module=${MODULESDIR}/ngx_pagespeed-release-${NPS_VERSION}-beta \
    	--add-module=${MODULESDIR}/ngx_http_enhanced_memcached_module \
    	--add-module=${MODULESDIR}/headers-more-nginx-module

RUN cd /usr/src/nginx-${NGINX_VERSION} && make && make install

RUN ln -s /data/ssl /etc/nginx/ssl

#Add custom nginx.conf file
ADD nginx.conf /etc/nginx/nginx.conf
ADD pagespeed.conf /etc/nginx/pagespeed.conf
ADD proxy_params /etc/nginx/proxy_params

WORKDIR /etc/nginx/ssl

RUN mkdir /app
WORKDIR /app
ADD ./app /app

RUN chmod u+x /app/init.sh

RUN wget -P /usr/local/bin https://godist.herokuapp.com/projects/ddollar/forego/releases/current/linux-amd64/forego
RUN chmod u+x /usr/local/bin/forego

ADD app/docker-gen docker-gen

EXPOSE 80 443
ENV DOCKER_HOST unix:///tmp/docker.sock

CMD ["/app/init.sh"]

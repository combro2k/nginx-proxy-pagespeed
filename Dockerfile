FROM ubuntu:14.04
MAINTAINER Jason Wilder jwilder@litl.com

# Install Nginx.
RUN apt-get update
RUN apt-get install -y wget
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62
RUN echo deb http://nginx.org/packages/mainline/ubuntu trusty nginx > /etc/apt/sources.list.d/nginx-stable-trusty.list
RUN echo deb-src http://nginx.org/packages/mainline/ubuntu trusty nginx > /etc/apt/sources.list.d/nginx-stable-trusty.list

RUN apt-get update &&  apt-get install nano git build-essential cmake zlib1g-dev libpcre3 libpcre3-dev unzip -y
RUN apt-get upgrade -y

ENV NGINX_VERSION 1.7.4
ENV MODULESDIR /usr/src/nginx-modules
ENV NPS_VERSION 1.8.31.4

RUN cd /usr/src/ && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar xf nginx-${NGINX_VERSION}.tar.gz && rm -f nginx-${NGINX_VERSION}.tar.gz
RUN cd /usr/src/ && git clone https://boringssl.googlesource.com/boringssl

# BoringSSL specifics
RUN cd /usr/src/ && wget --no-check-certificate https://calomel.org/boringssl_freebsd10_calomel.org.patch && cd /usr/src/boringssl && patch < ../boringssl_freebsd10_calomel.org.patch
RUN cd /usr/src/boringssl && mkdir build && cd build && cmake ../ && make && cd ..
RUN cd /usr/src/boringssl && mkdir -p .openssl/lib && cd .openssl && ln -s ../include && cd ..
RUN cd /usr/src/boringssl && cp build/crypto/libcrypto.a build/ssl/libssl.a .openssl/lib

RUN mkdir ${MODULESDIR}
RUN cd ${MODULESDIR} && \
    wget --no-check-certificate https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip && \
    unzip release-${NPS_VERSION}-beta.zip && \
    cd ngx_pagespeed-release-${NPS_VERSION}-beta/ && \
    wget --no-check-certificate https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz && \
    tar -xzvf ${NPS_VERSION}.tar.gz

RUN cd /usr/src/nginx-${NGINX_VERSION} && ./configure \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
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
	--with-file-aio \
	--with-ipv6 \
	--with-http_ssl_module \
	--with-http_spdy_module \
	--with-cc-opt="-I ../boringssl/.openssl/include/ -g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Wformat-security -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2" \
	--with-ld-opt="-L ../boringssl/.openssl/lib -Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,--as-needed" \
    --add-module=${MODULESDIR}/ngx_pagespeed-release-${NPS_VERSION}-beta

RUN cd /usr/src/nginx-${NGINX_VERSION} && make && make install

RUN mkdir -p /etc/nginx/ssl

#Add custom nginx.conf file
ADD nginx.conf /etc/nginx/nginx.conf
ADD pagespeed.conf /etc/nginx/pagespeed.conf
ADD proxy_params /etc/nginx/proxy_params

WORKDIR /etc/nginx/ssl

RUN openssl genrsa  -out server.key 4096
RUN openssl req -new -batch -key server.key -out server.csr
RUN openssl x509 -req -days 10000 -in server.csr -signkey server.key -out server.crt
RUN openssl dhparam -out dhparam.pem 4096

RUN mkdir -p /etc/nginx/sites-enabled

RUN mkdir /app
WORKDIR /app
ADD ./app /app

RUN wget -P /usr/local/bin https://godist.herokuapp.com/projects/ddollar/forego/releases/current/linux-amd64/forego
RUN chmod u+x /usr/local/bin/forego

ADD app/docker-gen docker-gen

EXPOSE 80 443
ENV DOCKER_HOST unix:///tmp/docker.sock

CMD ["/app/init.sh"]

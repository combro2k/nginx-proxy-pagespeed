#!/bin/bash

trap '{ echo -e "error ${?}\nthe command executing at the time of the error was\n${BASH_COMMAND}\non line ${BASH_LINENO[0]}" && tail -n 10 ${INSTALL_LOG} && exit $? }' ERR

declare -A NGX_MODULES
export DEBIAN_FRONTEND="noninteractive"

# Versions
export NGINX_VERSION="1.9.10"
export NPS_VERSION="1.10.33.4"
export DOCKER_GEN="0.5.0"

# Build options
export CFLAGS="-Wno-error"

# Packages
export PACKAGES=(
	'nano'
	'git'
	'build-essential'
	'cmake'
	'zlib1g'
	'zlib1g-dev'
	'libpcre3'
	'libpcre3-dev'
	'curl'
	'tar'
	'libpthread-stubs0-dev:amd64'
	'golang'
)

export NGX_MODULES=(
    ['ngx_http_enhanced_memcached_module']='https://github.com/bpaquet/ngx_http_enhanced_memcached_module.git'
    ['headers-more-nginx-module']='https://github.com/openresty/headers-more-nginx-module.git'
)

pre_install() {
	mkdir -p \
	    /app \
	    /usr/src/build \
	    /data/config \
	    /data/ssl \
	    /usr/local/go \
	    /data/logs 2>&1 || return 1

	apt-get update -q 2>&1 || return 1
	apt-get install -yq ${PACKAGES[@]} 2>&1 || return 1

    curl -L --silent https://godist.herokuapp.com/projects/ddollar/forego/releases/current/linux-amd64/forego --output /usr/local/bin/forego 2>&1 || return 1
    curl -L --silent https://github.com/jwilder/docker-gen/releases/download/${DOCKER_GEN}/docker-gen-linux-amd64-${DOCKER_GEN}.tar.gz | tar zx -C /app 2>&1 || return 1

    chmod +x /usr/local/bin/* || return 1

    return 0
}

install_nginx_modules() {
    mkdir -p /usr/src/build/nginx-modules/ngx_pagespeed || return 1

    echo "Installing ngx_pagespeed..." || return 1
    curl -L --silent https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.tar.gz | tar zx --strip-components=1 -C /usr/src/build/nginx-modules/ngx_pagespeed 2>&1  || return 1
    curl -L --silent https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz | tar zx -C /usr/src/build/nginx-modules/ngx_pagespeed 2>&1 || return 1

    cd /usr/src/build/nginx-modules/ngx_pagespeed || return 1

    ADD_MODULES="${ADD_MODULES} --add-module '/usr/src/build/nginx-modules/ngx_pagespeed'" || return 1

    cd /usr/src/build/nginx-modules || return 1
    for i in ${!NGX_MODULES[@]}
    do
        echo "Installing ${i}..." || return 1
        git clone -q "${NGX_MODULES[${i}]}" ./${i} 2>&1 || return 1
    done

    return 0
}

install_boringssl() {
    git clone -q "https://boringssl.googlesource.com/boringssl" /usr/src/build/boringssl || return 1

    cd /usr/src/build/boringssl || return 1

    mkdir build || return 1
    cd build || return 1

    cmake .. 2>&1 || return 1
    make 2>&1 || return 1

    cd /usr/src/build/boringssl || return 1

    mkdir -p .openssl/lib || return 1
    cd .openssl || return 1
    ln -s ../include . || return 1
    cd ../ || return 1
    cp build/crypto/libcrypto.a build/ssl/libssl.a .openssl/lib || return 1

    return 0
}

install_nginx() {
    ADD_MODULES=" --add-module=../nginx-modules/ngx_pagespeed"
    for i in ${!NGX_MODULES[@]}; do ADD_MODULES="${ADD_MODULES} --add-module=../nginx-modules/${i}"; done

    mkdir -p /usr/src/build/nginx || return 1
    curl -L --silent http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar zx --strip-components=1 -C /usr/src/build/nginx 2>&1 || return 1

    cd /usr/src/build/nginx || return 1

    patch -p0 < /usr/src/patches/nginx.patch || return 1

    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/data/logs/error.log \
        --http-log-path=/data/logs/access.log \
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
        --with-http_v2_module \
        --with-openssl=../boringssl \
        --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2' \
        --with-ld-opt='-Wl,-z,relro -Wl,--as-needed' \
        --user='www-data' \
        --group='www-data' \
        ${ADD_MODULES} || return 1

    touch -r Makefile ../boringssl/.openssl/include/openssl/ssl.h 2>&1 || return 1

    make 2>&1 || return 1
    make install 2>&1 || return 1

    return 0
}


post_install() {
    apt-get autoremove 2>&1 || return 1
	apt-get autoclean 2>&1 || return 1
	rm -fr /var/lib/apt /usr/src/build 2>&1 || return 1

	return 0
}

build() {
	if [ ! -f "${INSTALL_LOG}" ]
	then
		touch "${INSTALL_LOG}" || exit 1
	fi

	tasks=(
        'pre_install'
        'install_nginx_modules'
        'install_boringssl'
        'install_nginx'
	)

	for task in ${tasks[@]}
	do
		echo "Running build task ${task}..." || exit 1
		${task} | tee -a "${INSTALL_LOG}" || exit 1
	done
}

if [ $# -eq 0 ]
then
	echo "No parameters given! (${@})"
	echo "Available functions:"
	echo

	compgen -A function

	exit 1
else
	for task in ${@}
	do
		echo "Running ${task}..." 2>&1  || exit 1
		${task} || exit 1
	done
fi

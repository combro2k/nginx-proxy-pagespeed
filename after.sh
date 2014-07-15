#!/bin/bash
if  [ -d ".openssl" ]; then
  rm -Rf .openssl
fi

mkdir -p .openssl/lib

cp crypto/.libs/libcrypto.a ssl/.libs/libssl.a .openssl/lib
cd .openssl && ln -s ../include ./

# you might want to strip debugging-symbols
cd .openssl/lib && strip -g libssl.a  && strip -g libcrypto.a
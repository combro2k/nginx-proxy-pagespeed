#!/bin/bash

mkdir build && cd build && cmake ../ && make && cd ..
mkdir -p .openssl/lib
cd .openssl && ln -s ../include ./
cd ..
cp build/crypto/libcrypto.a build/ssl/libssl.a .openssl/lib
touch .openssl/include/ssl.h
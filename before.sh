#!/bin/bash

mkdir build && cd build && cmake ../ && make && cd ..
mkdir -p .openssl/lib
cd .openssl
ln -s include .openssl/
cd ..
cp build/crypto/libcrypto.a build/ssl/libssl.a .openssl/lib
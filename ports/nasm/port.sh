#!/bin/sh
set -e

. ../common.sh

VERSION=2.16.03
prep https://www.nasm.us/pub/nasm/releasebuilds/${VERSION}/nasm-${VERSION}.tar.xz nasm-${VERSION}.tar.xz nasm-${VERSION}

./configure --host=${ARCH}-pc-elf
make -j$(nproc)
make DESTDIR=$SYSROOT install

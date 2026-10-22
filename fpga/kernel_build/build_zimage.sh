#!/bin/bash
# Rebuild zImage to generate Module.symvers for external module builds.
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
mkdir -p "$TMPDIR"

KDIR=/d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38
TC=/d/websdr-trx-duo/fpga/kernel_build/toolchain/arm-gnu-toolchain-13.3.rel1-mingw-w64-i686-arm-none-linux-gnueabihf/bin
CROSS=$TC/arm-none-linux-gnueabihf-

export PATH="/c/msys64/usr/bin:$TC:/usr/bin:/bin"

cd "$KDIR"

# NOTE: host-tool prerequisites in scripts/Makefile.build:451 and
# scripts/Makefile.dtbs:91 were patched to use .exe explicitly because
# MSYS2 make 4.4.1 cannot resolve extension-less prerequisites and any
# extension-less copy gets deleted on relink. Do not create plain copies.

make KCFLAGS=-marm -j14 ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc HOSTCFLAGS="-I scripts/include" zImage
echo "ZIMAGE_EXIT=$?"

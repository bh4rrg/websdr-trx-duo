#!/bin/bash
# Build in-tree modules to generate Module.symvers for external module builds.
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
mkdir -p "$TMPDIR"

KDIR=/d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38
TC=/d/websdr-trx-duo/fpga/kernel_build/toolchain/arm-gnu-toolchain-13.3.rel1-mingw-w64-i686-arm-none-linux-gnueabihf/bin
CROSS=$TC/arm-none-linux-gnueabihf-

export PATH="/c/msys64/usr/bin:$TC:/usr/bin:/bin"

cd "$KDIR"

make KCFLAGS=-marm -j14 ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc HOSTCFLAGS="-I scripts/include" modules
echo "MODULES_EXIT=$?"

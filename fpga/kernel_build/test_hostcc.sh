#!/bin/bash
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
mkdir -p "$TMPDIR"
KDIR=/d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38
TC=/d/websdr-trx-duo/fpga/kernel_build/toolchain/arm-gnu-toolchain-13.3.rel1-mingw-w64-i686-arm-none-linux-gnueabihf/bin
CROSS=$TC/arm-none-linux-gnueabihf-
export PATH=/c/msys64/usr/bin:$TC:$PATH
cd "$KDIR"
echo "HOSTCC test:"
which gcc
gcc --version | head -1
echo "=== build fixdep verbose ==="
make ARCH=arm CROSS_COMPILE=$CROSS V=1 scripts_basic 2>&1 | tail -25

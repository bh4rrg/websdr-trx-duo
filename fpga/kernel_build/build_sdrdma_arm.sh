#!/bin/bash
set -e
export PATH="/c/msys64/usr/bin:/usr/bin:/bin:$PATH"
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
mkdir -p "$TMPDIR"

KDIR=/d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38
TC=/d/websdr-trx-duo/fpga/kernel_build/toolchain/arm-gnu-toolchain-13.3.rel1-mingw-w64-i686-arm-none-linux-gnueabihf/bin
CROSS=$TC/arm-none-linux-gnueabihf-
SRC=/d/websdr-trx-duo/fpga/kernel_build/sdrdma

export PATH="/c/msys64/usr/bin:$TC:/usr/bin:/bin"

cd "$SRC"

echo "=== clean ==="
make -C "$KDIR" M="$SRC" ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc HOSTCFLAGS="-I scripts/include" clean 2>&1 | tail -5

echo "=== build sdrdma.ko (-marm) ==="
make -C "$KDIR" M="$SRC" ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc HOSTCFLAGS="-I scripts/include" modules 2>&1 | tail -25
echo "BUILD_EXIT=${PIPESTATUS[0]}"

echo "=== result ==="
ls -la "$SRC"/*.ko
"$CROSS"readelf -h "$SRC/sdrdma.ko" | grep -E 'Flags|Machine'
echo "=== reloc types in built .ko ==="
"$CROSS"readelf -r "$SRC/sdrdma.ko" | grep -oE 'R_ARM_[A-Z0-9_]+' | sort | uniq -c

#!/bin/bash
set -e
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
mkdir -p "$TMPDIR"

KDIR=/d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38
TC=/d/websdr-trx-duo/fpga/kernel_build/toolchain/arm-gnu-toolchain-13.3.rel1-mingw-w64-i686-arm-none-linux-gnueabihf/bin
CROSS=$TC/arm-none-linux-gnueabihf-

# MSYS2 native gcc for HOSTCC (understands /d/... POSIX paths); msys tools; cross toolchain
export PATH="/c/msys64/usr/bin:$TC:/usr/bin:/bin"

cd "$KDIR"

echo "HOSTCC: $(which gcc)"; gcc --version | head -1

HFLAGS="-I scripts/include"

echo "=== clean stale fixdep ==="
rm -f scripts/basic/fixdep scripts/basic/.fixdep.cmd scripts/basic/.fixdep.d

echo "=== make xilinx_zynq_defconfig ==="
make ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc HOSTCFLAGS="$HFLAGS" xilinx_zynq_defconfig 2>&1 | tail -8
echo "DEFCONFIG_EXIT=${PIPESTATUS[0]}"

echo "=== make modules_prepare ==="
make ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc HOSTCFLAGS="$HFLAGS" modules_prepare 2>&1 | tail -30
echo "PREPARE_EXIT=${PIPESTATUS[0]}"

echo "=== checks ==="
ls -la Module.symvers 2>&1 || echo "NO Module.symvers"
grep CONFIG_MODVERSIONS .config || echo "no modversions"
cat include/config/kernel.release 2>&1 || echo "no kernel.release"

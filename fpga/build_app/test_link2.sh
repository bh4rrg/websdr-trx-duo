#!/bin/bash
export PATH="/c/msys64/usr/bin:/usr/bin:/bin:$PATH"
export ZIG_GLOBAL_CACHE_DIR=/d/websdr-trx-duo/fpga/toolchain/zig-cache-global
export ZIG_LOCAL_CACHE_DIR=/d/websdr-trx-duo/fpga/build_app/zig-cache-local
ZIG=/d/websdr-trx-duo/fpga/toolchain/zig-windows-x86_64-0.13.0/zig.exe
SYS=/d/websdr-trx-duo/fpga/sysroot-alpine320
cd /d/websdr-trx-duo/fpga/build_app

$ZIG cc -target arm-linux-musleabihf t.c -o t5.elf -I$SYS/usr/include \
  -L$SYS/usr/lib -L$SYS/lib \
  -lz -lgps -lfdk-aac -lunwind -lunwind-arm -lcurl -lc -v 2>&1 | grep -E "^ld.lld" | head -2

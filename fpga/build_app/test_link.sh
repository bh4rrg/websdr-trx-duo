#!/bin/bash
export PATH="/c/msys64/usr/bin:/usr/bin:/bin:$PATH"
export ZIG_GLOBAL_CACHE_DIR=/d/websdr-trx-duo/fpga/toolchain/zig-cache-global
export ZIG_LOCAL_CACHE_DIR=/d/websdr-trx-duo/fpga/build_app/zig-cache-local
ZIG=/d/websdr-trx-duo/fpga/toolchain/zig-windows-x86_64-0.13.0/zig.exe
SYS=/d/websdr-trx-duo/fpga/sysroot-alpine320
cd /d/websdr-trx-duo/fpga/build_app

echo "=== test6: full-path libc.so + libunwind.so ==="
$ZIG cc -target arm-linux-musleabihf t.c -o t6.elf -I$SYS/usr/include \
  -L$SYS/usr/lib -L$SYS/lib \
  -Wl,-Bstatic -lfftw3f -lfftw3f_threads -Wl,-Bdynamic \
  -lz -lgps -lfdk-aac -lcurl \
  $SYS/usr/lib/libunwind.so $SYS/lib/libc.so 2>&1 | grep -E "error" | head -8
echo "exit=${PIPESTATUS[0]}"
ls -la t6.elf 2>/dev/null || echo "no t6.elf"

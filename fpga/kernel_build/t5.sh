#!/bin/bash
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
export PATH="/c/msys64/mingw64/bin:/c/msys64/usr/bin:/usr/bin:/bin"
cd /d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38
echo "=== compile fixdep with includes ==="
gcc -O2 -I scripts/include -o scripts/basic/fixdep_test.exe scripts/basic/fixdep.c 2>&1; echo "C_EXIT=$?"
ls -la scripts/basic/fixdep_test.exe 2>&1
echo "=== run no args (expect usage) ==="
./scripts/basic/fixdep_test.exe 2>&1; echo "EXIT=$?"

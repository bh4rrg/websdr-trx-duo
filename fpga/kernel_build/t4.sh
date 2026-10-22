#!/bin/bash
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
export PATH="/c/msys64/mingw64/bin:/c/msys64/usr/bin:/usr/bin:/bin"
cd /d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38/scripts/basic
echo "=== compile fixdep ==="
gcc -O2 -o fixdep_test.exe fixdep.c 2>&1; echo "C_EXIT=$?"
ls -la fixdep_test.exe
echo "=== run with no args ==="
./fixdep_test.exe; echo "EXIT=$?"
echo "=== run with a depfile ==="
printf 'fixdep_test.o: fixdep.c\n' > /tmp/test.d
./fixdep_test.exe /tmp/test.d /tmp/t.o target 2>&1; echo "EXIT2=$?"

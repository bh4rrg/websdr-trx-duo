#!/bin/bash
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
export PATH="/c/msys64/mingw64/bin:/c/msys64/usr/bin:/usr/bin:/bin"
cd /d/websdr-trx-duo/fpga/kernel_build/linux-6.18.38
ls -la scripts/include/xalloc.h
echo "=== stat size ==="
stat -c '%s' scripts/include/xalloc.h
echo "=== build fixdep_test ==="
gcc -O2 -I scripts/include -o scripts/basic/fixdep_test.exe scripts/basic/fixdep.c 2>&1; echo "C_EXIT=$?"
echo "=== make a fake depfile referencing xalloc.h ==="
printf 'fixdep.o: scripts/basic/fixdep.c scripts/include/xalloc.h\n' > /tmp/fake.d
cat /tmp/fake.d
echo "=== run fixdep_test ==="
./scripts/basic/fixdep_test.exe /tmp/fake.d fixdep.o "gcc test" ; echo "EXIT=$?"

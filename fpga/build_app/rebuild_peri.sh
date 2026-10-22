#!/bin/bash
export PATH="/c/msys64/usr/bin:/usr/bin:/bin:$PATH"
export MSYS2_ARG_CONV_EXCL='*'
export MSYS_NO_PATHCONV=1
cd /d/websdr-trx-duo/fpga/build_app/build/CMakeFiles/websdr.bin.dir || exit 1
rm -f zynq/peri.cpp.o
cd /d/websdr-trx-duo/fpga/build_app/build
make -j4 2>&1 | tail -25
echo MAKE_EXIT=$?
ls -l websdr.bin

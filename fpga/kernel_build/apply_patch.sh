#!/bin/bash
export TMPDIR=/d/websdr-trx-duo/fpga/kernel_build/tmp
mkdir -p "$TMPDIR"
cd /d/websdr-trx-duo/fpga/kernel_build
echo "=== APPLY ==="
patch -d linux-6.18.38 -p1 < linux-6.18.patch
echo "APPLY_EXIT=$?"

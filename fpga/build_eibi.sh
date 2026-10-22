#!/bin/bash
export PATH="/c/msys64/usr/bin:/usr/bin:/bin:$PATH"
app="/d/websdr-trx-duo/fpga/OpenZynqSDRApp-develop/OpenZynqSDRApp-develop"
mkdir -p "$app/host_tools"
# 自动把所有含 .h 的目录(深度<=3)加入 include 路径
INCS=""
while IFS= read -r d; do INCS="$INCS -I$d"; done < <(find "$app" -maxdepth 3 -name '*.h' -printf '%h\n' | sort -u)
g++ -O2 -D_GNU_SOURCE $INCS "$app/pkgs/EiBi/eibi_proc.cpp" -o "$app/host_tools/eibi_proc.exe" 2>&1 | head -40
echo "GXX_EXIT=${PIPESTATUS[0]}"
ls -la "$app/host_tools/" || true

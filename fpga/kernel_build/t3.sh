#!/bin/bash
echo "=== cc1 direct ==="
/c/msys64/mingw64/lib/gcc/x86_64-w64-mingw32/16.1.0/cc1.exe --help 2>&1 | head -3
echo "EXIT=$?"
echo "=== ldd cc1 ==="
ldd /c/msys64/mingw64/lib/gcc/x86_64-w64-mingw32/16.1.0/cc1.exe 2>&1 | grep -i 'not found\|=>' | head -20

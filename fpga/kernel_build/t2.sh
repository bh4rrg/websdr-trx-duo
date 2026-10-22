#!/bin/bash
cd /tmp
printf 'int main(){return 0;}\n' > t.c
echo "=== compile to asm only ==="
/c/msys64/mingw64/bin/gcc.exe -S -o t.s t.c; echo "S_EXIT=$?"; ls -la t.s 2>&1
echo "=== compile asm to obj ==="
/c/msys64/mingw64/bin/gcc.exe -c -o t.o t.c; echo "C_EXIT=$?"; ls -la t.o 2>&1
echo "=== link ==="
/c/msys64/mingw64/bin/gcc.exe -o t.exe t.o; echo "L_EXIT=$?"; ls -la t.exe 2>&1

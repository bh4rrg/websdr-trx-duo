#!/bin/bash
cd /tmp
printf 'int main(){return 0;}\n' > t.c
/c/msys64/mingw64/bin/gcc.exe -v -o t.exe t.c > gccout.txt 2>&1
echo "EXIT=$?"
tail -30 gccout.txt

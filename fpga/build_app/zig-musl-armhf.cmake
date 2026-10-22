# CMake toolchain: zig c++ -> arm-linux-musleabihf (Alpine armhf 目标)
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
# 项目不创建静态库，try_compile 直接链接可执行文件（zig cc 可独立链接）
set(CMAKE_TRY_COMPILE_TARGET_TYPE EXECUTABLE)

set(ZIG_EXE "d:/websdr-trx-duo/fpga/toolchain/zig-windows-x86_64-0.13.0/zig.exe")
set(ZIG_TARGET "arm-linux-musleabihf")

set(CMAKE_C_COMPILER   "${ZIG_EXE}" cc   -target ${ZIG_TARGET})
set(CMAKE_CXX_COMPILER "${ZIG_EXE}" c++ -target ${ZIG_TARGET})

set(ALPINE_SYSROOT "d:/websdr-trx-duo/fpga/sysroot-alpine320" CACHE PATH "Alpine armhf sysroot")

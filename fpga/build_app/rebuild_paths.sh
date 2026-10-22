export PATH="/c/msys64/usr/bin:/usr/bin:/bin:$PATH"
export MSYS2_ARG_CONV_EXCL='*'
export MSYS_NO_PATHCONV=1
cd /d/websdr-trx-duo/fpga/build_app/build/CMakeFiles/websdr.bin.dir || exit 1
rm -f main.cpp.o \
  init/cfg.cpp.o init/clk.cpp.o init/dx.cpp.o \
  net/services.cpp.o \
  rx/rx_cmd.cpp.o rx/rx_server_ajax.cpp.o \
  ui/admin.cpp.o web/web.cpp.o web/web_server.cpp.o \
  extensions/ALE_2G/ALE_2G.cpp.o \
  extensions/CW_decoder/cw_decoder.cpp.o \
  extensions/CW_skimmer/skimmer.cpp.o \
  extensions/digi_modes/digi_modes.cpp.o \
  extensions/DRM/DRM.cpp.o \
  extensions/FSK/fsk.cpp.o \
  extensions/FT8/FT8.cpp.o \
  extensions/NAVTEX/navtex.cpp.o \
  extensions/SSTV/sstv.cpp.o \
  extensions/timecode/timecode.cpp.o \
  extensions/wspr/wspr_main.cpp.o
cd /d/websdr-trx-duo/fpga/build_app/build
make -j4 2>&1 | tail -25
echo MAKE_EXIT=$?
ls -l websdr.bin

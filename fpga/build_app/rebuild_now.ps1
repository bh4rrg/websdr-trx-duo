# Incremental rebuild of websdr.bin after peri.cpp edit
Set-Location D:\websdr-trx-duo\fpga\build_app\build
& cmake --build . --target websdr.bin -j 8 2>&1 | Tee-Object -FilePath D:\websdr-trx-duo\fpga\build_app\rebuild_watchdog.log
Write-Host ("EXIT=" + $LASTEXITCODE)

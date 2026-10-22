$log = 'd:\websdr-trx-duo\fpga\kernel_build\kernel_zimage7.log'
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalMinutes -lt 9) {
    if (Select-String -Path $log -Pattern 'ZIMAGE_EXIT=' -Quiet) {
        Write-Output 'DONE_MARKER_FOUND'
        break
    }
    Start-Sleep -Seconds 15
}
if (-not (Select-String -Path $log -Pattern 'ZIMAGE_EXIT=' -Quiet)) {
    Write-Output 'STILL_RUNNING'
}
Write-Output '--- tail ---'
Get-Content $log -Tail 8

# =============================================================================
# Re-run implementation with fixed XDC constraints
# Synthesis already completed, only need to reset and rerun impl
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/trxduo_flat/trxduo_flat.xpr

puts "=== RESETTING IMPL RUN ==="
reset_run impl_1
puts "IMPL_RESET_OK"

puts "=== STARTING IMPLEMENTATION + BITSTREAM ==="
if {[catch {launch_runs impl_1 -jobs 8 -to_step write_bitstream} e]} {
    puts "IMPL_LAUNCH_ERR: $e"
    close_project
    exit 1
}
puts "IMPL_LAUNCH_OK"

if {[catch {wait_on_run impl_1} e]} {
    puts "IMPL_WAIT_ERR: $e"
}

set impl_status [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS: $impl_status"

if {![string match "*write_bitstream Complete!*" $impl_status]} {
    puts "IMPL_OR_BITSTREAM_FAILED"
    close_project
    exit 1
}
puts "=== IMPLEMENTATION + BITSTREAM COMPLETE ==="

# ====== COPY BITSTREAM ======
set bit_src "D:/websdr-trx-duo/fpga/trxduo_port/trxduo_flat/trxduo_flat.runs/impl_1/top_trxduo.bit"
if {[file exists $bit_src]} {
    file copy -force $bit_src "D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo_v2.bit"
    puts "COPIED TO: D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo_v2.bit"
    puts "BIT_SIZE: [file size $bit_src] bytes"
} else {
    puts "BIT_MISSING: $bit_src"
}

close_project
puts "=== ALL DONE ==="
exit

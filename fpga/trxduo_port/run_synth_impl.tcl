# =============================================================================
# Run synthesis, implementation, and bitstream generation for TRX-DUO
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

# ====== 1. ENSURE AUTO MODE FOR MODULE REFS ======
set_property source_mgmt_mode All [current_project]
puts "OK source_mgmt_mode=All"

# ====== 2. UPDATE COMPILE ORDER ======
update_compile_order -fileset sources_1
puts "OK compile_order_updated"

# Report top module
puts "TOP: [get_property TOP [current_fileset]]"

# ====== 3. RESET SYNTH RUN (old part checkpoint mismatch) ======
reset_run synth_1
puts "OK synth_reset"

# ====== 4. LAUNCH SYNTHESIS ======
puts "=== STARTING SYNTHESIS ==="
if {[catch {launch_runs synth_1 -jobs 8} e]} {
    puts "SYNTH_LAUNCH_ERR: $e"
    close_project
    exit 1
}
puts "SYNTH_LAUNCH_OK"

# Wait for synthesis to complete
if {[catch {wait_on_run synth_1} e]} {
    puts "SYNTH_WAIT_ERR: $e"
}

set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS: $synth_status"

if {$synth_status ne "synth_design Complete!"} {
    puts "SYNTH_FAILED - check runme.log in synth_1 directory"
    close_project
    exit 1
}
puts "=== SYNTHESIS COMPLETE ==="

# ====== 5. RESET AND LAUNCH IMPLEMENTATION ======
reset_run impl_1
puts "OK impl_reset"

puts "=== STARTING IMPLEMENTATION ==="
if {[catch {launch_runs impl_1 -jobs 8 -to_step write_bitstream} e]} {
    puts "IMPL_LAUNCH_ERR: $e"
    close_project
    exit 1
}
puts "IMPL_LAUNCH_OK"

# Wait for implementation + bitstream to complete
if {[catch {wait_on_run impl_1} e]} {
    puts "IMPL_WAIT_ERR: $e"
}

set impl_status [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS: $impl_status"

if {![string match "*write_bitstream Complete!*" $impl_status]} {
    puts "IMPL_OR_BITSTREAM_FAILED - check runme.log in impl_1 directory"
    close_project
    exit 1
}
puts "=== IMPLEMENTATION + BITSTREAM COMPLETE ==="

# ====== 6. REPORT BITSTREAM LOCATION ======
set bit_file [get_property BITSTREAM.FILENAME [get_runs impl_1]]
puts "BITSTREAM_FILE: $bit_file"

close_project
puts "=== ALL DONE ==="
exit

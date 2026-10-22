# =============================================================================
# Direct synth_design test to diagnose the issue
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

# Set auto mode and include dir
set_property source_mgmt_mode All [current_project]
set wf_cic_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/wf_cic"
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
update_compile_order -fileset sources_1

# Try direct synthesis
puts "=== TRYING DIRECT SYNTHESIS ==="
if {[catch {synth_design -top top_trxduo -part xc7z020clg400-1} e]} {
    puts "SYNTH_ERR: $e"
    puts "=== ERROR INFO ==="
    puts "$::errorInfo"
} else {
    puts "SYNTH_OK"
}

close_project
puts "=== DONE ==="
exit

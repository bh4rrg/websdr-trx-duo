# =============================================================================
# Debug and fix module_ref IP issues
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

set new_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/new"
set wf_cic_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/wf_cic"

# ====== 1. SET AUTO MODE AND INCLUDE DIR ======
set_property source_mgmt_mode All [current_project]
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
puts "OK mode=Auto, include_dirs set"

# ====== 2. REPORT IP PROPERTIES ======
set all_ips [get_ips]
puts "ALL_IPS_COUNT: [llength $all_ips]"

foreach ip $all_ips {
    puts "\n=== IP: $ip ==="
    set props [list IPDEF VLNV IS_LOCKED NEEDS_UPGRADE STATUS USED_IN SYNTHESISFLOW]
    foreach p $props {
        if {[catch {set val [get_property $p $ip]} e]} {
            puts "  $p: <error> $e"
        } else {
            puts "  $p: $val"
        }
    }
}

# ====== 3. TRY DISABLING IP CACHE ======
puts "\n=== DISABLING IP CACHE ==="
if {[catch {config_ip_cache -disable_cache} e]} {
    puts "DISABLE_CACHE_ERR: $e"
} else {
    puts "DISABLE_CACHE_OK"
}

# ====== 4. TRY MARKING IPS AS UP-TO-DATE ======
set mref_names [list design_1_adc_ovr_detect_0_0 design_1_sound_rx_common_0_0 design_1_spi_receiver_0_0 design_1_wf_proc_0_0 design_1_wf_proc_0_1]

puts "\n=== TRYING TO FORCE IP STATUS ==="
foreach ip_name $mref_names {
    set ip [get_ips $ip_name]
    if {$ip != ""} {
        puts "Processing $ip_name..."
        # Try to mark as not locked
        if {[catch {set_property IS_LOCKED false $ip} e]} {
            puts "  IS_LOCKED=false err: $e"
        } else {
            puts "  IS_LOCKED=false ok"
        }
    }
}

# ====== 5. UPDATE COMPILE ORDER ======
update_compile_order -fileset sources_1
puts "\nOK compile_order_updated"

# ====== 6. RESET AND TRY SYNTHESIS ======
reset_run synth_1
puts "OK synth_reset"

puts "=== STARTING SYNTHESIS ==="
if {[catch {launch_runs synth_1 -jobs 8} e]} {
    puts "SYNTH_LAUNCH_ERR: $e"
    close_project
    exit 1
}
puts "SYNTH_LAUNCH_OK"

if {[catch {wait_on_run synth_1} e]} {
    puts "SYNTH_WAIT_ERR: $e"
}

set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS: $synth_status"

if {$synth_status ne "synth_design Complete!"} {
    puts "SYNTH_FAILED"
    close_project
    exit 1
}
puts "=== SYNTHESIS COMPLETE ==="

# ====== 7. IMPLEMENTATION + BITSTREAM ======
reset_run impl_1
puts "OK impl_reset"

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

set bit_file [get_property BITSTREAM.FILENAME [get_runs impl_1]]
set src_path [get_property DIRECTORY [get_runs impl_1]]
set full_bit_path "$src_path/$bit_file"
puts "BITSTREAM: $full_bit_path"

if {[file exists $full_bit_path]} {
    file copy -force $full_bit_path "D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.bit"
    puts "COPIED TO: D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.bit"
}

close_project
puts "=== ALL DONE ==="
exit

# =============================================================================
# Try fixing module_ref by accessing IPs via get_ips and changing synthesis flow
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

set new_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/new"
set wf_cic_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/wf_cic"

# ====== 1. SET AUTO MODE AND INCLUDE DIR ======
set_property source_mgmt_mode All [current_project]
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
puts "OK mode=Auto, include_dirs set"

# ====== 2. FIND ALL MODULE_REF IPS ======
set all_ips [get_ips]
puts "ALL_IPS_COUNT: [llength $all_ips]"
puts "ALL_IPS: $all_ips"

# Find module_ref IPs
set mref_ips [list]
foreach ip $all_ips {
    set comp_ref [get_property COMPONENT_NAME $ip]
    puts "IP: $ip => COMPONENT: $comp_ref"
    if {[string match "*module_ref*" $comp_ref]} {
        lappend mref_ips $ip
        puts "  -> MODULE_REF IP"
    }
}
puts "MOD_REF_IPS: $mref_ips"

# ====== 3. TRY TO REFRESH / UPGRADE MODULE_REF IPS ======
foreach ip $mref_ips {
    puts "Processing $ip..."
    
    # Check if IP is locked or needs upgrade
    set is_locked [get_property IS_LOCKED $ip]
    set needs_upgrade [get_property NEEDS_UPGRADE $ip]
    puts "  IS_LOCKED: $is_locked"
    puts "  NEEDS_UPGRADE: $needs_upgrade"
    
    # Get the module name from the component reference
    set comp_name [get_property COMPONENT_NAME $ip]
    puts "  COMPONENT_NAME: $comp_name"
}

# ====== 4. TRY RE-GENERATING TARGETS FOR MODULE_REF IPS ======
puts "=== REGENERATING MODULE REF IP TARGETS ==="
foreach ip $mref_ips {
    puts "Regenerating $ip..."
    if {[catch {generate_target all $ip} e]} {
        puts "  REGEN_ERR: $e"
    } else {
        puts "  REGEN_OK"
    }
}

# ====== 5. UPDATE COMPILE ORDER ======
update_compile_order -fileset sources_1
puts "OK compile_order_updated"

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

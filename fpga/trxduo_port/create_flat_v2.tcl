# =============================================================================
# Flat project v2 - fix IP repo, manual compile order, explicit top
# =============================================================================

set proj_dir "D:/websdr-trx-duo/fpga/trxduo_port/trxduo_flat"
set proj_name "trxduo_flat"
set part "xc7z020clg400-1"

set src_base "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1"
set gen_base "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.gen/sources_1/bd/design_1"
set bd_ip_dir "$src_base/bd/design_1/ip"
set new_dir "$src_base/new"
set wf_cic_dir "$src_base/wf_cic"
set ip_dir "$src_base/ip"
set ip_repo "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.ipdefs/export"

# ====== 1. CREATE NEW PROJECT ======
create_project $proj_name $proj_dir -part $part -force
puts "PROJECT_CREATED: $proj_dir/$proj_name"

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# ====== 2. ADD IP REPOSITORY (for HLS IPs: sound_sender, waterfall_sender) ======
if {[file exists $ip_repo]} {
    set_property IP_REPO_PATHS $ip_repo [current_project]
    update_ip_catalog
    puts "IP_REPO_ADDED: $ip_repo"
} else {
    puts "IP_REPO_MISSING: $ip_repo"
}

# ====== 3. ADD REGULAR IP .XCI FILES (non-module-ref) ======
set ip_xcis [list \
    "$bd_ip_dir/design_1_auto_us_0/design_1_auto_us_0.xci" \
    "$bd_ip_dir/design_1_auto_pc_0/design_1_auto_pc_0.xci" \
    "$bd_ip_dir/design_1_auto_pc_1/design_1_auto_pc_1.xci" \
    "$bd_ip_dir/design_1_auto_pc_2/design_1_auto_pc_2.xci" \
    "$bd_ip_dir/design_1_sound_sender_0_2/design_1_sound_sender_0_2.xci" \
    "$bd_ip_dir/design_1_waterfall_sender_0_0/design_1_waterfall_sender_0_0.xci" \
    "$bd_ip_dir/design_1_waterfall_sender_0_1/design_1_waterfall_sender_0_1.xci" \
    "$bd_ip_dir/design_1_processing_system7_0_0/design_1_processing_system7_0_0.xci" \
    "$bd_ip_dir/design_1_rst_design_1_10M_0/design_1_rst_design_1_10M_0.xci" \
    "$bd_ip_dir/design_1_rst_fclk_0/design_1_rst_fclk_0.xci" \
    "$bd_ip_dir/design_1_xlconcat_0_0/design_1_xlconcat_0_0.xci" \
    "$bd_ip_dir/design_1_xlconstant_0_0/design_1_xlconstant_0_0.xci" \
    "$bd_ip_dir/design_1_xlconstant_0_1/design_1_xlconstant_0_1.xci" \
    "$bd_ip_dir/design_1_axi_mem_intercon_1_1/design_1_axi_mem_intercon_1_1.xci" \
    "$bd_ip_dir/design_1_axi_mem_intercon_1_2/design_1_axi_mem_intercon_1_2.xci" \
    "$bd_ip_dir/design_1_axi_mem_intercon_2/design_1_axi_mem_intercon_2.xci" \
    "$ip_dir/rx_cic_1/rx_cic_1.xci" \
    "$ip_dir/rx_cic2/rx_cic2.xci" \
    "$ip_dir/dds_sound/dds_sound.xci" \
]

set ip_count 0
foreach xci $ip_xcis {
    if {[file exists $xci]} {
        add_files -norecurse -fileset sources_1 $xci
        incr ip_count
        puts "ADD_IP_OK: [file tail $xci]"
    } else {
        puts "ADD_IP_MISSING: $xci"
    }
}
puts "TOTAL_IPS_ADDED: $ip_count"

# ====== 4. UPGRADE LOCKED IPS ======
puts "=== UPGRADING LOCKED IPS ==="
set locked_ips [get_ips -quiet -filter {IS_LOCKED == 1}]
puts "LOCKED_IPS: $locked_ips"
if {[llength $locked_ips] > 0} {
    if {[catch {upgrade_ip -quiet $locked_ips} e]} {
        puts "UPGRADE_WARN: $e"
    } else {
        puts "UPGRADE_OK"
    }
}

# ====== 5. ADD BD STRUCTURAL NETLIST + WRAPPER ======
add_files -norecurse -fileset sources_1 "$gen_base/synth/design_1.v"
puts "ADD_DESIGN_1_OK"

add_files -norecurse -fileset sources_1 "$gen_base/hdl/design_1_wrapper.v"
puts "ADD_WRAPPER_OK"

# ====== 6. ADD MODULE_REF WRAPPERS AS PLAIN VERILOG ======
set mref_wrappers [list \
    "design_1_adc_ovr_detect_0_0/synth/design_1_adc_ovr_detect_0_0.v" \
    "design_1_sound_rx_common_0_0/synth/design_1_sound_rx_common_0_0.v" \
    "design_1_spi_receiver_0_0/synth/design_1_spi_receiver_0_0.v" \
    "design_1_wf_proc_0_0/synth/design_1_wf_proc_0_0.v" \
    "design_1_wf_proc_0_1/synth/design_1_wf_proc_0_1.v" \
]

foreach wf $mref_wrappers {
    set full_path "$gen_base/ip/$wf"
    if {[file exists $full_path]} {
        add_files -norecurse -fileset sources_1 $full_path
        puts "ADD_MREF_OK: $wf"
    }
}

# ====== 7. ADD RTL SOURCE FILES ======
set rtl_files [list \
    "$new_dir/adc_ovr_detect.v" \
    "$new_dir/adc_sim_conv.v" \
    "$new_dir/sound_rx_ch.v" \
    "$new_dir/sound_rx_common.v" \
    "$new_dir/spi_receiver.v" \
    "$new_dir/wf_proc.v" \
    "$new_dir/axis_async_fifo.v" \
    "$wf_cic_dir/cic_comb.v" \
    "$wf_cic_dir/cic_integrator.v" \
    "$wf_cic_dir/cic_prune_var.v" \
]

foreach f $rtl_files {
    if {[file exists $f]} {
        add_files -norecurse -fileset sources_1 $f
        puts "ADD_RTL_OK: [file tail $f]"
    }
}

# ====== 8. ADD TOP MODULE ======
add_files -norecurse -fileset sources_1 "D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v"
puts "ADD_TOP_OK"

# ====== 9. SET INCLUDE DIRECTORIES ======
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
puts "INCLUDE_DIRS: $wf_cic_dir"

# ====== 10. ADD CONSTRAINTS ======
add_files -norecurse -fileset constrs_1 "D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc"
puts "ADD_XDC_OK"

# ====== 11. MANUAL COMPILE ORDER + EXPLICIT TOP ======
set_property source_mgmt_mode None [current_project]
puts "SOURCE_MGMT: None (Manual)"

set_property top top_trxduo [current_fileset]
puts "TOP_MODULE: top_trxduo"

# ====== 12. GENERATE ALL IP TARGETS ======
puts "=== GENERATING IP TARGETS ==="
set all_ip_files [get_files -quiet -filter {FILE_TYPE == "IP"}]
puts "IP_FILES_COUNT: [llength $all_ip_files]"

if {[catch {generate_target all $all_ip_files} e]} {
    puts "GEN_TARGETS_ERR: $e"
} else {
    puts "GEN_TARGETS_OK"
}

# ====== 13. REPORT FILES FOR DEBUG ======
puts "\n=== ALL SOURCE FILES ==="
set all_srcs [get_files -quiet -of_objects [get_filesets sources_1]]
foreach f $all_srcs {
    set ftype [get_property FILE_TYPE $f]
    set used [get_property USED_IN_SYNTHESIS $f]
    puts "  $ftype | used_synth=$used | $f"
}
puts "TOTAL_SOURCE_FILES: [llength $all_srcs]"

# ====== 14. RESET AND RUN SYNTHESIS ======
reset_run synth_1
puts "SYNTH_RESET_OK"

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
    puts "SYNTH_FAILED - check runme.log"
    close_project
    exit 1
}
puts "=== SYNTHESIS COMPLETE ==="

# ====== 15. IMPLEMENTATION + BITSTREAM ======
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

# ====== 16. COPY BITSTREAM ======
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

# =============================================================================
# Create a flat (non-BD) project to bypass module_ref issues
# All BD-generated netlists and IPs are added directly
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

# ====== 1. CREATE NEW PROJECT ======
create_project $proj_name $proj_dir -part $part -force
puts "PROJECT_CREATED: $proj_dir/$proj_name"

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# ====== 2. ADD REGULAR IP .XCI FILES (non-module-ref) ======
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

# ====== 3. ADD BD STRUCTURAL NETLIST (design_1.v) ======
set design_1_v "$gen_base/synth/design_1.v"
if {[file exists $design_1_v]} {
    add_files -norecurse -fileset sources_1 $design_1_v
    puts "ADD_DESIGN_1_OK"
} else {
    puts "ADD_DESIGN_1_MISSING: $design_1_v"
}

# ====== 4. ADD DESIGN_1 WRAPPER ======
set wrapper_v "$gen_base/hdl/design_1_wrapper.v"
if {[file exists $wrapper_v]} {
    add_files -norecurse -fileset sources_1 $wrapper_v
    puts "ADD_WRAPPER_OK"
} else {
    puts "ADD_WRAPPER_MISSING: $wrapper_v"
}

# ====== 5. ADD MODULE_REF WRAPPERS AS PLAIN VERILOG ======
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
        puts "ADD_MREF_WRAPPER_OK: $wf"
    } else {
        puts "ADD_MREF_WRAPPER_MISSING: $full_path"
    }
}

# ====== 6. ADD RTL SOURCE FILES ======
set rtl_files [list \
    "$new_dir/adc_ovr_detect.v" \
    "$new_dir/adc_sim_conv.v" \
    "$new_dir/sound_rx_ch.v" \
    "$new_dir/sound_rx_common.v" \
    "$new_dir/spi_receiver.v" \
    "$new_dir/wf_proc.v" \
    "$wf_cic_dir/cic_comb.v" \
    "$wf_cic_dir/cic_integrator.v" \
    "$wf_cic_dir/cic_prune_var.v" \
]

foreach f $rtl_files {
    if {[file exists $f]} {
        add_files -norecurse -fileset sources_1 $f
        puts "ADD_RTL_OK: [file tail $f]"
    } else {
        puts "ADD_RTL_MISSING: $f"
    }
}

# ====== 7. SET INCLUDE DIRECTORIES ======
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
puts "INCLUDE_DIRS: $wf_cic_dir"

# ====== 8. ADD TOP MODULE ======
set top_file "D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v"
if {[file exists $top_file]} {
    add_files -norecurse -fileset sources_1 $top_file
    puts "ADD_TOP_OK: top_trxduo.v"
} else {
    puts "ADD_TOP_MISSING: $top_file"
}

# ====== 9. ADD CONSTRAINTS ======
set xdc_file "D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc"
if {[file exists $xdc_file]} {
    add_files -norecurse -fileset constrs_1 $xdc_file
    puts "ADD_XDC_OK: trxduo.xdc"
} else {
    puts "ADD_XDC_MISSING: $xdc_file"
}

# ====== 10. SET TOP MODULE ======
set_property top top_trxduo [current_fileset]
puts "TOP_MODULE: top_trxduo"

# ====== 11. GENERATE ALL IP TARGETS ======
puts "=== GENERATING IP TARGETS ==="
set all_ip_files [get_files -quiet -filter {FILE_TYPE == "IP"}]
puts "IP_FILES_COUNT: [llength $all_ip_files]"

if {[catch {generate_target all $all_ip_files} e]} {
    puts "GEN_TARGETS_ERR: $e"
} else {
    puts "GEN_TARGETS_OK"
}

# ====== 12. UPDATE COMPILE ORDER ======
update_compile_order -fileset sources_1
puts "COMPILE_ORDER_UPDATED"

set top_val [get_property top [current_fileset]]
puts "VERIFY_TOP: $top_val"

# ====== 13. RUN SYNTHESIS ======
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

# ====== 14. IMPLEMENTATION + BITSTREAM ======
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

# ====== 15. COPY BITSTREAM ======
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

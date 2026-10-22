# =============================================================================
# Replace module_ref IPs with plain Verilog wrappers to bypass resolution issues
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
set gen_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.gen/sources_1/bd/design_1/ip"
set new_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/new"
set wf_cic_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/wf_cic"

# ====== 1. SET AUTO MODE AND INCLUDE DIR ======
set_property source_mgmt_mode All [current_project]
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
puts "OK mode=Auto, include_dirs set"

# ====== 2. REMOVE MODULE_REF XCI FILES FROM PROJECT ======
set mref_xcis [list \
    "design_1_adc_ovr_detect_0_0/design_1_adc_ovr_detect_0_0.xci" \
    "design_1_sound_rx_common_0_0/design_1_sound_rx_common_0_0.xci" \
    "design_1_spi_receiver_0_0/design_1_spi_receiver_0_0.xci" \
    "design_1_wf_proc_0_0/design_1_wf_proc_0_0.xci" \
    "design_1_wf_proc_0_1/design_1_wf_proc_0_1.xci" \
]

set bd_ip_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/ip"
foreach xci $mref_xcis {
    set full_path "$bd_ip_dir/$xci"
    if {[file exists $full_path]} {
        if {[catch {remove_files $full_path} e]} {
            puts "REMOVE_XCI_WARN $xci: $e"
        } else {
            puts "REMOVE_XCI_OK $xci"
        }
    }
}

# ====== 3. ADD SYNTH WRAPPERS AS PLAIN VERILOG ======
set wrapper_files [list \
    "design_1_adc_ovr_detect_0_0/synth/design_1_adc_ovr_detect_0_0.v" \
    "design_1_sound_rx_common_0_0/synth/design_1_sound_rx_common_0_0.v" \
    "design_1_spi_receiver_0_0/synth/design_1_spi_receiver_0_0.v" \
    "design_1_wf_proc_0_0/synth/design_1_wf_proc_0_0.v" \
    "design_1_wf_proc_0_1/synth/design_1_wf_proc_0_1.v" \
]

foreach wf $wrapper_files {
    set full_path "$gen_dir/$wf"
    if {[file exists $full_path]} {
        if {[catch {add_files -norecurse $full_path} e]} {
            puts "ADD_WRAPPER_WARN $wf: $e"
        } else {
            puts "ADD_WRAPPER_OK $wf"
        }
    } else {
        puts "ADD_WRAPPER_MISSING $full_path"
    }
}

# ====== 4. ENSURE RTL SOURCES ARE PRESENT ======
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
        # Check if already in project
        if {[catch {get_files $f} e]} {
            add_files -norecurse $f
            puts "ADD_RTL_OK $f"
        } else {
            puts "RTL_ALREADY_THERE $f"
        }
    }
}

# ====== 5. UPDATE COMPILE ORDER ======
update_compile_order -fileset sources_1
puts "OK compile_order_updated"

set top_mod [get_property TOP [current_fileset]]
puts "TOP_MODULE: $top_mod"

# ====== 6. RESET AND RUN SYNTHESIS ======
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

# ====== 8. COPY BITSTREAM ======
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

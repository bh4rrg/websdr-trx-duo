# =============================================================================
# Fix module references in auto mode, then run synthesis + impl + bitstream
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]

# ====== 1. SET AUTO MODE (required for module_ref) ======
set_property source_mgmt_mode All [current_project]
puts "OK source_mgmt_mode=All"

# ====== 2. OPEN BD AND UPDATE MODULE REFERENCES ======
open_bd_design $bd

# Report current module_ref cells
puts "=== MODULE REF CELLS ==="
set mref_cells [get_bd_cells -filter {VLNV =~ "*module_ref*"}]
foreach cell $mref_cells {
    puts "  $cell"
}

# Update each module reference
set mref_names {adc_ovr_detect sound_rx_common wf_proc spi_receiver}
foreach mod $mref_names {
    set cells [get_bd_cells -filter {VLNV =~ "*module_ref*"}]
    foreach cell $cells {
        set cell_name [get_property NAME $cell]
        if {[string match "${mod}_*" $cell_name]} {
            puts "UMR_ATTEMPT $cell_name"
            if {[catch {update_module_reference $cell} e]} {
                puts "UMR_WARN $cell_name: $e"
            } else {
                puts "UMR_OK $cell_name"
            }
        }
    }
}

# Validate BD
if {[catch {validate_bd_design} verr]} {
    puts "VALIDATE_ERR: $verr"
} else {
    puts "VALIDATE_OK"
}

save_bd_design
close_bd_design [current_bd_design]
puts "OK BD_SAVED"

# ====== 3. REGENERATE BD TARGETS ======
puts "=== REGENERATING BD TARGETS ==="
if {[catch {generate_target all [get_files $bd]} e]} {
    puts "GEN_TARGET_ERR: $e"
    close_project
    exit 1
} else {
    puts "GEN_TARGET_OK"
}

# ====== 4. UPDATE COMPILE ORDER ======
update_compile_order -fileset sources_1
puts "OK compile_order_updated"

# Report top module
set top_mod [get_property TOP [current_fileset]]
puts "TOP_MODULE: $top_mod"

# If top is not top_trxduo, set it manually (in auto mode it should auto-detect)
if {$top_mod ne "top_trxduo"} {
    puts "WARNING: Top is $top_mod, expected top_trxduo"
}

# ====== 5. RESET SYNTH RUN ======
reset_run synth_1
puts "OK synth_reset"

# ====== 6. LAUNCH SYNTHESIS ======
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
    puts "SYNTH_FAILED - check runme.log in synth_1 directory"
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

# ====== 8. REPORT ======
set bit_file [get_property BITSTREAM.FILENAME [get_runs impl_1]]
puts "BITSTREAM_FILE: $bit_file"

# Copy bitstream to project root
set src_path [get_property DIRECTORY [get_runs impl_1]]
set full_bit_path "$src_path/$bit_file"
puts "FULL_PATH: $full_bit_path"

if {[file exists $full_bit_path]} {
    file copy -force $full_bit_path "D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.bit"
    puts "COPIED: D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.bit"
}

close_project
puts "=== ALL DONE ==="
exit

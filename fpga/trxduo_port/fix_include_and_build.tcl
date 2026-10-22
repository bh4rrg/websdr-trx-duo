# =============================================================================
# Fix include paths, resolve module refs, full build
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]

# ====== 1. SET AUTO MODE ======
set_property source_mgmt_mode All [current_project]
puts "OK source_mgmt_mode=All"

# ====== 2. ADD INCLUDE DIRECTORIES ======
set wf_cic_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/wf_cic"
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
puts "OK include_dirs=$wf_cic_dir"

# ====== 3. FORCE REPARSE OF SOURCES ======
# Touch the wf_proc.v to force reparse
set wf_proc_file "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/new/wf_proc.v"
if {[file exists $wf_proc_file]} {
    puts "wf_proc.v exists"
}

# Update compile order to trigger reparse
update_compile_order -fileset sources_1
puts "OK compile_order_updated"

# ====== 4. OPEN BD AND UPDATE MODULE REFERENCES ======
open_bd_design $bd

# Try update_module_reference on each module_ref cell
set mref_cells [get_bd_cells -filter {VLNV =~ "*module_ref*"}]
puts "=== UPDATING MODULE REFS ==="
foreach cell $mref_cells {
    set cell_name [get_property NAME $cell]
    puts "UMR_ATTEMPT $cell_name"
    if {[catch {update_module_reference $cell} e]} {
        puts "UMR_FAIL $cell_name: $e"
    } else {
        puts "UMR_OK $cell_name"
    }
}

# Validate BD
puts "=== VALIDATING BD ==="
if {[catch {validate_bd_design} verr]} {
    puts "VALIDATE_ERR: $verr"
} else {
    puts "VALIDATE_OK"
}

save_bd_design
close_bd_design [current_bd_design]
puts "OK BD_SAVED"

# ====== 5. REGENERATE BD TARGETS ======
puts "=== REGENERATING BD TARGETS ==="
if {[catch {generate_target all [get_files $bd]} e]} {
    puts "GEN_TARGET_ERR: $e"
    close_project
    exit 1
} else {
    puts "GEN_TARGET_OK"
}

# ====== 6. UPDATE COMPILE ORDER AND CHECK TOP ======
update_compile_order -fileset sources_1
set top_mod [get_property TOP [current_fileset]]
puts "TOP_MODULE: $top_mod"

# Check if all module ref IPs are valid
puts "=== CHECKING MODULE REF IPs ==="
set ip_files [get_files -of [get_filesets sources_1] -filter {FILE_TYPE == "IP"}]
foreach ip $ip_files {
    puts "IP: $ip"
}

# ====== 7. RESET AND RUN SYNTHESIS ======
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

# ====== 8. IMPLEMENTATION + BITSTREAM ======
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

# ====== 9. COPY BITSTREAM ======
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

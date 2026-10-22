# =============================================================================
# Fix: re-parse sources before opening BD to resolve module_refs
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]

# ====== 1. SET AUTO MODE AND INCLUDE DIR ======
set_property source_mgmt_mode All [current_project]
set wf_cic_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/wf_cic"
set_property include_dirs $wf_cic_dir [get_filesets sources_1]
puts "OK mode=Auto, include_dirs set"

# ====== 2. REMOVE AND RE-ADD RTL FILES TO FORCE REPARSE ======
set new_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/new"
set wf_cic_dir2 "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/wf_cic"
set top_file "D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v"

set all_rtl [list \
    "$new_dir/adc_ovr_detect.v" \
    "$new_dir/adc_sim_conv.v" \
    "$new_dir/sound_rx_ch.v" \
    "$new_dir/sound_rx_common.v" \
    "$new_dir/spi_receiver.v" \
    "$new_dir/wf_proc.v" \
    "$wf_cic_dir2/cic_comb.v" \
    "$wf_cic_dir2/cic_integrator.v" \
    "$wf_cic_dir2/cic_prune_var.v" \
    "$top_file" \
]

# Remove then re-add to force reparse
foreach f $all_rtl {
    if {[file exists $f]} {
        catch {remove_files $f}
        puts "REMOVED: $f"
    }
}

update_compile_order -fileset sources_1

# Re-add
foreach f $all_rtl {
    if {[file exists $f]} {
        add_files -norecurse $f
        puts "ADDED: $f"
    }
}

# Also re-add header files
add_files -norecurse "$wf_cic_dir2/cic_wf1.vh"
add_files -norecurse "$wf_cic_dir2/misc.vh"
puts "ADDED: header files"

update_compile_order -fileset sources_1
puts "OK compile_order_updated"

# ====== 3. OPEN BD AND UPDATE MODULE REFS ======
open_bd_design $bd

set mref_cells [get_bd_cells -filter {VLNV =~ "*module_ref*"}]
puts "=== UPDATING MODULE REFS ==="
foreach cell $mref_cells {
    set cell_name [get_property NAME $cell]
    if {[catch {update_module_reference $cell} e]} {
        puts "UMR_FAIL $cell_name: $e"
    } else {
        puts "UMR_OK $cell_name"
    }
}

# Validate
if {[catch {validate_bd_design} verr]} {
    puts "VALIDATE_ERR: $verr"
} else {
    puts "VALIDATE_OK"
}

save_bd_design
close_bd_design [current_bd_design]
puts "OK BD_SAVED"

# ====== 4. GENERATE TARGETS ======
puts "=== GENERATING TARGETS ==="
if {[catch {generate_target all [get_files $bd]} e]} {
    puts "GEN_TARGET_ERR: $e"
} else {
    puts "GEN_TARGET_OK"
}

# ====== 5. CHECK TOP MODULE ======
update_compile_order -fileset sources_1
set top_mod [get_property TOP [current_fileset]]
puts "TOP_MODULE: $top_mod"

save_project -force
puts "OK PROJECT_SAVED"

close_project
puts "=== DONE ==="
exit

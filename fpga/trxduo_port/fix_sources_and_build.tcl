# =============================================================================
# Fix sources, resolve module refs, and prepare for synthesis
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]

# ====== 1. ADD RTL SOURCE FILES ======
set src_dir "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/new"
set rtl_files [list \
    "adc_ovr_detect.v" \
    "adc_sim_conv.v" \
    "sound_rx_ch.v" \
    "sound_rx_common.v" \
    "spi_receiver.v" \
    "wf_proc.v" \
]

foreach f $rtl_files {
    set path "$src_dir/$f"
    if {[file exists $path]} {
        if {[catch {add_files -norecurse $path} e]} {
            puts "ADD_WARN $f: $e"
        } else {
            puts "ADD_OK $f"
        }
    } else {
        puts "ADD_MISSING $f"
    }
}

# Also add top_trxduo.v and constraints
set top_file "D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v"
if {[file exists $top_file]} {
    if {[catch {add_files -norecurse $top_file} e]} {
        puts "ADD_WARN top_trxduo.v: $e"
    } else {
        puts "ADD_OK top_trxduo.v"
    }
}

set xdc_file "D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc"
if {[file exists $xdc_file]} {
    if {[catch {add_files -fileset constrs_1 -norecurse $xdc_file} e]} {
        puts "ADD_WARN trxduo.xdc: $e"
    } else {
        puts "ADD_OK trxduo.xdc"
    }
}

# ====== 2. SET MANUAL COMPILE ORDER ======
set_property source_mgmt_mode None [current_project]
puts "OK source_mgmt_mode=None"

# ====== 3. UPDATE COMPILE ORDER ======
update_compile_order -fileset sources_1
puts "OK compile_order_updated"

# ====== 4. OPEN BD AND UPDATE MODULE REFS ======
open_bd_design $bd

# Try update_module_reference on each module_ref block
set mref_modules {adc_ovr_detect sound_rx_common wf_proc spi_receiver}
foreach mod $mref_modules {
    set cells [get_bd_cells -filter {VLNV =~ "*module_ref*"} -quiet]
    set matched 0
    foreach cell $cells {
        set cell_name [get_property NAME $cell]
        if {[string match "${mod}_*" $cell_name]} {
            if {[catch {update_module_reference $cell} e]} {
                puts "UMR_WARN $cell_name: $e"
            } else {
                puts "UMR_OK $cell_name"
            }
            set matched 1
        }
    }
    if {!$matched} {
        puts "UMR_NOTFOUND $mod"
    }
}

# ====== 5. VALIDATE BD ======
if {[catch {validate_bd_design} verr]} {
    puts "VALIDATE_ERR: $verr"
} else {
    puts "VALIDATE_OK"
}

save_bd_design
close_bd_design [current_bd_design]
puts "OK BD_SAVED"

# ====== 6. GENERATE TARGETS ======
if {[catch {generate_target all [get_files $bd]} e]} {
    puts "GEN_TARGET_ERR: $e"
} else {
    puts "GEN_TARGET_OK"
}

# ====== 7. SET TOP MODULE ======
set_property TOP top_trxduo [current_fileset]
puts "OK TOP=top_trxduo"

update_compile_order -fileset sources_1
puts "OK compile_order_reupdated"

# ====== 8. REPORT ======
puts "=== SOURCE FILES ==="
set all_srcs [get_files -of [get_filesets sources_1]]
foreach s $all_srcs {
    puts "  $s"
}

puts "=== TOP MODULE ==="
puts "TOP: [get_property TOP [current_fileset]]"

save_project -force
puts "OK PROJECT_SAVED"

close_project
puts "=== ALL DONE ==="
exit

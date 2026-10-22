# =============================================================================
# Debug: check file properties and try to fix source resolution
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

# ====== 1. CHECK FILE PROPERTIES ======
puts "=== CHECKING SOURCE FILES ==="
set src_files [get_files -of [get_filesets sources_1]]
foreach f $src_files {
    set ftype [get_property FILE_TYPE $f]
    set used [get_property USED_IN $f]
    set lib [get_property LIBRARY $f]
    puts "FILE: $f"
    puts "  TYPE=$ftype USED_IN=$used LIB=$lib"
}

# ====== 2. TRY TO READ JUST ONE FILE TO SEE IF IT PARSES ======
puts "=== TESTING FILE PARSING ==="
set test_file "D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/new/adc_ovr_detect.v"
if {[catch {read_verilog $test_file} e]} {
    puts "READ_VERILOG_ERR: $e"
} else {
    puts "READ_VERILOG_OK"
    set modules [find_modules -regexp .*]
    puts "MODULES: $modules"
}

# ====== 3. CHECK IF MODULES EXIST IN THE CURRENT PROJECT ======
puts "=== CURRENT DESIGN MODULES ==="
if {[catch {current_design} cd_err]} {
    puts "NO CURRENT DESIGN: $cd_err"
} else {
    puts "CURRENT DESIGN: [current_design]"
}

# Try to find modules in the project
if {[catch {find_modules -regexp .*} mods]} {
    puts "FIND_MODULES_ERR: $mods"
} else {
    puts "FOUND MODULES: $mods"
}

close_project
puts "=== DONE ==="
exit

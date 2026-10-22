open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

# Check if update_module_reference exists and what it needs
puts "=== HELP ==="
catch {help update_module_reference} he
puts "HELP: $he"

puts "=== CMD_EXISTS ==="
puts "exists: [llength [info commands update_module*]]"
foreach c [info commands update_module*] { puts "CMD: $c" }

puts "=== CELL_PROPS ==="
set cell [get_bd_cells adc_ovr_detect_0]
puts "VLNV: [get_property VLNV $cell]"
puts "CONFIG: [get_property CONFIG $cell -quiet]"

# List all properties
puts "=== ALL_PROPS ==="
foreach p [list_property $cell] {
    set val [get_property $p $cell -quiet]
    if {$val ne ""} { puts "PROP: $p = $val" }
}

# Try update_module_reference with cell object
puts "=== TRY1 ==="
if {[catch {update_module_reference [get_bd_cells adc_ovr_detect_0]} e]} {
    puts "FAIL1: $e"
} else { puts "OK1" }

# Try with cell name string
puts "=== TRY2 ==="
if {[catch {update_module_reference adc_ovr_detect_0} e]} {
    puts "FAIL2: '$e'"
} else { puts "OK2" }

# Try without args (might update all)
puts "=== TRY3 ==="
if {[catch {update_module_reference} e]} {
    puts "FAIL3: '$e'"
} else { puts "OK3" }

# Try upgrade_ip (module refs might be treated as IPs)
puts "=== TRY4 ==="
if {[catch {upgrade_ip [get_bd_cells adc_ovr_detect_0]} e]} {
    puts "FAIL4: $e"
} else { puts "OK4" }

# Check pin widths
puts "=== PIN_CHECK ==="
foreach pin {adc_ovr_detect_0/adc_data_in adc_ovr_detect_0/clk_main adc_ovr_detect_0/ofl_i} {
    set p [get_bd_pins $pin -quiet]
    if {$p ne ""} {
        puts "PIN: $pin LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet]"
    } else {
        puts "MISSING: $pin"
    }
}

puts "=== DONE ==="
close_bd_design [current_bd_design]
exit

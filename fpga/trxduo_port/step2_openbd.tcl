open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
foreach f [get_files -quiet *.vh] {
  set_property file_type {Verilog Header} $f
  puts "FIXED_HEADER: $f"
}
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
if {[catch {open_bd_design $bd} err]} {
  puts "OPEN_BD_ERROR: $err"
} else {
  puts "OPEN_BD_OK"
  puts "CELLS: [llength [get_bd_cells -quiet *]]"
  if {[catch {validate_bd_design} verr]} {
    puts "VALIDATE_ERROR: $verr"
  } else {
    puts "VALIDATE_OK"
  }
  close_bd_design [current_bd_design]
}
exit

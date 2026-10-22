open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
puts "CURRENT_PART: [get_property PART [current_project]]"
set_property PART xc7z020clg400-1 [current_project]
puts "NEW_PART: [get_property PART [current_project]]"
open_bd_design D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd
catch {validate_bd_design} err
puts "VALIDATE_ERR: $err"
close_bd_design [current_bd_design]
save_project
exit

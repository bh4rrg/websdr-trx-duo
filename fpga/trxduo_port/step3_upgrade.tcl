open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd
foreach ip [get_ips] {
  if {[catch {upgrade_ip $ip} e]} {
    puts "UPG_FAIL: [get_property NAME $ip] :: $e"
  } else {
    puts "UPG_OK: [get_property NAME $ip]"
  }
}
if {[catch {validate_bd_design} verr]} {
  puts "VALIDATE_ERROR: $verr"
} else {
  puts "VALIDATE_OK"
}
close_bd_design [current_bd_design]
exit

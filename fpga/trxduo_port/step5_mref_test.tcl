open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

# disconnect adc_data pins from the adc_in net so width change won't collide
foreach pin {adc_ovr_detect_0/adc_data_in sound_rx_common_0/adc_data wf_proc_0/adc_data wf_proc_1/adc_data} {
  set n [get_property NET [get_bd_pins $pin]]
  if {$n ne ""} { disconnect_bd_net $n [get_bd_pins $pin]; puts "DISC $pin from $n" }
}

foreach inst {adc_ovr_detect_0 sound_rx_common_0 wf_proc_0 wf_proc_1} {
  set err ""
  if {[catch {update_module_reference $inst} err]} {
    puts "UMR_FAIL $inst :: err=$err"
    puts "   info=$::errorInfo"
  } else {
    puts "UMR_OK $inst"
  }
}
puts "chk adc_ovr_detect_0/adc_data_in LEFT=[get_property LEFT [get_bd_pins adc_ovr_detect_0/adc_data_in]]"
puts "chk adc_ovr_detect_0/ofl_i = [get_bd_pins adc_ovr_detect_0/ofl_i -quiet]"
puts "chk sound_rx_common_0/adc_data LEFT=[get_property LEFT [get_bd_pins sound_rx_common_0/adc_data]]"
puts "chk wf_proc_0/adc_data LEFT=[get_property LEFT [get_bd_pins wf_proc_0/adc_data]]"
close_bd_design [current_bd_design]
exit

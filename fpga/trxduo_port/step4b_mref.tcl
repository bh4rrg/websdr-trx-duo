open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

foreach m {adc_ovr_detect sound_rx_common wf_proc} {
  if {[catch {update_module_reference $m} e]} { puts "UMR_FAIL $m :: $e" } else { puts "UMR_OK $m" }
}

puts "=== ADC_OVR_PINS ==="
foreach p [get_bd_pins adc_ovr_detect_0/*] { puts "P: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet]" }
puts "=== SRX_PINS ==="
foreach p [get_bd_pins sound_rx_common_0/*] { puts "P: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet]" }
puts "=== WF0_PINS ==="
foreach p [get_bd_pins wf_proc_0/*] { puts "P: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet]" }

if {[catch {validate_bd_design} verr]} { puts "VALIDATE_ERROR: $verr" } else { puts "VALIDATE_OK" }
close_bd_design [current_bd_design]
exit

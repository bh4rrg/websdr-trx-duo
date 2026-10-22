open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

puts "=== HELP ==="
catch {puts [help update_module_reference]} he
puts "HELP_END"

puts "=== MODULE_REF_OBJS ==="
catch {puts "mrefs: [get_bd_module_refs *]"} e1
catch {puts "files: [get_files -filter {NAME =~ adc_ovr_detect.v}]"} e2

puts "=== TRY_INSTANCE_NAMES ==="
foreach inst {adc_ovr_detect_0 sound_rx_common_0 wf_proc_0 wf_proc_1} {
  if {[catch {update_module_reference $inst} e]} { puts "UMR_INST_FAIL $inst :: $e" } else { puts "UMR_INST_OK $inst" }
}
puts "after: adc_ovr_detect_0/adc_data_in LEFT=[get_property LEFT [get_bd_pins adc_ovr_detect_0/adc_data_in]]"
puts "after: has ofl_i? [get_bd_pins adc_ovr_detect_0/ofl_i -quiet]"
puts "after: sound_rx_common_0/adc_data LEFT=[get_property LEFT [get_bd_pins sound_rx_common_0/adc_data]]"
puts "after: wf_proc_0/adc_data LEFT=[get_property LEFT [get_bd_pins wf_proc_0/adc_data]]"

close_bd_design [current_bd_design]
exit

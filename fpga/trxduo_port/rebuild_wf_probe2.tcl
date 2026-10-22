# Rebuild trxduo_flat with decisive wf0 producer/gating probes
open_project D:/websdr-trx-duo/fpga/trxduo_port/trxduo_flat/trxduo_flat.xpr
reset_run synth_1
puts "=== STARTING SYNTHESIS ==="
if {[catch {launch_runs synth_1 -jobs 8} e]} { puts "SYNTH_LAUNCH_ERR: $e"; close_project; exit 1 }
wait_on_run synth_1
set s [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS: $s"
if {$s ne "synth_design Complete!"} { close_project; exit 1 }
reset_run impl_1
puts "=== STARTING IMPL ==="
if {[catch {launch_runs impl_1 -jobs 8 -to_step write_bitstream} e]} { puts "IMPL_LAUNCH_ERR: $e"; close_project; exit 1 }
wait_on_run impl_1
set i [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS: $i"
if {![string match "*write_bitstream Complete!*" $i]} { close_project; exit 1 }
set dir [get_property DIRECTORY [get_runs impl_1]]
file mkdir "D:/websdr-trx-duo/fpga/trxduo_port/out_probe2"
file copy -force "$dir/top_trxduo.bit" "D:/websdr-trx-duo/fpga/trxduo_port/out_probe2/top_probe2.bit"
puts "COPIED: D:/websdr-trx-duo/fpga/trxduo_port/out_probe2/top_probe2.bit"
close_project
exit

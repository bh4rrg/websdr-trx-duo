open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

puts "=== MODULE_COMMANDS ==="
puts [lsort [info commands *module*]]
puts "=== REF_COMMANDS ==="
puts [lsort [info commands *refresh*]]

puts "=== CELLS ==="
foreach c [get_bd_cells *] {
  puts "CELL: [get_property VLNV $c] :: [get_property NAME $c] :: CONFIG=[get_property CONFIG.ENABLE_ADVANCED_OPTIONS $c -quiet]"
}
puts "=== WF_INDEX ==="
puts "wf_proc_0.WF_INDEX=[get_property CONFIG.WF_INDEX [get_bd_cells wf_proc_0] -quiet]"
puts "wf_proc_1.WF_INDEX=[get_property CONFIG.WF_INDEX [get_bd_cells wf_proc_1] -quiet]"
puts "=== PORTS ==="
foreach p [get_bd_ports *] {
  puts "PORT: [get_property NAME $p] DIR=[get_property DIR $p] WIDTH=[get_property WIDTH $p]"
}
puts "=== NETS ==="
foreach n [get_bd_nets *] {
  set pins {}
  foreach pin [get_property PINS $n] { lappend pins $pin }
  puts "NET: [get_property NAME $n] :: $pins"
}
puts "=== INTF_NETS ==="
foreach n [get_bd_intf_nets *] {
  set pins {}
  foreach pin [get_property INTF_PINS $n] { lappend pins $pin }
  puts "IFNET: [get_property NAME $n] :: $pins"
}
close_bd_design [current_bd_design]
exit

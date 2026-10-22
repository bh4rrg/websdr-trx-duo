# 补全 project.tcl 因 fileutil 问题中断的剩余步骤
set project_name led_blinker
open_project tmp/$project_name.xpr

set wrapper tmp/$project_name.srcs/sources_1/bd/system/hdl/system_wrapper.v
add_files -norecurse $wrapper
set_property TOP system_wrapper [current_fileset]

set files [glob -nocomplain cfg/*.xdc projects/$project_name/*.xdc]
if {[llength $files] > 0} {
  add_files -norecurse -fileset constrs_1 $files
}

set_property VERILOG_DEFINE {TOOL_VIVADO} [current_fileset]
set_property STRATEGY Flow_PerfOptimized_high [get_runs synth_1]
close_project
puts "PROJECT_COMPLETION_OK"

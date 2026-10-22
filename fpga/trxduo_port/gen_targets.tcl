open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr

# Check if TCL can see the file
set f "c:/Xilinx/Vivado/2022.2/data/ip/xilinx/axi_protocol_converter_v2_1/xgui/axi_protocol_converter_v2_1.tcl"
puts "FILE_EXISTS: [file exists $f]"
puts "FILE_READABLE: [file readable $f]"

# Try to source the file
if {[catch {source $f} e]} {
    puts "SOURCE_ERR: $e"
} else {
    puts "SOURCE_OK"
}

# Try generating targets without opening BD
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
if {[catch {generate_target all $bd} e]} {
    puts "GEN_TARGET_ERR: $e"
} else {
    puts "GEN_TARGET_OK"
}

# Try opening BD with recovery
if {[catch {open_bd_design $bd} e]} {
    puts "OPEN_BD_ERR: $e"
    # Try to list the IPs in the BD
    set ip_files [get_files -quiet -of [get_ips -quiet]]
    puts "IP_FILES: $ip_files"
} else {
    puts "OPEN_BD_OK"
    close_bd_design [current_bd_design]
}

close_project
exit

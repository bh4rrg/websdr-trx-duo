open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

puts "=== PROJECT_PART ==="
puts "PART: [get_property PART [current_project]]"

puts "=== BD_PORTS ==="
foreach p [get_bd_ports *] {
    puts "PORT: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet]"
}

puts "=== BD_CELLS ==="
foreach c [get_bd_cells -hierarchical *] {
    set type [get_property VLNV $c -quiet]
    if {$type eq ""} { set type [get_property CONFIG.COMPOSITE_OBJ $c -quiet] }
    puts "CELL: [get_property NAME $c] TYPE=$type"
}

puts "=== BD_NETS ==="
foreach n [get_bd_nets *] {
    puts "NET: [get_property NAME $n]"
}

puts "=== PIN_CONNECTIONS ==="
foreach c [get_bd_cells -hierarchical *] {
    foreach pin [get_bd_pins -of $c] {
        set net [get_property NET $pin]
        set name [get_property NAME $pin]
        set cell [get_property NAME $c]
        puts "PIN: $cell/$name -> NET=$net"
    }
}

puts "=== INTF_PINS ==="
foreach c [get_bd_cells -hierarchical *] {
    foreach ipin [get_bd_intf_pins -of $c] {
        set inet [get_property BD_INTF_NET $ipin -quiet]
        puts "IPIN: [get_property NAME $c]/[get_property NAME $ipin] -> INET=$inet"
    }
}

puts "=== PS7_CONFIG ==="
set ps [get_bd_cells processing_system7_0]
puts "FCLK_CLK0: [get_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $ps]"
puts "FCLK_CLK0_BUF: [get_property CONFIG.PCW_FCLK_CLK0_BUF $ps]"
puts "SPI0: [get_property CONFIG.PCW_SPI0_PERIPHERAL_ENABLE $ps]"
puts "SPI0_IO: [get_property CONFIG.PCW_SPI0_SPI0_IO $ps]"

puts "=== MODULE_REFS ==="
foreach mr [get_bd_module_refs *] {
    puts "MREF: [get_property NAME $mr] MODS=[get_property MODULES $mr -quiet]"
}

puts "=== ADC_OVR_PINS ==="
foreach p [get_bd_pins adc_ovr_detect_0/*] {
    puts "P: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet] NET=[get_property NET $p]"
}

puts "=== SOUND_RX_PINS ==="
foreach p [get_bd_pins sound_rx_common_0/*] {
    puts "P: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet] NET=[get_property NET $p]"
}

puts "=== WF0_PINS ==="
foreach p [get_bd_pins wf_proc_0/*] {
    puts "P: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet] NET=[get_property NET $p]"
}

puts "=== SPI_RECV_PINS ==="
foreach p [get_bd_pins spi_receiver_0/*] {
    puts "P: [get_property NAME $p] DIR=[get_property DIR $p] LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet] NET=[get_property NET $p]"
}

puts "=== RST_PINS ==="
foreach p [get_bd_pins rst_design_1_10M/*] {
    puts "P: [get_property NAME $p] DIR=[get_property DIR $p] NET=[get_property NET $p]"
}

puts "=== SND_SENDER_PINS ==="
foreach p [get_bd_pins sound_sender_0/*] {
    puts "P: [get_property NAME $p] DIR=[get_property DIR $p] NET=[get_property NET $p]"
}

puts "=== WF_SENDER_PINS ==="
foreach p [get_bd_pins waterfall_sender_0/*] {
    puts "P: [get_property NAME $p] DIR=[get_property DIR $p] NET=[get_property NET $p]"
}

puts "=== DONE ==="
close_bd_design [current_bd_design]
exit

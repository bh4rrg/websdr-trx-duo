open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

puts "=== ALL_CELLS_HIER ==="
foreach c [get_bd_cells -hierarchical *] { puts "C: [get_property NAME $c]" }

puts "=== PORT_NETS ==="
foreach p [get_bd_ports *] {
  set n [get_property NET [get_bd_ports $p]]
  puts "P: [get_property NAME $p] -> NET=$n"
}

puts "=== CELL_PIN_NETS ==="
foreach cp {adc_ovr_detect_0/adc_data_in adc_ovr_detect_0/clk_main adc_ovr_detect_0/rst_n adc_ovr_detect_0/led_n
            wf_proc_0/adc_data wf_proc_0/in_aclk wf_proc_0/resn_i wf_proc_0/data_ready_i wf_proc_0/command_i wf_proc_0/data_i wf_proc_0/start_out wf_proc_0/wf_axis_tvalid wf_proc_0/wf_axis_tdata
            wf_proc_1/adc_data wf_proc_1/in_aclk
            sound_rx_common_0/adc_data sound_rx_common_0/in_aclk sound_rx_common_0/resn_i sound_rx_common_0/snd_axis_tvalid sound_rx_common_0/snd_axis_tdata sound_rx_common_0/snd_axis_tuser sound_rx_common_0/snd_axis_tlast
            spi_receiver_0/clk_main spi_receiver_0/resn_i spi_receiver_0/data_ready spi_receiver_0/command spi_receiver_0/data
            sound_sender_0/in_bus_TVALID sound_sender_0/in_bus_TREADY sound_sender_0/in_bus_TDATA sound_sender_0/in_bus_TLAST sound_sender_0/in_bus_TKEEP sound_sender_0/in_bus_TSTRB
            sound_sender_0/ap_clk sound_sender_0/ap_rst_n sound_sender_0/m_axi_out_bus_ACLK sound_sender_0/m_axi_out_bus_ARESETN
            waterfall_sender_0/ap_clk waterfall_sender_0/in_bus_TDATA
            rst_design_1_10M/slowest_sync_clk rst_design_1_10M/ext_reset_in rst_design_1_10M/peripheral_aresetn rst_design_1_10M/peripheral_reset
            xlconcat_0/dout xlconstant_0/dout xlconstant_1/dout
            processing_system7_0/FCLK_CLK0 processing_system7_0/FCLK_RESET0_N processing_system7_0/SPI_0_SS processing_system7_0/SPI_0_SCLK processing_system7_0/SPI_0_MOSI processing_system7_0/SPI_0_MISO processing_system7_0/IRQ_F2P} {
  if {[catch {get_bd_pins $cp} obj]} { puts "PIN_MISS: $cp"; continue }
  if {[llength $obj] == 0} { puts "PIN_NONE: $cp"; continue }
  foreach o $obj { puts "PIN: [get_property NAME $o] -> NET=[get_property NET $o] WIDTH=[get_property WIDTH $o -quiet]" }
}

puts "=== MODULE_REF_WIDTH_TEST ==="
puts "wf_proc_0/adc_data width: [get_property WIDTH [get_bd_pins wf_proc_0/adc_data] -quiet]"
puts "sound_rx_common_0/adc_data width: [get_property WIDTH [get_bd_pins sound_rx_common_0/adc_data] -quiet]"
puts "adc_ovr_detect_0/adc_data_in width: [get_property WIDTH [get_bd_pins adc_ovr_detect_0/adc_data_in] -quiet]"
puts "adc_ovr_detect_0 pin list: [get_property NAME [get_bd_pins adc_ovr_detect_0/*]]"

puts "=== INTF_PIN_NETS ==="
foreach ip [get_bd_intf_pins *] {
  puts "IPIN: [get_property NAME $ip] -> NET=[get_property BD_INTF_NET $ip -quiet]"
}

puts "=== SPI_IF ==="
catch {puts [get_property NAME [get_bd_intf_pins processing_system7_0/SPI_0]]} e1
catch {puts [get_property NAME [get_bd_intf_pins spi_receiver_0/spi_s]]} e2

puts "=== ADC_IN_FANOUT ==="
catch {puts "net_of_port: [get_bd_nets -of [get_bd_ports adc_in]]"} e3
catch {puts "pins_on_adc_in_net: [get_property NAME [get_bd_pins -of [get_bd_nets -of [get_bd_ports adc_in]]]]"} e4

close_bd_design [current_bd_design]
exit

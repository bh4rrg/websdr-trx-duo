open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

set ps [get_bd_cells processing_system7_0]

# --- PS7: apply web888 board preset (correct DDR/MIO for TRX DUO, validated by led_blinker) ---
if {[catch {set_property CONFIG.PCW_IMPORT_BOARD_PRESET D:/websdr-trx-duo/src/red-pitaya-notes-web888_bootloader_si5351_driver/cfg/red_pitaya.xml $ps} e]} {
  puts "PRESET_FAIL: $e"
} else {
  puts "PRESET_OK"
}

# Overrides needed for this design (S9 clocking: FCLK0 internal, 40MHz D2 domain)
set_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 40.0 $ps
set_property CONFIG.PCW_FCLK_CLK0_BUF TRUE $ps
set_property CONFIG.PCW_SPI0_PERIPHERAL_ENABLE 1 $ps
set_property CONFIG.PCW_SPI0_SPI0_IO EMIO $ps
puts "PS_OVERRIDE_OK"

# --- BD ports: remove adc_clk output (S9 drove ADC with FCLK; TRX DUO ADC is source-sync input) ---
if {[catch {disconnect_bd_net [get_bd_nets -quiet -of [get_bd_ports adc_clk]] [get_bd_ports adc_clk]} e]} { puts "DISC_ADCCLK: $e" }
delete_bd_objs [get_bd_ports -quiet adc_clk]
puts "PORT_ADCCLK_DELETED"

# --- adc_in port: widen 12 -> 14 ---
disconnect_bd_net [get_bd_nets adc_in[0]] [get_bd_ports adc_in[0]]
delete_bd_objs [get_bd_ports adc_in]
create_bd_port -dir I -from 13 -to 0 adc_in
puts "PORT_ADC_IN_WIDENED"

# --- new input port adc_ofl (TRX DUO overflow flag, active high) ---
create_bd_port -dir I adc_ofl
puts "PORT_ADC_OFL_ADDED"

if {[catch {validate_bd_design} verr]} { puts "VALIDATE_ERROR: $verr" } else { puts "VALIDATE_OK" }
close_bd_design [current_bd_design]
exit

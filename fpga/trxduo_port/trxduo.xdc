# TRX DUO (XC7Z020) constraints for OpenZynqSDR port
# ADC: 16-bit 122.88MHz, channel A [15:2] used (14-bit)

# --- ADC differential clock (122.88MHz DCO from ADC) ---
set_property PACKAGE_PIN U18 [get_ports adc_clk_p_i]
set_property PACKAGE_PIN U19 [get_ports adc_clk_n_i]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_p_i]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_n_i]
create_clock -period 8.138 -name adc_clk -waveform {0.000 4.069} [get_ports adc_clk_p_i]

# --- ADC data bus A (16-bit, LVCMOS18) ---
# Only [15:2] used = 14 bits
set_property PACKAGE_PIN V16 [get_ports {adc_dat_a_i[15]}]
set_property PACKAGE_PIN T16 [get_ports {adc_dat_a_i[14]}]
set_property PACKAGE_PIN V15 [get_ports {adc_dat_a_i[13]}]
set_property PACKAGE_PIN T15 [get_ports {adc_dat_a_i[12]}]
set_property PACKAGE_PIN T14 [get_ports {adc_dat_a_i[11]}]
set_property PACKAGE_PIN V13 [get_ports {adc_dat_a_i[10]}]
set_property PACKAGE_PIN V12 [get_ports {adc_dat_a_i[9]}]
set_property PACKAGE_PIN W13 [get_ports {adc_dat_a_i[8]}]
set_property PACKAGE_PIN Y14 [get_ports {adc_dat_a_i[7]}]
set_property PACKAGE_PIN W14 [get_ports {adc_dat_a_i[6]}]
set_property PACKAGE_PIN W15 [get_ports {adc_dat_a_i[5]}]
set_property PACKAGE_PIN Y16 [get_ports {adc_dat_a_i[4]}]
set_property PACKAGE_PIN W16 [get_ports {adc_dat_a_i[3]}]
set_property PACKAGE_PIN Y17 [get_ports {adc_dat_a_i[2]}]
# Bits [1:0] unused, not constrained

set_property IOSTANDARD LVCMOS18 [get_ports {adc_dat_a_i[*]}]
set_property IOB TRUE [get_ports {adc_dat_a_i[*]}]

# --- ADC overflow flag (P20) ---
set_property PACKAGE_PIN P20 [get_ports adc_ofl_i]
set_property IOSTANDARD LVCMOS18 [get_ports adc_ofl_i]

# --- LED (F16) ---
set_property PACKAGE_PIN F16 [get_ports led_o]
set_property IOSTANDARD LVCMOS33 [get_ports led_o]

# --- Timing: ADC clock is the main PL clock ---
# FCLK_CLK0 (40MHz) is auto-constrained by PS7 IP
# clk_adc (122.88MHz) is constrained above via create_clock
# Async clock domains: adc_clk vs clk_fpga_0
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks adc_clk] \
    -group [get_clocks -include_generated_clocks clk_fpga_0]

# Relax I/O timing on ADC data (source-synchronous, captured by clk_adc)
set_input_delay -clock [get_clocks adc_clk] -max 2.0 [get_ports {adc_dat_a_i[*]}]
set_input_delay -clock [get_clocks adc_clk] -min 0.5 [get_ports {adc_dat_a_i[*]}]
set_input_delay -clock [get_clocks adc_clk] -max 2.0 [get_ports adc_ofl_i]
set_input_delay -clock [get_clocks adc_clk] -min 0.5 [get_ports adc_ofl_i]

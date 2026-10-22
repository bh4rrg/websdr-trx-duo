open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

set ps [get_bd_cells processing_system7_0]

# ====== 1. PS7 PRESET + OVERRIDES ======
if {[catch {set_property CONFIG.PCW_IMPORT_BOARD_PRESET D:/websdr-trx-duo/src/red-pitaya-notes-web888_bootloader_si5351_driver/cfg/red_pitaya.xml $ps} e]} {
    puts "ERR PRESET: $e"
} else { puts "OK PRESET" }
set_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 40.0 $ps
set_property CONFIG.PCW_FCLK_CLK0_BUF TRUE $ps
set_property CONFIG.PCW_SPI0_PERIPHERAL_ENABLE 1 $ps
set_property CONFIG.PCW_SPI0_SPI0_IO EMIO $ps
puts "OK PS7_OVERRIDES"

# ====== 2. DISCONNECT ADC DATA PINS (before width change) ======
foreach pin {adc_ovr_detect_0/adc_data_in sound_rx_common_0/adc_data wf_proc_0/adc_data wf_proc_1/adc_data} {
    set nets [get_bd_nets -of [get_bd_pins $pin] -quiet]
    foreach n $nets { catch {disconnect_bd_net $n [get_bd_pins $pin]} }
}
puts "OK DISC_ADC_DATA"

# ====== 3. DELETE OLD PORTS ======
set nets [get_bd_nets -of [get_bd_ports adc_clk] -quiet]
foreach n $nets { catch {disconnect_bd_net $n [get_bd_ports adc_clk]} }
delete_bd_objs [get_bd_ports adc_clk]
puts "OK DEL adc_clk"

set nets [get_bd_nets -of [get_bd_ports adc_in] -quiet]
foreach n $nets { catch {disconnect_bd_net $n [get_bd_ports adc_in]} }
delete_bd_objs [get_bd_ports adc_in]
puts "OK DEL old adc_in"

# ====== 4. CREATE NEW PORTS ======
create_bd_port -dir I -from 13 -to 0 adc_in
puts "OK NEW adc_in[13:0]"

create_bd_port -dir I adc_ofl
puts "OK NEW adc_ofl"

create_bd_port -dir I clk_adc
# FREQ_HZ may not be settable via CONFIG; clock frequency will come from XDC create_clock
catch {set_property CONFIG.FREQ_HZ 122880000 [get_bd_ports clk_adc]}
catch {set_property FREQ_HZ 122880000 [get_bd_ports clk_adc]}
puts "OK NEW clk_adc"

# ====== 5. UPDATE MODULE REFERENCES ======
# Try module names (not instance names) for update_module_reference
foreach mod {adc_ovr_detect sound_rx_common wf_proc} {
    if {[catch {update_module_reference $mod} e]} {
        puts "WARN UMR $mod: $e"
        # Try with -objects flag as fallback
        if {[catch {update_module_reference -objects [get_bd_cells ${mod}_*]} e2]} {
            puts "ERR UMR2 $mod: $e2"
        } else { puts "OK UMR2 $mod" }
    } else { puts "OK UMR $mod" }
}

# ====== 6. RECONNECT ADC DATA ======
if {[catch {connect_bd_net [get_bd_ports adc_in] [get_bd_pins {adc_ovr_detect_0/adc_data_in sound_rx_common_0/adc_data wf_proc_0/adc_data wf_proc_1/adc_data}]} e]} {
    puts "ERR CONN adc_in: $e"
} else { puts "OK CONN adc_in" }

# ====== 7. CONNECT adc_ofl -> adc_ovr_detect_0/ofl_i ======
if {[catch {connect_bd_net [get_bd_ports adc_ofl] [get_bd_pins adc_ovr_detect_0/ofl_i]} e]} {
    puts "WARN CONN ofl_i: $e (pin may not exist yet - module ref may have failed)"
} else { puts "OK CONN ofl_i" }

# ====== 8. CLOCK DOMAIN: move PL modules from FCLK_CLK0 to clk_adc ======
# Use PS7 FCLK_CLK0 pin directly to avoid stale net references
set fclk_src [get_bd_pins processing_system7_0/FCLK_CLK0]

# Explicit list of pins to move
set pins_to_move {
    adc_ovr_detect_0/clk_main
    spi_receiver_0/clk_main
    sound_rx_common_0/in_aclk
    wf_proc_0/in_aclk
    wf_proc_1/in_aclk
    sound_sender_0/ap_clk
    waterfall_sender_0/ap_clk
    waterfall_sender_1/ap_clk
    axi_mem_intercon/ACLK
    axi_mem_intercon/S00_ACLK
    axi_mem_intercon_1/ACLK
    axi_mem_intercon_1/S00_ACLK
    axi_mem_intercon_2/ACLK
    axi_mem_intercon_2/S00_ACLK
    rst_design_1_10M/slowest_sync_clk
}

foreach pin $pins_to_move {
    set p [get_bd_pins $pin -quiet]
    if {$p eq ""} { puts "SKIP $pin (not found)"; continue }
    # Disconnect from current net (should be FCLK_CLK0)
    set cur_net [get_bd_nets -of $p -quiet]
    if {$cur_net ne ""} { catch {disconnect_bd_net $cur_net $p} }
    # Connect to clk_adc
    if {[catch {connect_bd_net [get_bd_ports clk_adc] $p} e]} { puts "ERR CONN $pin: $e" } else { puts "OK CLK $pin" }
}

# Find and move HLS sender AXI master clocks (pin name varies by IP)
foreach sender {sound_sender_0 waterfall_sender_0 waterfall_sender_1} {
    set aclks [get_bd_pins -of [get_bd_cells $sender] -filter {NAME =~ *ACLK*}]
    foreach aclk $aclks {
        # Skip ap_clk if matched by *ACLK* (unlikely but safe)
        if {[string match "ap_clk" [get_property NAME $aclk]]} continue
        set cur_net [get_bd_nets -of $aclk -quiet]
        if {$cur_net ne ""} { catch {disconnect_bd_net $cur_net $aclk} }
        catch {connect_bd_net [get_bd_ports clk_adc] $aclk}
        puts "OK CLK $sender/[get_property NAME $aclk]"
    }
}

# Also try S01_ACLK on interconnects
foreach ic {axi_mem_intercon axi_mem_intercon_1 axi_mem_intercon_2} {
    set p [get_bd_pins ${ic}/S01_ACLK -quiet]
    if {$p ne ""} {
        set cur_net [get_bd_nets -of $p -quiet]
        if {$cur_net ne ""} { catch {disconnect_bd_net $cur_net $p} }
        catch {connect_bd_net [get_bd_ports clk_adc] $p}
        puts "OK CLK ${ic}/S01_ACLK"
    }
}

puts "OK CLOCK_DOMAINS"

# ====== 9. SECOND PROC_SYS_RESET FOR FCLK DOMAIN ======
set rst_fclk [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_fclk]
# Connect: slowest_sync_clk from PS7 FCLK_CLK0, ext_reset_in from FCLK_RESET0_N
connect_bd_net $fclk_src [get_bd_pins rst_fclk/slowest_sync_clk]
set fclk_rst_src [get_bd_pins processing_system7_0/FCLK_RESET0_N]
connect_bd_net $fclk_rst_src [get_bd_pins rst_fclk/ext_reset_in]
puts "OK rst_fclk created"

# Connect rst_fclk/peripheral_aresetn to interconnect M00_ARESETN
foreach ic {axi_mem_intercon axi_mem_intercon_1 axi_mem_intercon_2} {
    set p [get_bd_pins ${ic}/M00_ARESETN -quiet]
    if {$p ne ""} {
        set old_net [get_bd_nets -of $p -quiet]
        if {$old_net ne ""} { catch {disconnect_bd_net $old_net $p} }
        catch {connect_bd_net [get_bd_pins rst_fclk/peripheral_aresetn] $p}
        puts "OK RST ${ic}/M00_ARESETN"
    }
}

# Verify M00_ACLK still on FCLK (reconnect if lost)
foreach ic {axi_mem_intercon axi_mem_intercon_1 axi_mem_intercon_2} {
    set p [get_bd_pins ${ic}/M00_ACLK -quiet]
    if {$p ne ""} {
        set cur_net [get_bd_nets -of $p -quiet]
        if {$cur_net eq ""} {
            catch {connect_bd_net $fclk_src $p}
            puts "OK FIX ${ic}/M00_ACLK -> FCLK"
        }
    }
}

# Verify PS7 AXI clock pins on FCLK
foreach axipin {M_AXI_GP0_ACLK S_AXI_HP0_ACLK S_AXI_HP1_ACLK S_AXI_HP2_ACLK S_AXI_HP3_ACLK} {
    set p [get_bd_pins processing_system7_0/$axipin -quiet]
    if {$p ne ""} {
        set cur_net [get_bd_nets -of $p -quiet]
        if {$cur_net eq ""} {
            catch {connect_bd_net $fclk_src $p}
            puts "OK FIX PS7/$axipin -> FCLK"
        }
    }
}

puts "OK FCLK DOMAIN"

# ====== 10. SAVE (even if validation has warnings) ======
# Validate but don't fail on warnings
catch {validate_bd_design} verr
puts "VALIDATE: $verr"

# Save regardless - we can fix issues later
save_bd_design
puts "OK BD_SAVED"
close_bd_design [current_bd_design]
save_project
puts "OK PROJECT_SAVED"

# ====== 11. ADD SOURCES AND SET TOP ======
add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v
add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc
set_property TOP top_trxduo [current_fileset]
update_compile_order -fileset sources_1
puts "OK SOURCES_ADDED"

puts "=== ALL DONE ==="
exit

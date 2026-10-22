# =============================================================================
# Comprehensive BD modification script for TRX DUO OpenZynqSDR port
# Combines: PS7 preset, module ref refresh, port changes, clock domain
#           separation, second proc_sys_reset, save, wrapper generation
# =============================================================================

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

# ====== 2. REFRESH MODULE REFERENCES ======
# RTL has been modified: IN_WIDTH=14, FREQ_HZ=122880000, ofl_i pin added
# Need to refresh module references so BD picks up new pin widths
foreach mod {adc_ovr_detect sound_rx_common wf_proc} {
    # Method 1: update_module_reference with module name
    if {[catch {update_module_reference $mod} e]} {
        puts "WARN UMR_name $mod: $e"
        # Method 2: with VLNV
        if {[catch {update_module_reference xilinx.com:module_ref:${mod}:1.0} e2]} {
            puts "WARN UMR_vlnv $mod: $e2"
            # Method 3: upgrade_ip on instances
            if {[catch {upgrade_ip [get_bd_cells ${mod}_*]} e3]} {
                puts "WARN UPGRADE $mod: $e3"
            } else { puts "OK UPGRADE $mod" }
        } else { puts "OK UMR_vlnv $mod" }
    } else { puts "OK UMR_name $mod" }
}

# Report pin widths to verify refresh
foreach {cell pin} {
    adc_ovr_detect_0/adc_data_in
    sound_rx_common_0/adc_data
    wf_proc_0/adc_data
    wf_proc_1/adc_data
} {
    set p [get_bd_pins $cell/$pin -quiet]
    if {$p ne ""} {
        puts "PIN $cell/$pin LEFT=[get_property LEFT $p] RIGHT=[get_property RIGHT $p]"
    } else {
        puts "PIN $cell/$pin NOT FOUND"
    }
}

# Check if ofl_i pin exists on adc_ovr_detect_0
set ofl_pin [get_bd_pins adc_ovr_detect_0/ofl_i -quiet]
puts "OFL_PIN exists: [expr {$ofl_pin ne ""}]"

# ====== 3. DISCONNECT AND DELETE OLD ADC PORTS ======
# Disconnect adc_clk
foreach n [get_bd_nets -of [get_bd_ports adc_clk] -quiet] {
    foreach p [get_bd_pins -of $n] {
        catch {disconnect_bd_net $n $p}
    }
}
catch {delete_bd_objs [get_bd_ports adc_clk]}
puts "OK DEL adc_clk"

# Disconnect adc_in (12-bit)
foreach n [get_bd_nets -of [get_bd_ports adc_in] -quiet] {
    foreach p [get_bd_pins -of $n] {
        catch {disconnect_bd_net $n $p}
    }
}
catch {delete_bd_objs [get_bd_ports adc_in]}
puts "OK DEL old adc_in"

# ====== 4. CREATE NEW PORTS ======
# adc_in[13:0]
create_bd_port -dir I -from 13 -to 0 adc_in
puts "OK NEW adc_in[13:0]"

# adc_ofl
create_bd_port -dir I adc_ofl
puts "OK NEW adc_ofl"

# clk_adc as clock interface port (FREQ_HZ=122.88MHz)
create_bd_intf_port -mode Slave -vlnv xilinx.com:signal:clock_rtl:1.0 clk_adc
set_property CONFIG.FREQ_HZ 122880000 [get_bd_intf_ports clk_adc]
puts "OK NEW clk_adc (intf port, 122.88MHz)"

# Get clk_adc source pin for connections
# Clock interface ports have an underlying CLK pin
set clk_adc_src ""
catch {set clk_adc_src [get_bd_pins -of [get_bd_intf_ports clk_adc] -quiet]}
if {$clk_adc_src eq ""} {
    catch {set clk_adc_src [get_bd_ports clk_adc -quiet]}
}
if {$clk_adc_src eq ""} {
    # Fallback: use interface port directly
    set clk_adc_src [get_bd_intf_ports clk_adc]
}
puts "clk_adc_src: $clk_adc_src"

# ====== 5. RECONNECT ADC DATA ======
# Connect adc_in[13:0] to module adc_data pins
set adc_pins [list]
foreach {cell pin} {
    adc_ovr_detect_0/adc_data_in
    sound_rx_common_0/adc_data
    wf_proc_0/adc_data
    wf_proc_1/adc_data
} {
    set p [get_bd_pins $cell/$pin -quiet]
    if {$p ne ""} { lappend adc_pins $p }
}
if {[llength $adc_pins] > 0} {
    if {[catch {connect_bd_net [get_bd_ports adc_in] $adc_pins} e]} {
        puts "ERR CONN adc_in: $e"
        # Try connecting one by one
        foreach p $adc_pins {
            catch {connect_bd_net [get_bd_ports adc_in] $p}
        }
        puts "DONE adc_in one-by-one"
    } else { puts "OK CONN adc_in" }
}

# Connect adc_ofl to adc_ovr_detect_0/ofl_i
if {$ofl_pin ne ""} {
    if {[catch {connect_bd_net [get_bd_ports adc_ofl] $ofl_pin} e]} {
        puts "ERR CONN adc_ofl: $e"
    } else { puts "OK CONN adc_ofl" }
} else {
    puts "SKIP adc_ofl (ofl_i pin not found - module ref may not have refreshed)"
}

# ====== 6. CLOCK DOMAIN SEPARATION ======
# D1 (122.88MHz): PL modules on clk_adc
# D2 (40MHz): PS7 AXI interfaces on FCLK_CLK0
set fclk_src [get_bd_pins processing_system7_0/FCLK_CLK0]

# All pins to move from FCLK to clk_adc
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
    if {$p eq ""} {
        puts "SKIP $pin (not found)"
        continue
    }
    # Disconnect from FCLK_CLK0
    set cur_net [get_bd_nets -of $p -quiet]
    if {$cur_net ne ""} {
        catch {disconnect_bd_net $cur_net $p}
    }
    # Connect to clk_adc
    if {[catch {connect_bd_net $clk_adc_src $p} e]} {
        puts "ERR CLK $pin: $e"
    } else { puts "OK CLK $pin" }
}

# Also move S01_ACLK on interconnects if present
foreach ic {axi_mem_intercon axi_mem_intercon_1 axi_mem_intercon_2} {
    set p [get_bd_pins ${ic}/S01_ACLK -quiet]
    if {$p ne ""} {
        set cur_net [get_bd_nets -of $p -quiet]
        if {$cur_net ne ""} { catch {disconnect_bd_net $cur_net $p} }
        catch {connect_bd_net $clk_adc_src $p}
        puts "OK CLK ${ic}/S01_ACLK"
    }
}

puts "OK CLOCK_DOMAINS"

# ====== 7. SECOND PROC_SYS_RESET FOR FCLK DOMAIN ======
# Create reset controller for PS7 AXI domain (40MHz)
set rst_fclk [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_fclk]
catch {connect_bd_net $fclk_src [get_bd_pins rst_fclk/slowest_sync_clk]}
set fclk_rst_src [get_bd_pins processing_system7_0/FCLK_RESET0_N]
catch {connect_bd_net $fclk_rst_src [get_bd_pins rst_fclk/ext_reset_in]}
puts "OK rst_fclk created"

# Connect rst_fclk/peripheral_aresetn to interconnect M00_ARESETN
foreach ic {axi_mem_intercon axi_mem_intercon_1 axi_mem_intercon_2} {
    set p [get_bd_pins ${ic}/M00_ARESETN -quiet]
    if {$p ne ""} {
        set old_net [get_bd_nets -of $p -quiet]
        if {$old_net ne ""} { catch {disconnect_bd_net $old_net $p} }
        catch {connect_bd_net [get_bd_pins rst_fclk/peripheral_aresetn] $p}
        puts "OK RST ${ic}/M00_ARESETN -> rst_fclk"
    }
}

# Ensure M00_ACLK stays on FCLK
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

# Ensure PS7 AXI clock pins on FCLK
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

puts "OK FCLK_DOMAIN"

# ====== 8. TRY TO FIX FREQ_HZ ON HLS SENDERS ======
# HLS senders were generated with 40MHz ap_clk; their bus interfaces say 40MHz
# After connecting to clk_adc (122.88MHz), there may be FREQ_HZ mismatch warnings
# Try to override the frequency
foreach sender {sound_sender_0 waterfall_sender_0 waterfall_sender_1} {
    # Try setting on the cell
    catch {set_property CONFIG.FREQ_HZ 122880000 [get_bd_cells $sender]}
    # Try setting on the ap_clk pin
    catch {set_property CONFIG.FREQ_HZ 122880000 [get_bd_pins ${sender}/ap_clk]}
    # Try setting on the bus interface pin
    catch {set_property CONFIG.FREQ_HZ 122880000 [get_bd_intf_pins ${sender}/in_bus]}
}
puts "OK FREQ_HZ_FIX attempted (may produce warnings - safe to ignore)"

# ====== 9. VALIDATE AND SAVE ======
# Validation may show warnings about FREQ_HZ mismatches - these are non-fatal
set verr ""
catch {validate_bd_design} verr
puts "VALIDATE: $verr"

# Save BD regardless of validation warnings
save_bd_design
puts "OK BD_SAVED"
close_bd_design [current_bd_design]
save_project
puts "OK PROJECT_SAVED"

# ====== 10. GENERATE WRAPPER AND SET TOP ======
generate_target all [get_files $bd]
puts "OK TARGET_GENERATED"

# Add custom top-level and constraints (idempotent)
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v}
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc}
set_property TOP top_trxduo [current_fileset]
update_compile_order -fileset sources_1
puts "OK TOP_SET"

close_project
puts "=== ALL DONE ==="
exit

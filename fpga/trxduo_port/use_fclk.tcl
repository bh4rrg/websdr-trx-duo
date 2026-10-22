# =============================================================================
# Use FCLK_CLK0 at 122.88MHz instead of separate clk_adc port
# This eliminates all FREQ_HZ mismatches since FCLK_CLK0 is the BD clock source
# ADC clock is only used in top_trxduo.v for data capture (not in BD)
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

set ps [get_bd_cells processing_system7_0]

# ====== 1. SET FCLK_CLK0 TO 122.88MHz ======
set_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 122.88 $ps
puts "OK FCLK_CLK0=122.88MHz"
puts "  FCLK_CLK0 FREQ_HZ: [get_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $ps]"

# ====== 2. DELETE clk_adc PORT ======
# First disconnect all pins from clk_adc
set nets [get_bd_nets -quiet -of [get_bd_ports clk_adc -quiet]]
foreach n $nets {
    foreach p [get_bd_pins -quiet -of $n] {
        catch {disconnect_bd_net $n $p}
    }
}
# Also try via interface port
set nets [get_bd_nets -quiet -of [get_bd_intf_ports clk_adc -quiet]]
foreach n $nets {
    foreach p [get_bd_pins -quiet -of $n] {
        catch {disconnect_bd_net $n $p}
    }
}
catch {delete_bd_objs [get_bd_ports clk_adc -quiet]}
catch {delete_bd_objs [get_bd_intf_ports clk_adc -quiet]}
puts "OK DEL clk_adc"

# ====== 3. CONNECT ALL PL CLOCKS TO FCLK_CLK0 ======
set fclk [get_bd_pins processing_system7_0/FCLK_CLK0]

set all_clk_pins {
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
    rst_fclk/slowest_sync_clk
}

foreach pin $all_clk_pins {
    set p [get_bd_pins $pin -quiet]
    if {$p eq ""} { puts "SKIP $pin (not found)"; continue }
    # Disconnect from current net
    set cur_net [get_bd_nets -quiet -of $p]
    if {$cur_net ne ""} { catch {disconnect_bd_net $cur_net $p} }
    # Connect to FCLK_CLK0
    if {[catch {connect_bd_net $fclk $p} e]} {
        puts "ERR $pin: $e"
    } else {
        puts "OK $pin"
    }
}

# Also connect S01_ACLK if present
foreach ic {axi_mem_intercon axi_mem_intercon_1 axi_mem_intercon_2} {
    set p [get_bd_pins ${ic}/S01_ACLK -quiet]
    if {$p ne ""} {
        set cur_net [get_bd_nets -quiet -of $p]
        if {$cur_net ne ""} { catch {disconnect_bd_net $cur_net $p} }
        catch {connect_bd_net $fclk $p}
        puts "OK ${ic}/S01_ACLK"
    }
}

# Connect PS7 AXI clocks to FCLK_CLK0
foreach axipin {M_AXI_GP0_ACLK S_AXI_HP0_ACLK S_AXI_HP1_ACLK S_AXI_HP2_ACLK S_AXI_HP3_ACLK} {
    set p [get_bd_pins processing_system7_0/$axipin -quiet]
    if {$p ne ""} {
        set cur_net [get_bd_nets -quiet -of $p]
        if {$cur_net eq ""} {
            catch {connect_bd_net $fclk $p}
            puts "OK PS7/$axipin"
        }
    }
}

# ====== 4. CONNECT RESET TO FCLK_RESET0_N ======
set fclk_rst [get_bd_pins processing_system7_0/FCLK_RESET0_N]
# rst_design_1_10M already connected, but verify
set rst_pin [get_bd_pins rst_design_1_10M/ext_reset_in -quiet]
if {$rst_pin ne ""} {
    set cur_net [get_bd_nets -quiet -of $rst_pin]
    if {$cur_net eq ""} {
        catch {connect_bd_net $fclk_rst $rst_pin}
        puts "OK rst_design_1_10M/ext_reset_in"
    }
}

# ====== 5. REPORT FREQ_HZ VALUES ======
puts "=== FREQ_HZ REPORT ==="
puts "FCLK_CLK0: [get_property CONFIG.FREQ_HZ $fclk -quiet]"
foreach cell {sound_rx_common_0 wf_proc_0 wf_proc_1 sound_sender_0 waterfall_sender_0 waterfall_sender_1 adc_ovr_detect_0 spi_receiver_0} {
    set clk_pin ""
    foreach candidate {in_aclk ap_clk clk_main} {
        set p [get_bd_pins ${cell}/$candidate -quiet]
        if {$p ne ""} { set clk_pin $p; break }
    }
    if {$clk_pin ne ""} {
        set freq [get_property CONFIG.FREQ_HZ $clk_pin -quiet]
        set net [get_bd_nets -quiet -of $clk_pin]
        set net_name "DISCONNECTED"
        if {$net ne ""} { set net_name [get_property NAME $net] }
        puts "$cell: FREQ_HZ=$freq net=$net_name"
    }
}

# ====== 6. SAVE AND GENERATE ======
catch {validate_bd_design} verr
puts "VALIDATE: $verr"

save_bd_design
puts "OK BD_SAVED"
close_bd_design [current_bd_design]
catch {save_project -force}
puts "OK PROJECT_SAVED"

# Generate target
if {[catch {generate_target all [get_files $bd]} e]} {
    puts "GEN_TARGET_ERR: $e"
} else {
    puts "GEN_TARGET_OK"
}

# Set top
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v}
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc}
set_property TOP top_trxduo [current_fileset]
update_compile_order -fileset sources_1
puts "OK TOP_SET"

close_project
puts "=== ALL DONE ==="
exit

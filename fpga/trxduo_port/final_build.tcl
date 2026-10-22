# =============================================================================
# Final BD fix: refresh module refs (FREQ_HZ removed from RTL), set HLS FREQ_HZ=125MHz
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

# ====== 1. REFRESH MODULE REFERENCES ======
# RTL changed: FREQ_HZ removed from X_INTERFACE_PARAMETER
# Modules should now inherit FREQ_HZ from connected clock (FCLK_CLK0=125MHz)
foreach mod {adc_ovr_detect sound_rx_common wf_proc} {
    if {[catch {update_module_reference $mod} e]} {
        puts "WARN UMR $mod: $e"
        if {[catch {upgrade_ip [get_bd_cells ${mod}_*]} e2]} {
            puts "WARN UPGRADE $mod: $e2"
        } else { puts "OK UPGRADE $mod" }
    } else { puts "OK UMR $mod" }
}

# ====== 2. SET HLS SENDER FREQ_HZ TO 125MHZ ======
# FCLK_CLK0 is 125MHz (PS7 PLL can't do 122.88MHz exactly)
# HLS senders were set to 122880000, need to match FCLK_CLK0=125000000
foreach sender {sound_sender_0 waterfall_sender_0 waterfall_sender_1} {
    catch {set_property CONFIG.FREQ_HZ 125000000 [get_bd_cells $sender]}
    catch {set_property CONFIG.FREQ_HZ 125000000 [get_bd_pins ${sender}/ap_clk]}
    catch {set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins ${sender}/in_bus]}
    catch {set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins ${sender}/m_axi_out_bus]}
}
puts "OK HLS FREQ_HZ=125MHz"

# ====== 3. REPORT FREQ_HZ ======
puts "=== FREQ_HZ REPORT ==="
set fclk [get_bd_pins processing_system7_0/FCLK_CLK0]
puts "FCLK_CLK0: [get_property CONFIG.FREQ_HZ $fclk]"
foreach cell {sound_rx_common_0 wf_proc_0 wf_proc_1 sound_sender_0 waterfall_sender_0 waterfall_sender_1 adc_ovr_detect_0 spi_receiver_0} {
    set clk_pin ""
    foreach candidate {in_aclk ap_clk clk_main} {
        set p [get_bd_pins ${cell}/$candidate -quiet]
        if {$p ne ""} { set clk_pin $p; break }
    }
    if {$clk_pin ne ""} {
        set freq [get_property CONFIG.FREQ_HZ $clk_pin -quiet]
        puts "$cell: FREQ_HZ=$freq"
    }
}

# ====== 4. SAVE AND GENERATE ======
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

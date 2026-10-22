# =============================================================================
# Reconnect clk_adc interface port to all PL clock pins
# The BD was saved with clk_adc as interface port (122.88MHz) but pins disconnected
# =============================================================================

open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

# ====== 1. CHECK CURRENT STATE ======
puts "=== clk_adc port type ==="
set intf_port [get_bd_intf_ports clk_adc -quiet]
set reg_port [get_bd_ports clk_adc -quiet]
puts "intf_port: $intf_port"
puts "reg_port: $reg_port"

# Check the orphaned net
set clk_net [get_bd_nets clk_adc_1 -quiet]
puts "clk_adc_1 net: $clk_net"
if {$clk_net ne ""} {
    puts "Pins on clk_adc_1:"
    foreach p [get_bd_pins -quiet -of $clk_net] {
        puts "  [get_property NAME $p]"
    }
}

# ====== 2. TRY BD AUTOMATION TO CONNECT CLK_ADC ======
puts "=== Trying apply_bd_automation ==="
if {[catch {apply_bd_automation -rule xilinx.com:bd_rule:clk -source [get_bd_intf_ports clk_adc]} e]} {
    puts "BD_AUTO_ERR: $e"
} else {
    puts "BD_AUTO_OK"
}

# Check if any pins got connected
set connected 0
foreach p {adc_ovr_detect_0/clk_main sound_rx_common_0/in_aclk sound_sender_0/ap_clk} {
    set pin [get_bd_pins $p -quiet]
    if {$pin ne ""} {
        set net [get_bd_nets -quiet -of $pin]
        if {$net ne ""} {
            puts "  $p connected to: [get_property NAME $net]"
            incr connected
        } else {
            puts "  $p still disconnected"
        }
    }
}

# ====== 3. MANUAL CONNECTION ATTEMPTS ======
if {$connected == 0} {
    puts "=== BD automation failed, trying manual ==="

    # Method A: connect_bd_intf_net for interface clock pins
    set intf_clk_pins {
        sound_rx_common_0/in_aclk
        wf_proc_0/in_aclk
        wf_proc_1/in_aclk
        sound_sender_0/ap_clk
        waterfall_sender_0/ap_clk
        waterfall_sender_1/ap_clk
    }
    foreach pin $intf_clk_pins {
        set p [get_bd_pins $pin -quiet]
        if {$p eq ""} continue
        # Disconnect from old net
        set old_net [get_bd_nets -quiet -of $p]
        if {$old_net ne ""} { catch {disconnect_bd_net $old_net $p} }
        # Try connect_bd_intf_net (connects interface port to interface pin)
        if {[catch {connect_bd_intf_net [get_bd_intf_ports clk_adc] $p} e]} {
            puts "  INTF_NET $pin: $e"
            # Try connect_bd_net with interface port
            if {[catch {connect_bd_net [get_bd_intf_ports clk_adc] $p} e2]} {
                puts "  NET $pin: $e2"
            } else {
                puts "  OK NET $pin"
            }
        } else {
            puts "  OK INTF $pin"
        }
    }

    # Method B: For regular pins, try to find underlying port
    set reg_clk_pins {
        adc_ovr_detect_0/clk_main
        spi_receiver_0/clk_main
        axi_mem_intercon/ACLK
        axi_mem_intercon/S00_ACLK
        axi_mem_intercon_1/ACLK
        axi_mem_intercon_1/S00_ACLK
        axi_mem_intercon_2/ACLK
        axi_mem_intercon_2/S00_ACLK
        rst_design_1_10M/slowest_sync_clk
    }

    # Try to find the underlying port of the interface port
    set clk_src ""
    catch {set clk_src [get_bd_ports -of_objects [get_bd_intf_ports clk_adc] -quiet]}
    if {$clk_src eq ""} {
        # Try direct name
        catch {set clk_src [get_bd_ports clk_adc -quiet]}
    }
    puts "Underlying port: $clk_src"

    foreach pin $reg_clk_pins {
        set p [get_bd_pins $pin -quiet]
        if {$p eq ""} continue
        set old_net [get_bd_nets -quiet -of $p]
        if {$old_net ne ""} { catch {disconnect_bd_net $old_net $p} }

        if {$clk_src ne ""} {
            if {[catch {connect_bd_net $clk_src $p} e]} {
                puts "  ERR $pin: $e"
            } else {
                puts "  OK $pin"
            }
        } else {
            # Try with interface port directly
            if {[catch {connect_bd_net [get_bd_intf_ports clk_adc] $p} e]} {
                puts "  ERR2 $pin: $e"
            } else {
                puts "  OK2 $pin"
            }
        }
    }
}

# ====== 4. IF STILL DISCONNECTED, TRY CREATING REGULAR PORT INSTEAD ======
set still_disconnected 0
foreach p {adc_ovr_detect_0/clk_main sound_rx_common_0/in_aclk sound_sender_0/ap_clk} {
    set pin [get_bd_pins $p -quiet]
    if {$pin ne ""} {
        set net [get_bd_nets -quiet -of $pin]
        if {$net eq ""} {
            incr still_disconnected
        }
    }
}

if {$still_disconnected > 0} {
    puts "=== Still $still_disconnected pins disconnected, trying regular port ==="

    # Delete interface port
    catch {delete_bd_objs [get_bd_intf_ports clk_adc]}

    # Create regular port
    create_bd_port -dir I clk_adc
    set clk_src [get_bd_ports clk_adc]

    # Connect to all clock pins
    set all_pins {
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

    foreach pin $all_pins {
        set p [get_bd_pins $pin -quiet]
        if {$p eq ""} continue
        set old_net [get_bd_nets -quiet -of $p]
        if {$old_net ne ""} { catch {disconnect_bd_net $old_net $p} }
        if {[catch {connect_bd_net $clk_src $p} e]} {
            puts "  ERR $pin: $e"
        } else {
            puts "  OK $pin"
        }
    }

    # Set FREQ_HZ on regular port (may not work but try)
    catch {set_property CONFIG.FREQ_HZ 122880000 $clk_src}
    puts "FREQ_HZ on regular port: [get_property CONFIG.FREQ_HZ $clk_src -quiet]"
}

# ====== 5. FINAL CHECK ======
puts "=== FINAL CLOCK STATE ==="
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
    rst_design_1_10M/slowest_sync_clk
}
foreach pin $all_clk_pins {
    set p [get_bd_pins $pin -quiet]
    if {$p eq ""} { puts "  $pin NOT FOUND"; continue }
    set net [get_bd_nets -quiet -of $p]
    set net_name "DISCONNECTED"
    if {$net ne ""} { set net_name [get_property NAME $net] }
    set freq [get_property CONFIG.FREQ_HZ $p -quiet]
    puts "  $pin: net=$net_name FREQ_HZ=$freq"
}

# ====== 6. SAVE ======
catch {validate_bd_design} verr
puts "VALIDATE: $verr"
save_bd_design
puts "OK BD_SAVED"
close_bd_design [current_bd_design]
catch {save_project -force}
puts "OK PROJECT_SAVED"

# ====== 7. GENERATE TARGET ======
if {[catch {generate_target all [get_files $bd]} e]} {
    puts "GEN_TARGET_ERR: $e"
} else {
    puts "GEN_TARGET_OK"
}

# ====== 8. SET TOP ======
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v}
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc}
set_property TOP top_trxduo [current_fileset]
update_compile_order -fileset sources_1
puts "OK TOP_SET"

close_project
puts "=== ALL DONE ==="
exit

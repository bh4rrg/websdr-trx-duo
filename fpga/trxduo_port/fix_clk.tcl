open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

# ====== 1. FIX clk_adc PORT FREQUENCY ======
# Current clk_adc has wrong FREQ_HZ (40M inherited from FCLK). Delete and recreate as clock intf port.

# First: disconnect all clock pins from clk_adc
set clk_adc_pins [get_bd_pins -of [get_bd_nets -of [get_bd_ports clk_adc] -quiet]]
set clk_adc_pin_list {}
foreach p $clk_adc_pins {
    lappend clk_adc_pin_list [get_property NAME $p]
}

# Disconnect
set nets [get_bd_nets -of [get_bd_ports clk_adc] -quiet]
foreach n $nets {
    set pins_on_net [get_bd_pins -of $n]
    foreach pin $pins_on_net {
        catch {disconnect_bd_net $n $pin}
    }
}
# Delete old port
delete_bd_objs [get_bd_ports clk_adc]
puts "OK DEL old clk_adc"

# Create new clock interface port with correct frequency
create_bd_intf_port -mode Slave -vlnv xilinx.com:signal:clock_rtl:1.0 clk_adc
set_property CONFIG.FREQ_HZ 122880000 [get_bd_intf_ports clk_adc]
puts "OK NEW clk_adc (intf port, 122.88MHz)"

# Get the actual pin name of the intf port (usually same as port name)
set clk_adc_port [get_bd_intf_ports clk_adc]

# Reconnect all clock pins to new clk_adc
foreach pin_name $clk_adc_pin_list {
    set p [get_bd_pins $pin_name -quiet]
    if {$p ne ""} {
        if {[catch {connect_bd_net [get_bd_intf_ports clk_adc] $p} e]} {
            puts "ERR CONN $pin_name: $e"
        } else { puts "OK CLK $pin_name" }
    }
}

# Also reconnect any missed pins
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
}
foreach pin_name $all_clk_pins {
    set p [get_bd_pins $pin_name -quiet]
    if {$p eq ""} continue
    set net [get_bd_nets -of $p -quiet]
    if {$net eq ""} {
        catch {connect_bd_net [get_bd_intf_ports clk_adc] $p}
        puts "OK RECONNECT $pin_name"
    }
}

# ====== 2. FIX HLS SENDER FREQUENCY ======
# HLS senders expect 40MHz on ap_clk; update to 122.88MHz
foreach sender {sound_sender_0 waterfall_sender_0 waterfall_sender_1} {
    # Try setting the cell's clock frequency
    catch {set_property CONFIG.FREQ_HZ 122880000 [get_bd_cells $sender]}
    # Try setting via the associated clock interface
    catch {set_property CONFIG.FREQ_HZ 122880000 [get_bd_intf_pins ${sender}/ap_clk] -quiet}
    catch {set_property CONFIG.CLK.FREQ_HZ 122880000 [get_bd_cells $sender]}
}

# ====== 3. VALIDATE AND SAVE ======
catch {validate_bd_design} verr
puts "VALIDATE: $verr"

save_bd_design
puts "OK BD_SAVED"
close_bd_design [current_bd_design]

# Generate wrapper
generate_target all [get_files $bd]
puts "OK TARGET_GENERATED"

# Add sources and set top (if not already added)
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v}
catch {add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc}
set_property TOP top_trxduo [current_fileset]
update_compile_order -fileset sources_1
puts "OK TOP_SET"

close_project
puts "=== ALL DONE ==="

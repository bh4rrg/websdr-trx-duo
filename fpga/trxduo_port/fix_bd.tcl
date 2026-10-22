open_project D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.xpr
set bd [get_files D:/websdr-trx-duo/fpga/trxduo_port/OpenZynqSDR_HW/OpenZynqSDR_HW.srcs/sources_1/bd/design_1/design_1.bd]
open_bd_design $bd

# ====== 1. UPGRADE MODULE REFS (refresh cached RTL) ======
puts "=== Upgrading module references ==="
foreach cell {adc_ovr_detect_0 sound_rx_common_0 wf_proc_0 wf_proc_1} {
    if {[catch {upgrade_ip [get_bd_cells $cell]} e]} {
        puts "ERR UPGRADE $cell: $e"
    } else { puts "OK UPGRADE $cell" }
}

# ====== 2. VERIFY PIN WIDTHS ======
puts "=== Pin check ==="
foreach pin {adc_ovr_detect_0/adc_data_in adc_ovr_detect_0/ofl_i
             sound_rx_common_0/adc_data wf_proc_0/adc_data wf_proc_1/adc_data} {
    set p [get_bd_pins $pin -quiet]
    if {$p ne ""} {
        puts "PIN: $pin LEFT=[get_property LEFT $p -quiet] RIGHT=[get_property RIGHT $p -quiet]"
    } else { puts "MISSING: $pin" }
}

# ====== 3. CONNECT ofl_i (now exists after upgrade) ======
set ofl_pin [get_bd_pins adc_ovr_detect_0/ofl_i -quiet]
if {$ofl_pin ne ""} {
    set cur_net [get_bd_nets -of $ofl_pin -quiet]
    if {$cur_net ne ""} { catch {disconnect_bd_net $cur_net $ofl_pin} }
    if {[catch {connect_bd_net [get_bd_ports adc_ofl] $ofl_pin} e]} {
        puts "ERR CONN ofl_i: $e"
    } else { puts "OK CONN ofl_i" }
} else { puts "ERR: ofl_i still missing" }

# ====== 4. VERIFY ADC_IN CONNECTIONS (may need reconnect after upgrade) ======
foreach pin {adc_ovr_detect_0/adc_data_in sound_rx_common_0/adc_data wf_proc_0/adc_data wf_proc_1/adc_data} {
    set p [get_bd_pins $pin -quiet]
    set net [get_bd_nets -of $p -quiet]
    if {$net eq ""} {
        puts "RECONNECT needed: $pin"
        catch {connect_bd_net [get_bd_ports adc_in] $p}
    } else {
        puts "OK: $pin already connected"
    }
}

# ====== 5. VERIFY CLOCK CONNECTIONS ======
foreach pin {adc_ovr_detect_0/clk_main sound_rx_common_0/in_aclk wf_proc_0/in_aclk wf_proc_1/in_aclk
             spi_receiver_0/clk_main sound_sender_0/ap_clk waterfall_sender_0/ap_clk waterfall_sender_1/ap_clk
             rst_design_1_10M/slowest_sync_clk} {
    set p [get_bd_pins $pin -quiet]
    if {$p eq ""} { puts "MISS: $pin"; continue }
    set net [get_bd_nets -of $p -quiet]
    if {$net eq ""} {
        puts "RECONNECT clk_adc: $pin"
        catch {connect_bd_net [get_bd_ports clk_adc] $p}
    } else {
        puts "OK: $pin on net"
    }
}

# ====== 6. SAVE BD ======
catch {validate_bd_design} verr
puts "VALIDATE: $verr"
save_bd_design
puts "OK BD_SAVED"
close_bd_design [current_bd_design]

# ====== 7. GENERATE WRAPPER AND ADD SOURCES ======
# Generate BD products (wrapper, synthesis outputs)
generate_target all [get_files $bd]
puts "OK TARGET_GENERATED"

# Add custom top-level RTL (if not already added)
set top_file [get_files top_trxduo.v -quiet]
if {$top_file eq ""} {
    add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/top_trxduo.v
    puts "OK ADDED top_trxduo.v"
}

# Add constraints (if not already added)
set xdc_file [get_files trxduo.xdc -quiet]
if {$xdc_file eq ""} {
    add_files -norecurse D:/websdr-trx-duo/fpga/trxduo_port/trxduo.xdc
    puts "OK ADDED trxduo.xdc"
}

# Set top module to our custom wrapper
set_property TOP top_trxduo [current_fileset]
update_compile_order -fileset sources_1
puts "OK TOP_SET to top_trxduo"

# Save project (use close_project which auto-saves)
close_project
puts "=== ALL DONE ==="

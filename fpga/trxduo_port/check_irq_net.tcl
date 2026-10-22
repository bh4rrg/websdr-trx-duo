open_checkpoint D:/websdr-trx-duo/fpga/trxduo_port/trxduo_flat/trxduo_flat.runs/synth_1/top_trxduo.dcp

puts "=== xlconcat_0 pins and their nets ==="
set xc [get_cells -hierarchical -filter {NAME =~ *xlconcat_0} -quiet]
foreach p [get_pins -of $xc] {
    set n [get_nets -of $p -quiet]
    if {$n eq ""} { puts "  $p -> NO NET" } else { puts "  $p -> net [get_property NAME $n]" }
}

puts "=== PS7 IRQ_F2P pin net + fanout ==="
set ps [get_cells -hierarchical -filter {NAME =~ *processing_system7_0} -quiet]
foreach p [get_pins -of $ps -filter {NAME =~ IRQ_F2P*}] {
    set n [get_nets -of $p -quiet]
    if {$n eq ""} { puts "  $p -> NO NET"; continue }
    puts "  $p -> net [get_property NAME $n]"
    foreach q [get_pins -of $n] { puts "      pin: $q" }
}

puts "=== waterfall_sender interrupt_out nets ==="
foreach inst [get_cells -hierarchical -filter {NAME =~ *waterfall_sender*} -quiet] {
    foreach p [get_pins -of $inst -filter {NAME =~ *interrupt_out}] {
        set n [get_nets -of $p -quiet]
        if {$n eq ""} { puts "  $p -> NO NET" } else {
            puts "  $p -> net [get_property NAME $n]"
            foreach q [get_pins -of $n] { puts "      pin: $q" }
        }
    }
}
close_project
exit

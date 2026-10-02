# -----------------------------------------------------------------------------
# verify_basys3_xdc.tcl
#
# Phase 8 / basys3_xdc Step 7 verification artifact
#
# PURPOSE
#   Query Vivado's live design/constraint database and verify that the
#   basys3_top_level XDC was actually applied as designed.
#
# PRECONDITION
#   Run this script only after the basys3_top_level design is open in Vivado
#   with vivado/constraints/basys3_top_level.xdc loaded. A synthesized design
#   (for example, open_run synth_1) is an appropriate context.
#
# PASS SCOPE
#   This script verifies constraint application only. It does NOT prove:
#     - BRAM/DSP/LUT/FF utilization
#     - WNS/TNS/WHS/THS timing closure
#     - physical Basys-3 button/LED operation
# -----------------------------------------------------------------------------

set error_count 0
set check_count 0

proc check_equal {label actual expected} {
    upvar error_count error_count
    upvar check_count check_count

    incr check_count

    if {$actual eq $expected} {
        puts "PASS: $label = $actual"
    } else {
        puts "ERROR: $label expected '$expected' but got '$actual'"
        incr error_count
    }
}

proc check_true {label condition} {
    upvar error_count error_count
    upvar check_count check_count

    incr check_count

    if {$condition} {
        puts "PASS: $label"
    } else {
        puts "ERROR: $label"
        incr error_count
    }
}

proc check_near {label actual expected tolerance} {
    upvar error_count error_count
    upvar check_count check_count

    incr check_count

    if {![string is double -strict $actual]} {
        puts "ERROR: $label expected numeric value near $expected but got '$actual'"
        incr error_count
        return
    }

    set difference [expr {abs(double($actual) - double($expected))}]

    if {$difference <= $tolerance} {
        puts "PASS: $label = $actual"
    } else {
        puts "ERROR: $label expected $expected +/- $tolerance but got $actual"
        incr error_count
    }
}

puts "============================================================"
puts "Basys 3 XDC constraint-database verification"
puts "============================================================"

# -----------------------------------------------------------------------------
# Expected physical mapping
# -----------------------------------------------------------------------------
set expected_ports {
    {clk_100mhz     W5  LVCMOS33}
    {btn_start      U18 LVCMOS33}
    {btn_reset      U17 LVCMOS33}
    {led_result[0]  U16 LVCMOS33}
    {led_result[1]  E19 LVCMOS33}
    {led_result[2]  U19 LVCMOS33}
    {led_result[3]  V19 LVCMOS33}
    {led_result[4]  W18 LVCMOS33}
    {led_result[5]  U15 LVCMOS33}
    {led_result[6]  U14 LVCMOS33}
    {led_result[7]  V14 LVCMOS33}
    {led_done       V13 LVCMOS33}
}

check_equal "expected mapping entry count" [llength $expected_ports] 12

# -----------------------------------------------------------------------------
# Port existence, PACKAGE_PIN, IOSTANDARD, and duplicate-pin checks
# -----------------------------------------------------------------------------
array set seen_pin {}

foreach entry $expected_ports {
    lassign $entry port_name expected_pin expected_iostandard

    set port_obj [get_ports -quiet $port_name]
    set port_count [llength $port_obj]

    check_equal "$port_name object count" $port_count 1

    if {$port_count != 1} {
        # Avoid querying properties on an absent/ambiguous object.
        continue
    }

    set actual_pin [get_property PACKAGE_PIN $port_obj]
    set actual_iostandard [get_property IOSTANDARD $port_obj]

    check_equal "$port_name PACKAGE_PIN" $actual_pin $expected_pin
    check_equal "$port_name IOSTANDARD" $actual_iostandard $expected_iostandard

    if {[info exists seen_pin($actual_pin)]} {
        puts "ERROR: duplicate PACKAGE_PIN $actual_pin used by $seen_pin($actual_pin) and $port_name"
        incr error_count
        incr check_count
    } else {
        set seen_pin($actual_pin) $port_name
        puts "PASS: $port_name uses unique PACKAGE_PIN $actual_pin"
        incr check_count
    }
}

check_equal "unique PACKAGE_PIN count" [array size seen_pin] 12

# -----------------------------------------------------------------------------
# Primary clock-object checks
# -----------------------------------------------------------------------------
set clk_port [get_ports -quiet clk_100mhz]
set clk_objs {}

if {[llength $clk_port] == 1} {
    set clk_objs [get_clocks -quiet -of_objects $clk_port]
}

check_equal "clock objects on clk_100mhz" [llength $clk_objs] 1

if {[llength $clk_objs] == 1} {
    set clk_obj [lindex $clk_objs 0]

    check_equal "primary clock name" [get_property NAME $clk_obj] "sys_clk_pin"
    check_near "primary clock period (ns)" [get_property PERIOD $clk_obj] 10.000 0.001

    set waveform [get_property WAVEFORM $clk_obj]
    check_equal "clock waveform edge count" [llength $waveform] 2

    if {[llength $waveform] == 2} {
        check_near "clock rising edge (ns)" [lindex $waveform 0] 0.000 0.001
        check_near "clock falling edge (ns)" [lindex $waveform 1] 5.000 0.001
    }
}

# This design intentionally has only one clock object.
check_equal "total design clock count" [llength [get_clocks -quiet *]] 1

# -----------------------------------------------------------------------------
# Device configuration-property checks
# -----------------------------------------------------------------------------
set design_obj [current_design]

check_near "CONFIG_VOLTAGE" [get_property CONFIG_VOLTAGE $design_obj] 3.3 0.001
check_equal "CFGBVS" [get_property CFGBVS $design_obj] "VCCO"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
puts "============================================================"
puts "Checks executed: $check_count"
puts "Errors found:    $error_count"

if {$error_count == 0} {
    puts "PASS: basys3_xdc constraint database matches the approved design."
    puts "NOTE: This is not synthesis-resource, routed-timing, or hardware sign-off."
} else {
    puts "FAIL: basys3_xdc constraint verification found $error_count error(s)."
    error "basys3_xdc verification failed"
}

puts "============================================================"

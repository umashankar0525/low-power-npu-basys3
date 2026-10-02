## -----------------------------------------------------------------------------
## Basys 3 top-level constraints
## Module: basys3_top_level
## Target: XC7A35T-1CPG236C
## Board: Basys 3
##
## Source for package-pin / IOSTANDARD mappings:
## Digilent Basys-3-Master.xdc
##
## Approved project mapping:
##   clk_100mhz    -> 100 MHz oscillator
##   btn_start     -> btnC
##   btn_reset     -> btnD
##   led_result[0] -> LED0
##   ...
##   led_result[7] -> LED7
##   led_done      -> LED8
##
## All selected board I/O use LVCMOS33.
## -----------------------------------------------------------------------------

## -----------------------------------------------------------------------------
## 100 MHz system clock
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk_100mhz]

## 100 MHz = 10 ns period, 50% duty cycle.
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk_100mhz]


## -----------------------------------------------------------------------------
## Pushbuttons
## -----------------------------------------------------------------------------

## Center button (btnC) -> start
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btn_start]

## Down button (btnD) -> reset
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports btn_reset]


## -----------------------------------------------------------------------------
## Result LEDs: led_result[n] -> board LEDn
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led_result[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led_result[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led_result[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led_result[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led_result[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led_result[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led_result[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led_result[7]}]


## -----------------------------------------------------------------------------
## Persistent completion indicator
## -----------------------------------------------------------------------------

## Board LED8 -> done
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports led_done]


## -----------------------------------------------------------------------------
## Basys 3 configuration properties
## -----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

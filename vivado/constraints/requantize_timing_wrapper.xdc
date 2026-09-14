# Requantization timing-wrapper clock constraint
# Target clock: 100 MHz
# Derived period: T = 1 / 100 MHz = 10 ns
# Timing path under measurement:
# accumulator_reg -> requantize_relu -> output_activation register
#
# IMPORTANT:
# Use this constraint for the requantize_timing_wrapper measurement run.
# Do not enable another XDC that also creates a clock on the same clk port.

create_clock -name clk_100MHz -period 10.000 [get_ports clk]

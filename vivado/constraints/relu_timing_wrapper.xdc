# ReLU timing-wrapper clock constraint
# Target clock: 100 MHz
# Derived period: T = 1 / 100 MHz = 10 ns
# This constraint is for static timing analysis of:
# accumulator_reg -> relu_activation -> output_activation

create_clock -name clk_100MHz -period 10.000 [get_ports clk]

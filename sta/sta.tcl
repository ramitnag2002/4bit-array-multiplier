
# Part C: Static Timing Analysis

# SKY130 typical-corner Liberty library
set lib "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# Read the Liberty timing library
read_liberty $lib

# Read the synthesized netlist
read_verilog synth/mult_array_netlist.v

# Link the design
link_design mult_array

# Define a 10 ns clock
create_clock -name clk -period 2.61 [get_ports clk]

# Set input delay
set_input_delay 1.0 -clock clk \
    [delete_from_list [all_inputs] [get_ports clk]]

# Set output delay
set_output_delay 1.0 -clock clk [all_outputs]

# Report worst setup slack
report_worst_slack -max

# Save the critical path timing report
report_checks -path_delay max -digits 3 \
    > sta/mult_array_timing.rpt

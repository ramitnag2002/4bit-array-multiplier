
# SKY130 Liberty library
set lib "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# Read Verilog files
yosys read_verilog rtl/full_adder.v rtl/mult_array.v

# Generic synthesis
yosys synth -top mult_array -flatten

# Flip-flop mapping
yosys dfflibmap -liberty $lib

# Logic gate mapping
yosys abc -liberty $lib

# Remove unused logic
yosys opt_clean -purge

# Generate statistics report
yosys tee -o synth/mult_array_stat.rpt stat -liberty $lib

# Generate synthesized netlist
yosys write_verilog -noattr synth/mult_array_netlist.v

# 4-bit Array Multiplier: RTL to GDSII (SKY130, open-source flow)

- **Name:** Ramit Nag and Kanuthala harshith
- **Roll number:** 2026203011 and 2026203018
- **Design:** 4-bit x 4-bit unsigned array multiplier, 8-bit registered product, latency 2 clock cycles
- **Technology:** SkyWater SKY130, cell library `sky130_fd_sc_hd`
- **Environment:** IIC-OSIC-TOOLS Docker image (Docker Desktop on Windows)
- **Repository:** https://github.com/Harshith21k/mult4_2026203018

All commands are given in the order they were used. Section 0 runs on the Windows host
(PowerShell). Everything from Section 1 onward runs in a terminal inside the container.
`/foss/designs` inside the container is the same folder as `eda/designs` on the host.

## Repository layout

```
mult4_2026203018/
|-- README.md
|-- rtl/    full_adder.v  mult_array.v
|-- tb/     tb_mult.v
|-- synth/  synth.tcl  mult_array_netlist.v  mult_array_stat.rpt
|-- sta/    sta.tcl    mult_array_timing.rpt
|-- pnr/    config.json  metrics.json  mult_array.gds
`-- report/ report.pdf
```

---

## 0. Start the container (Windows host, PowerShell)

```powershell
docker ps                                  # list running containers; note the name (iic-osic-tools)
docker exec -it iic-osic-tools bash        # open a shell inside it (container name or ID from docker ps)
```


## 1. Environment setup (inside the container)

```bash
cd /foss/designs/mult4_2026203018

# check the tools
iverilog -V | head -1
yosys -V
sta -version

# the container defaulted to the ihp-sg13g2 PDK; switch to SKY130
sak-pdk sky130A
echo $PDK_ROOT $PDK                        # expect: sky130A
ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# create the folder structure
mkdir -p rtl tb synth sta pnr report
```

`sak-pdk sky130A` only affects the current terminal, so it is repeated in every new
terminal before using Yosys, OpenSTA or LibreLane.

## 2. Part A: RTL design and verification

Files written by hand (with `nano`): `rtl/full_adder.v`, `rtl/mult_array.v`,
`tb/tb_mult.v`.

Testbench timing: `rst_n` is held low for the first 2 clock cycles. For each of the 256
input pairs the inputs are applied on a falling clock edge, two rising edges follow
(edge 1 captures `a` and `b`, edge 2 captures the product: latency = 2 cycles), and `p`
is compared with `a * b` on the next falling edge.

```bash
# compile and simulate (writes mult.vcd)
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
# result: PASS: 256 vectors checked, 0 errors
```

Waveform: GTKWave could not open a display inside the container (`Could not initialize
GTK`), so `mult.vcd` was opened with the Surfer waveform viewer on the host. Signals
shown: `clk`, `rst_n`, `a`, `b`, `p`. For the example A = 13 (last roll digit 8 + 5),
B = 7, the product 0x5B (91) appears two rising clock edges after `b` becomes 7.

Error test (temporarily break the adder, confirm the testbench reports FAIL, restore):

```bash
cp rtl/full_adder.v rtl/full_adder.v.bak
nano rtl/full_adder.v                       # change sum to: assign sum = a ^ b;
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | tail -n 5                         # result: FAIL: 256 vectors checked, <N> errors
mv rtl/full_adder.v.bak rtl/full_adder.v    # restore the original
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | tail -n 1                         # PASS again
```

## 3. Git setup and first push

`.gitignore` keeps generated files, screenshots and the large `runs/` folder out of the
repository:

```bash
cat > .gitignore << 'EOF'
sim
gls
*.vcd
*.bak
fail_line.txt
pnr/runs/
pnr/*.png
report/*.png
EOF

git init -b main
git config user.name Harshith21k
git config user.email harshith.kanuthala@gmail.com
git add .
git commit -m "Part A: RTL and testbench"
git remote add origin https://github.com/Harshith21k/mult4_2026203018.git
git push -u origin main
```

Pushing needs a GitHub personal access token (classic, `repo` scope) as the password;
account passwords are rejected.

## 4. Part B: logic synthesis with Yosys

```bash
cat > synth/synth.tcl << 'EOF'
set lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

yosys read_verilog rtl/full_adder.v rtl/mult_array.v
yosys synth -top mult_array -flatten
yosys dfflibmap -liberty $lib
yosys abc -liberty $lib
yosys opt_clean -purge
yosys tee -o synth/mult_array_stat.rpt stat -liberty $lib
yosys write_verilog -noattr synth/mult_array_netlist.v
EOF

yosys -c synth/synth.tcl
cat synth/mult_array_stat.rpt
```

Gate-level (netlist) simulation, using the command from the assignment:

```bash
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls | tail -n 3
# result: PASS: 256 vectors checked, 0 errors
```

Note on the testbench: an earlier version of `tb/tb_mult.v` read `p` only 1 ns after the
capturing clock edge. That passed in RTL simulation but failed in the gate-level
simulation with `-DUNIT_DELAY=#1` (239 errors: `p` still showed the previous product,
because the cell models have delays). The testbench was changed to apply inputs and
sample `p` on falling clock edges and to keep the expected value in an 8-bit variable.
RTL and gate-level simulation then both passed with the unchanged command above, and the
RTL, netlist, STA and place-and-route results did not change. Part A was rerun with the
final testbench.

```bash
git add tb/tb_mult.v synth/
git commit -m "Part B: synthesis script, netlist, stat report; testbench samples on falling edge"
git push
```

## 5. Part C: static timing analysis with OpenSTA

`sta/sta.tcl` takes the clock period from the environment variable `T` (default 10 ns):

```bash
cat > sta/sta.tcl << 'EOF'
set lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# clock period in ns: taken from the environment, default 10
if {[info exists ::env(T)]} { set T $::env(T) } else { set T 10 }

read_liberty $lib
read_verilog synth/mult_array_netlist.v
link_design mult_array

create_clock -name clk -period $T [get_ports clk]
set_input_delay 1.0 -clock clk [delete_from_list [all_inputs] [get_ports clk]]
set_output_delay 1.0 -clock clk [all_outputs]

report_worst_slack -max
report_checks -path_delay max -digits 3 > sta/mult_array_timing.rpt
exit
EOF

# T = 10 ns
sta sta/sta.tcl                    # worst slack max 7.43  ->  T_min = 10 - 7.43 = 2.57 ns
                                   #                       ->  F_max = 1000/2.57 = 389.1 MHz

# T = T_min (this run's report is the one kept in the repository)
T=2.57 sta sta/sta.tcl             # worst slack max 0.00
grep -i slack sta/mult_array_timing.rpt          # 0.004 ns (critical path), 1.798 ns (reset recovery)
cat sta/mult_array_timing.rpt

# identify the start and end flip-flops in the netlist
grep -A6 "dfrtp_1 _102_" synth/mult_array_netlist.v     # b_reg[0]
grep -A6 "dfrtp_1 _096_" synth/mult_array_netlist.v     # p[6]
```

```bash
git add sta/
git commit -m "Part C: OpenSTA script and timing report at T_min = 2.57 ns"
git push
```

## 6. Part D: physical design with LibreLane

`CLOCK_PERIOD` start value: 1.2 x 2.57 = 3.084 -> rounded up to the next 0.5 ns = 3.5 ns.

```bash
sak-pdk sky130A                    # only if this is a new terminal
echo $PDK_ROOT $PDK
librelane --version

cat > pnr/config.json << 'EOF'
{
  "DESIGN_NAME": "mult_array",
  "VERILOG_FILES": ["dir::../rtl/full_adder.v", "dir::../rtl/mult_array.v"],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 3.5,
  "FP_SIZING": "absolute",
  "DIE_AREA": [0, 0, 150, 150]
}
EOF

cd pnr
librelane config.json                                  # run 1 (3.5 ns)
```

LibreLane also checks setup timing at the slow and fast corners, so the early runs
stopped with "Setup violations found" at the `ss_100C_1v60` corner. For each failed run
the worst slack was read, the period was changed and the flow rerun:

```bash
grep -E 'setup__ws' runs/<RUN_FOLDER>/final/metrics.json

sed -i 's/"CLOCK_PERIOD":[ ]*[0-9.]*/"CLOCK_PERIOD": 6.0/' config.json
grep CLOCK_PERIOD config.json
librelane config.json                                  # run 2 (6.0 ns)
# ... run 3 ...                                        # <FILL IN: period and result>
sed -i 's/"CLOCK_PERIOD":[ ]*[0-9.]*/"CLOCK_PERIOD": 7.0/' config.json
librelane config.json                                  # run 4 (7.0 ns): Flow complete
```

### Run log

| Run | CLOCK_PERIOD | Worst setup slack | Result |
|-----|--------------|-------------------|--------|
| 1 | 3.5 ns | -2.133 ns (ss_100C_1v60) | failed (setup) |
| 2 | 6.0 ns | -0.119 ns (ss_100C_1v60) | failed (setup) |
| 3 | 6.5 ns | -0.119 ns (ss_100C_1v60) | failed (setup) |
| 4 | 7.0 ns | +0.427 ns (ss_100C_1v60) | passed: DRC 0, LVS 0, antenna passed |

Collect the results of the final run and copy the deliverables:

```bash
RUN=$(ls -d runs/*/ | tail -n 1)
echo $RUN                                              # runs/RUN_2026-10-21_21-18-47/
ls $RUN/final/ $RUN/final/gds
cp $RUN/final/metrics.json .
cp $RUN/final/gds/mult_array.gds .

ls -d runs/*/ | wc -l                                  # number of runs
grep -E 'instance__count|core__area|die__area|wirelength|timing__setup__ws"|setup__ws__corner:(nom|max)_(tt|ss)|drc|lvs' metrics.json
```

Layout screenshots (made with KLayout in batch mode from `mult_array.gds`; the images
are used in the report and are not committed):

```bash
cat > shot.py << 'EOF'
import pya, os
lv = pya.LayoutView()
lv.load_layout("mult_array.gds", True)
lyp = os.environ.get("PDK_ROOT", "") + "/sky130A/libs.tech/klayout/tech/sky130A.lyp"
if os.path.exists(lyp):
    lv.load_layer_props(lyp)
lv.max_hier()
lv.zoom_fit()
lv.save_image("die_full.png", 1600, 1600)
lv.zoom_box(pya.DBox(55, 55, 95, 95))
lv.save_image("die_zoom.png", 1600, 1600)
print("done")
EOF
klayout -b -r shot.py
```

Commit only the required files:

```bash
cd ..
git add .gitignore pnr/config.json pnr/metrics.json pnr/mult_array.gds
git status
git commit -m "Part D: LibreLane config, metrics and GDS (7.0 ns, DRC/LVS clean)"
git push
```

## 7. Report and README

The report (`report/report.pdf`) is built from LaTeX (pdflatex, run twice) and placed in
the `report/` folder, then committed together with this README:

```bash
mkdir -p report
# report.pdf copied into /foss/designs/mult4_2026203018/report/ (shared folder)
ls report/
git add README.md report/report.pdf
git status
git commit -m "Add README and report"
git push
git ls-files
```

---

## Results summary

| Part | Result |
|------|--------|
| A | PASS: 256 vectors checked, 0 errors; error test (`sum = a ^ b`): FAIL |
| B | 65 cells, 16 flip-flops, area 746.966 um^2, flip-flops 400.384 um^2 (53.60%); netlist simulation PASS |
| C | T_min = 2.57 ns, F_max = 389.1 MHz, slack at T_min = 0.004 ns; critical path b_reg[0] -> p[6], 8 logic cells |
| D | CLOCK_PERIOD 7.0 ns, 4 runs, core area 17759.5 um^2, 1885 cells after P&R, wirelength 2314 um, slack +0.427 ns, post-route F_max 152.1 MHz (slow corner) / 312.4 MHz (typical corner), DRC 0, LVS 0 |

## AI-tool disclosure

An AI assistant (Claude) was used for guidance on the tool
flow, debugging and drafting the report. All code in this repository was written and checked by us.

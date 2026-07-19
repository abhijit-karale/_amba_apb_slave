#!/bin/bash
set -e
iverilog -g2012 -o sim.out rtl/apb_slave.sv tb/tb_apb_slave.sv
vvp sim.out
python3 vcd_plot.py waveform/apb_slave.vcd waveform/apb_slave_waveform.png \
    pclk presetn psel penable pwrite paddr pwdata prdata pready pslverr --window 0 250
echo "Done. Open waveform/apb_slave.vcd in GTKWave for full interactive waveform."

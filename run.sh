verilator --binary -j 0 axi_lite.v
verilator --binary -j 0 -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-INITIALDLY --trace --timescale 1ns/1ps --top-module axi_lite_tb *.v
./obj_dir/Vaxi_lite_tb
SAVE_FILE = axi_lite
DUMP_FILE = dump

compile:
	verilator --binary -j 0 --sv --assert \
		-Wno-INITIALDLY -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL \
		--trace --timescale 1ns/1ps --top-module axi_lite_tb *.v

run:
	./obj_dir/Vaxi_lite_tb

all: compile run

wave:
	unset LD_LIBRARY_PATH; \
	if [ -f $(SAVE_FILE).gtkw ]; then \
		gtkwave $(DUMP_FILE).vcd $(SAVE_FILE).gtkw; \
	else \
		gtkwave $(DUMP_FILE).vcd; \
	fi

clean:
	rm -rf obj_dir $(DUMP_FILE).vcd
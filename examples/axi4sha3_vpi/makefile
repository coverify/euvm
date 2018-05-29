DFLAGS = -version=COSIM_VERILOG -fPIC -w -O  # -version=UVM_NO_DEPRECATED  -version=UVM_NO_WAIT_FOR_NBA

all: axi.vvp axi.vpi

clean:
	rm -f axi.vvp axi.vpi axi.o tr_db.log

run: axi.vvp axi.vpi
	vvp -M. -maxi axi.vvp +UVM_TESTNAME=axi4_lite.random_test
#	vvp -M. -maxi axi.vvp +UVM_TESTNAME=axi4_lite.directed_test


axi.vvp: axi_tb.v axi4_sha3_1.0/hdl/* axi4_sha3_1.0/src/*
	iverilog -o $@ $^

axi.vpi: axi4_lite.d c-model/libsha3.a
	ldmd2 $(DFLAGS) -shared -of$@ -L-ldl -L-lesdl-ldc -L-luvm-ldc -L-lphobos2-ldc $^

MODEL = 64
DFLAGS = -m$(MODEL) -fPIC -w -O # -version=UVM_NO_DEPRECATED
ESDLDIR = ${HOME}/code/vlang
VLANGDIR = ${HOME}/code/vlang-uvm
DEBUGCONF = ldc2-debug.conf

DMD = ldmd2
PHOBOS = phobos2-ldc

LIBDIR = $(VLANGDIR)/lib

all: libs

libs: libesdl-ldc.so libuvm-ldc.so libesdl-ldc-debug.so libuvm-ldc-debug.so \
      libesdl-ldc.so libuvm-ldc.a libesdl-ldc-debug.a libuvm-ldc-debug.a

clean:
	rm -f lib*.o lib*.so lib*.so.* lib*.a

libesdl-ldc.so: $(ESDLDIR)/src/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/vcd/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d
	$(DMD) -shared $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

libesdl-ldc.a: $(ESDLDIR)/src/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/vcd/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d
	$(DMD) -static -c -lib $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

libuvm-ldc.so: $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/dpi/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/tlm2/*.d $(VLANGDIR)/src/uvm/reg/*.d $(VLANGDIR)/src/uvm/vpi/*.d
	$(DMD) -shared $(DFLAGS) -of$@ -L-R. -L-L. -I$(VLANGDIR)/src -I$(ESDLDIR)/src $^

libuvm-ldc.a: $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/dpi/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/tlm2/*.d $(VLANGDIR)/src/uvm/reg/*.d $(VLANGDIR)/src/uvm/vpi/*.d
	$(DMD) -static -c -lib $(DFLAGS) -of$@ -L-R. -L-L. -I$(VLANGDIR)/src -I$(ESDLDIR)/src $^

libesdl-ldc-debug.so: $(ESDLDIR)/src/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/vcd/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d
	$(DMD) -gs -conf=$(DEBUGCONF) -shared $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

libesdl-ldc-debug.a: $(ESDLDIR)/src/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/vcd/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d
	$(DMD) -gs -conf=$(DEBUGCONF) -static -c -lib $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

libuvm-ldc-debug.so: $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/dpi/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/tlm2/*.d $(VLANGDIR)/src/uvm/reg/*.d $(VLANGDIR)/src/uvm/vpi/*.d
	$(DMD) -gs -conf=$(DEBUGCONF) -shared $(DFLAGS) -of$@ -L-R. -L-L. -I$(VLANGDIR)/src -I$(ESDLDIR)/src $^

libuvm-ldc-debug.a: $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/dpi/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/tlm2/*.d $(VLANGDIR)/src/uvm/reg/*.d $(VLANGDIR)/src/uvm/vpi/*.d
	$(DMD) -gs -conf=$(DEBUGCONF) -static -c -lib $(DFLAGS) -of$@ -L-R. -L-L. -I$(VLANGDIR)/src -I$(ESDLDIR)/src $^

MODEL = 64
DFLAGS = -m$(MODEL) -fPIC -w -O # -version=UVM_NO_DEPRECATED
ESDLDIR = ${HOME}/code/vlang
VLANGDIR = ${HOME}/code/vlang-uvm

DMDDIR = ${HOME}/local/ldc
DMD = $(DMDDIR)/bin/ldmd2

DMDLIBDIR = $(DMDDIR)/lib
PHOBOS = phobos2-ldc

LIBDIR = $(VLANGDIR)/lib

all: libs

libs: libesdl-ldc.so libuvm-ldc.so libesdl-ldc-debug.so libuvm-ldc-debug.so

clean:
	rm -f lib*.o lib*.so

libesdl-ldc.so: $(ESDLDIR)/src/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/vcd/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d
	$(DMD) -shared $(DFLAGS) -oflibesdl-ldc.so -L-l$(PHOBOS) -L-L$(DMDLIBDIR) -L-R$(DMDLIBDIR) -I$(ESDLDIR)/src $^

libuvm-ldc.so: $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/dpi/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/tlm2/*.d $(VLANGDIR)/src/uvm/reg/*.d 
	$(DMD) -shared $(DFLAGS) -oflibuvm-ldc.so -L-lesdl-ldc -L-l$(PHOBOS) -L-L$(DMDLIBDIR) -L-R$(DMDLIBDIR) -L-R. -L-L. -I$(VLANGDIR)/src -I$(ESDLDIR)/src $^

libesdl-ldc-debug.so: $(ESDLDIR)/src/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/vcd/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d
	$(DMD) -g -shared $(DFLAGS) -oflibesdl-ldc-debug.so -L-l$(PHOBOS) -L-L$(DMDLIBDIR) -L-R$(DMDLIBDIR) -I$(ESDLDIR)/src $^

libuvm-ldc-debug.so: $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/dpi/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/tlm2/*.d $(VLANGDIR)/src/uvm/reg/*.d 
	$(DMD) -g -shared $(DFLAGS) -oflibuvm-ldc-debug.so -L-lesdl-ldc-debug -L-l$(PHOBOS) -L-L$(DMDLIBDIR) -L-R$(DMDLIBDIR) -L-R. -L-L. -I$(VLANGDIR)/src -I$(ESDLDIR)/src $^

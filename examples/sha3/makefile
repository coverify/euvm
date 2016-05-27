#----------------------------------------------------------------------
#   Copyright 2014 Coverify Systems Technology
#   All Rights Reserved Worldwide
#
#   Licensed under the Apache License, Version 2.0 (the
#   "License"); you may not use this file except in
#   compliance with the License.  You may obtain a copy of
#   the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in
#   writing, software distributed under the License is
#   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied.  See
#   the License for the specific language governing
#   permissions and limitations under the License.
#----------------------------------------------------------------------

MODEL = 64
DFLAGS = -fPIC -g -w -O # -debug=LOGPROCS # -debug=SCHEDULER # -debug=LOGPROCS -release  # -debug=SEED
MRAALIB = mraa
MRAALIBDIR = /usr/local/lib/i386-linux-gnu
ESDLDIR = /home/puneet/code/vlang
VLANGDIR = /home/puneet/code/vlang-uvm
DMD = /home/puneet/local/dmd$(MODEL)/bin/dmd
LIBDIR = /home/puneet/local/dmd$(MODEL)/lib
PHOBOS = phobos2
ICARUSDIR = /home/puneet/local/icarus$(MODEL)

ICARUSLIBPATH = $(ICARUSDIR)/lib
ICARUSINCPATH = $(ICARUSDIR)/include/iverilog

VERILOG = $(ICARUSDIR)/bin/iverilog
VVP = $(ICARUSDIR)/bin/vvp

ESDLSOURCES := $(shell find $(ESDLDIR)/src -name '*.d')
VLANGSOURCES := $(shell find $(VLANGDIR)/src -name '*.d')

DMDDIR = /home/puneet/local/dmd$(MODEL)
DMD = $(DMDDIR)/bin/dmd

LIBDIR = $(DMDDIR)/lib
PHOBOS = phobos2


all: cvcsim sha.vvp vpi.o sha.vpi

run_icarus: sha.vvp sha.vpi
	$(VVP) -M. -msha sha.vvp +UVM_TESTNAME=sha.RandomTest

run_quick_fox: sha.vvp sha.vpi
	$(VVP) -M. -msha sha.vvp +UVM_TESTNAME=sha.QuickFoxTest


run: cvcsim
	./cvcsim

.PHONY: all sha vpi run

vpi.o: vpi.c
	gcc -m$(MODEL) -c -I $(ICARUSINCPATH) -fPIC -Wall vpi.c -o vpi.o

vpi.so: vpi.o libsha.so
	gcc -m$(MODEL) -L. -Wl,-rpath=. -shared -o vpi.so vpi.o -lsha

vpi: vpi.so

clean:
	rm -fr libsha.so sha.o vpi.o vpi.so cvcsim sha.vvp vpi.o sha.vpi

sha.o: sha.d
	$(DMD) -m$(MODEL) $(DFLAGS) -c -fPIC  -I$(ESDLDIR)/src -I$(VLANGDIR)/src $^

cvcsim: vpi.so libsha.so sha_top.v sha_mem.v
	$(CVC) -q +loadvpi=./vpi.so:vpi_compat_bootstrap -sv -sv_lib ./libsha.so sha_top.v sha_mem.v

libesdl.so: $(ESDLSOURCES)
	$(DMD) -shared -fPIC -oflibesdl.so -L-l$(PHOBOS) -L-L$(LIBDIR) -L-R$(LIBDIR) -I$(ESDLDIR)/src $(ESDLSOURCES)

libvlang.so: $(VLANGSOURCES)
	$(DMD) -shared -fPIC -oflibvlang.so -L-lesdl -L-l$(PHOBOS) -L-L$(LIBDIR) -L-R$(LIBDIR) -L-R. -L-L. -I$(VLANGDIR)/src -I$(ESDLDIR)/src $(VLANGSOURCES)

libsha.so: sha.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/*.d $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/dpi/uvm_svcmd_dpi.d $(VLANGDIR)/src/uvm/dap/*.d
	$(DMD) -m$(MODEL) -I$(ESDLDIR)/src -I$(VLANGDIR)/src $(DFLAGS) -shared -of$@ -L-ldl -L-l$(PHOBOS) -L-R$(LIBDIR) $^

sha.vvp: verilog/keccak_avst.v verilog/keccak.v verilog/f_permutation.v \
	verilog/padder.v verilog/rconst.v verilog/round.v \
	verilog/test_keccak_avst.v
	$(VERILOG) -o $@ $^

sha.vpi: sha.d vpi.o libesdl.so libvlang.so c-model/$(MODEL)-bit/libsha3.a
	$(DMD) -m$(MODEL) -g -I$(VLANGDIR)/src -I$(ESDLDIR)/src $(DFLAGS) -shared -fPIC -of$@ -L-ldl -L-l$(PHOBOS) -L-R$(LIBDIR) -L-lesdl -L-lvlang -L-L. -L-R. $^

sha: sha.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d  $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/dpi/uvm_svcmd_dpi.d $(VLANGDIR)/src/uvm/dap/*.d
	$(DMD) -version=EDISON -m$(MODEL) -I$(ESDLDIR)/src -I$(VLANGDIR)/src $(DFLAGS) -of$@ -L-ldl -L-l$(MRAALIB) -L-l$(PHOBOS) -L-R$(MRAALIBDIR) -L-L$(MRAALIBDIR) -L-R$(LIBDIR) -L-lsha3 -L-Lc-model/$(MODEL)-bit $^

sha32: sha.d $(ESDLDIR)/src/esdl/sync/*.d $(ESDLDIR)/src/esdl/sys/*.d $(ESDLDIR)/src/esdl/intf/*.d $(ESDLDIR)/src/esdl/base/*.d $(ESDLDIR)/src/esdl/data/*.d $(ESDLDIR)/src/esdl/*.d $(ESDLDIR)/src/esdl/posix/sys/net/*.d  $(VLANGDIR)/src/uvm/*.d $(VLANGDIR)/src/uvm/meta/*.d $(VLANGDIR)/src/uvm/base/*.d $(VLANGDIR)/src/uvm/comps/*.d $(VLANGDIR)/src/uvm/dap/*.d $(VLANGDIR)/src/uvm/tlm1/*.d $(VLANGDIR)/src/uvm/seq/*.d $(VLANGDIR)/src/uvm/dpi/uvm_svcmd_dpi.d $(VLANGDIR)/src/uvm/dap/*.d
	$(DMD) -version=NODESIGN -m$(MODEL) -I$(ESDLDIR)/src -I$(VLANGDIR)/src $(DFLAGS) -of$@ -L-ldl -L-l$(MRAALIB) -L-l$(PHOBOS) -L-R$(MRAALIBDIR) -L-L$(MRAALIBDIR) -L-R$(LIBDIR) -L-lsha3 -L-Lc-model/$(MODEL)-bit -L-Rc-model/$(MODEL)-bit $^

sha_norand: sha_norand.d $(ESDLDIR)/src/esdl/sync/*.d \
	$(ESDLDIR)/src/esdl/sys/*.d \
	$(ESDLDIR)/src/esdl/intf/*.d \
	$(ESDLDIR)/src/esdl/base/*.d \
	$(ESDLDIR)/src/esdl/data/bstr.d \
	$(ESDLDIR)/src/esdl/data/bvec.d \
	$(ESDLDIR)/src/esdl/data/package.d \
	$(ESDLDIR)/src/esdl/data/packed.d \
	$(ESDLDIR)/src/esdl/data/packer.d \
	$(ESDLDIR)/src/esdl/data/queue.d \
	$(ESDLDIR)/src/esdl/data/sync.d \
	$(ESDLDIR)/src/esdl/data/time.d \
	$(ESDLDIR)/src/esdl/*.d \
	$(ESDLDIR)/src/esdl/posix/sys/net/*.d  \
	$(VLANGDIR)/src/uvm/*.d \
	$(VLANGDIR)/src/uvm/meta/*.d \
	$(VLANGDIR)/src/uvm/base/*.d \
	$(VLANGDIR)/src/uvm/comps/*.d \
	$(VLANGDIR)/src/uvm/dap/*.d \
	$(VLANGDIR)/src/uvm/tlm1/*.d \
	$(VLANGDIR)/src/uvm/seq/*.d \
	$(VLANGDIR)/src/uvm/dpi/uvm_svcmd_dpi.d \
	$(VLANGDIR)/src/uvm/dap/*.d
	$(DMD) -version=UVM_NORANDOM -version=ESDL_NORAND -m$(MODEL) -I$(ESDLDIR)/src -I$(VLANGDIR)/src $(DFLAGS) -of$@ -L-ldl -L-l$(PHOBOS) -L-R$(LIBDIR) $^


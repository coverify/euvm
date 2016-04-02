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

MODEL = 32
DFLAGS = -version=UVM_NO_DEPRECATED -fPIC -g -w -O # -release  # -debug=SEED
MRAALIB = mraa
MRAALIBDIR = /usr/local/lib/i386-linux-gnu
VLANGDIR = /home/puneet/code/vlang
UVMDIR = /home/puneet/code/vlang-uvm
DMD = /home/puneet/local/dmd$(MODEL)/bin/dmd
LIBDIR = /home/puneet/local/dmd$(MODEL)/lib
PHOBOS = phobos2
ICARUSLIBPATH = /home/puneet/local/icarus$(MODEL)/lib
ICARUSINCPATH = /home/puneet/local/icarus$(MODEL)/include/iverilog
VERILOG = /home/puneet/local/icarus$(MODEL)/bin/iverilog
VVP = /home/puneet/local/icarus$(MODEL)/bin/vvp

all: cvcsim sha.vvp vpi.o sha.vpi

run_icarus: sha.vvp vpi.o sha.vpi
	$(VVP) -M. -msha sha.vvp +UVM_TESTNAME=sha.RandomTest

run_quick_fox: sha.vvp vpi.o sha.vpi
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
	$(DMD) -m$(MODEL) $(DFLAGS) -c -fPIC  -I$(VLANGDIR)/src -I$(UVMDIR)/src $^

cvcsim: vpi.so libsha.so sha_top.v sha_mem.v
	$(CVC) -q +loadvpi=./vpi.so:vpi_compat_bootstrap -sv -sv_lib ./libsha.so sha_top.v sha_mem.v

libsha.so: sha.d $(VLANGDIR)/src/esdl/posix/sys/net/*.d $(VLANGDIR)/src/esdl/sync/*.d $(VLANGDIR)/src/esdl/sys/*.d $(VLANGDIR)/src/esdl/intf/*.d $(VLANGDIR)/src/esdl/base/*.d $(VLANGDIR)/src/esdl/data/*.d $(VLANGDIR)/src/esdl/*.d $(UVMDIR)/src/uvm/*.d $(UVMDIR)/src/uvm/meta/*.d $(UVMDIR)/src/uvm/base/*.d $(UVMDIR)/src/uvm/comps/*.d $(UVMDIR)/src/uvm/tlm1/*.d $(UVMDIR)/src/uvm/seq/*.d $(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d $(UVMDIR)/src/uvm/dap/*.d
	$(DMD) -m$(MODEL) -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -shared -of$@ -L-ldl -L-l$(PHOBOS) -L-R$(LIBDIR) $^

sha.vvp: verilog/keccak_avst.v verilog/keccak.v verilog/f_permutation.v \
	verilog/padder.v verilog/rconst.v verilog/round.v \
	verilog/test_keccak_avst.v
	$(VERILOG) -o $@ $^

sha.vpi: sha.d vpi.o $(VLANGDIR)/src/esdl/sync/*.d $(VLANGDIR)/src/esdl/sys/*.d $(VLANGDIR)/src/esdl/intf/*.d $(VLANGDIR)/src/esdl/base/*.d $(VLANGDIR)/src/esdl/data/*.d $(VLANGDIR)/src/esdl/*.d $(VLANGDIR)/src/esdl/posix/sys/net/*.d  $(UVMDIR)/src/uvm/*.d $(UVMDIR)/src/uvm/meta/*.d $(UVMDIR)/src/uvm/base/*.d $(UVMDIR)/src/uvm/comps/*.d $(UVMDIR)/src/uvm/dap/*.d $(UVMDIR)/src/uvm/tlm1/*.d $(UVMDIR)/src/uvm/seq/*.d $(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d $(UVMDIR)/src/uvm/dap/*.d
	$(DMD) -m$(MODEL) -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -shared -of$@ -L-ldl -L-lsha3 -L-Lc-model/$(MODEL)-bit -L-lvpi -L-l$(PHOBOS) -L-R$(LIBDIR) -L-R$(ICARUSLIBPATH) $^

sha: sha.d $(VLANGDIR)/src/esdl/sync/*.d $(VLANGDIR)/src/esdl/sys/*.d $(VLANGDIR)/src/esdl/intf/*.d $(VLANGDIR)/src/esdl/base/*.d $(VLANGDIR)/src/esdl/data/*.d $(VLANGDIR)/src/esdl/*.d $(VLANGDIR)/src/esdl/posix/sys/net/*.d  $(UVMDIR)/src/uvm/*.d $(UVMDIR)/src/uvm/meta/*.d $(UVMDIR)/src/uvm/base/*.d $(UVMDIR)/src/uvm/comps/*.d $(UVMDIR)/src/uvm/dap/*.d $(UVMDIR)/src/uvm/tlm1/*.d $(UVMDIR)/src/uvm/seq/*.d $(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d $(UVMDIR)/src/uvm/dap/*.d
	$(DMD) -version=EDISON -m$(MODEL) -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -of$@ -L-ldl -L-l$(MRAALIB) -L-l$(PHOBOS) -L-R$(MRAALIBDIR) -L-L$(MRAALIBDIR) -L-R$(LIBDIR) $^

sha_norand: sha_norand.d $(VLANGDIR)/src/esdl/sync/*.d \
	$(VLANGDIR)/src/esdl/sys/*.d \
	$(VLANGDIR)/src/esdl/intf/*.d \
	$(VLANGDIR)/src/esdl/base/*.d \
	$(VLANGDIR)/src/esdl/data/bstr.d \
	$(VLANGDIR)/src/esdl/data/bvec.d \
	$(VLANGDIR)/src/esdl/data/package.d \
	$(VLANGDIR)/src/esdl/data/packed.d \
	$(VLANGDIR)/src/esdl/data/packer.d \
	$(VLANGDIR)/src/esdl/data/queue.d \
	$(VLANGDIR)/src/esdl/data/sync.d \
	$(VLANGDIR)/src/esdl/data/time.d \
	$(VLANGDIR)/src/esdl/*.d \
	$(VLANGDIR)/src/esdl/posix/sys/net/*.d  \
	$(UVMDIR)/src/uvm/*.d \
	$(UVMDIR)/src/uvm/meta/*.d \
	$(UVMDIR)/src/uvm/base/*.d \
	$(UVMDIR)/src/uvm/comps/*.d \
	$(UVMDIR)/src/uvm/dap/*.d \
	$(UVMDIR)/src/uvm/tlm1/*.d \
	$(UVMDIR)/src/uvm/seq/*.d \
	$(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d \
	$(UVMDIR)/src/uvm/dap/*.d
	$(DMD) -version=UVM_NORANDOM -version=ESDL_NORAND -m$(MODEL) -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -of$@ -L-ldl -L-l$(PHOBOS) -L-R$(LIBDIR) $^


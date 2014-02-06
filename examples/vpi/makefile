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

LD_RUN_PATH := /home/puneet/local/works/dmd/lib
DFLAGS = -version=UVM_NO_WAIT_FOR_NBA -version=COSIM_VERILOG -fPIC -w -O # -version=UVM_NO_DEPRECATED
VLANGDIR = /home/puneet/work/vlang
UVMDIR = /home/puneet/work/vlang-uvm

all: helloObj hellod

testuvm: helloObj

helloObj: helloObj.vpi hello.vvp
	vvp -M. -mhelloObj hello.vvp +UVM_TESTCASE=test -F +UVM_OTHER_TESTCASE=foo -f +UVM_FIXME

hellod: hellod.vpi hello.vvp
	vvp -M. -mhellod hello.vvp +UVM_TESTCASE=foo -F +UVM_TESTCASE=foo -f +UVM_FIXME

clean:
	rm -fr objs uvm.a *.vpi *.vvp *.o

hello.o: hello.c
	gcc -I$(VLANGDIR)/src/esdl/intf  -c -fpic hello.c -o $@

helloObj.o: helloObj.d
	dmd $(DFLAGS) -c -fPIC  -I$(VLANGDIR)/src -I$(UVMDIR)/src $^

hellod.o: hellod.d
	dmd $(DFLAGS) -c -fPIC  -I$(VLANGDIR)/src -I$(UVMDIR)/src $^

# None of the following two work because of some bug in DMD
# helloObj.vpi: helloObj.o  hello.o objs/comm.o objs/core.o objs/time.o objs/vpi.o objs/bvec.o objs/bstr.o objs/rand.o objs/cstparse.o objs/parser.o objs/obdd.o objs/queue.o objs/sync.o objs/packer.o objs/libuvmso.a
# 	gcc -shared -o $@ $^ -lvpi -lphobos2 -L/home/puneet/local/dmd/lib -Wl,-rpath,/home/puneet/local/dmd/lib -Xlinker --no-warn-search-mismatch -Xlinker --export-dynamic

# helloObj.vpi: helloObj.d hello.o
# 	dmd -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -shared -m64 -of$@ -L-ldl -L-lvpi -L-luvm -L-R./objs -L-L./objs -L-lphobos2 -L-R/home/puneet/local/dmd/lib $^

helloObj.vpi: helloObj.d hello.o $(VLANGDIR)/src/esdl/base/comm.d $(VLANGDIR)/src/esdl/base/core.d $(VLANGDIR)/src/esdl/base/time.d $(VLANGDIR)/src/esdl/intf/vpi.d $(VLANGDIR)/src/esdl/data/bvec.d $(VLANGDIR)/src/esdl/data/cstx.d $(VLANGDIR)/src/esdl/data/rand.d $(VLANGDIR)/src/esdl/data/obdd.d $(VLANGDIR)/src/esdl/data/queue.d $(VLANGDIR)/src/esdl/data/sync.d $(VLANGDIR)/src/esdl/data/packer.d $(UVMDIR)/src/uvm/meta/*.d $(UVMDIR)/src/uvm/base/*.d $(UVMDIR)/src/uvm/comps/*.d $(UVMDIR)/src/uvm/tlm1/*.d $(UVMDIR)/src/uvm/seq/*.d $(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d
	dmd -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -shared -m64 -of$@ -L-ldl -L-lvpi -L-lphobos2 -L-R/home/puneet/local/dmd/lib $^

objs/libuvm.so: $(VLANGDIR)/src/esdl/base/comm.d $(VLANGDIR)/src/esdl/base/core.d $(VLANGDIR)/src/esdl/base/time.d $(VLANGDIR)/src/esdl/intf/vpi.d $(VLANGDIR)/src/esdl/data/bvec.d $(VLANGDIR)/src/esdl/data/cstx.d $(VLANGDIR)/src/esdl/data/rand.d $(VLANGDIR)/src/esdl/data/obdd.d $(VLANGDIR)/src/esdl/data/queue.d $(VLANGDIR)/src/esdl/data/sync.d $(VLANGDIR)/src/esdl/data/packer.d $(UVMDIR)/src/uvm/meta/*.d $(UVMDIR)/src/uvm/base/*.d $(UVMDIR)/src/uvm/comps/*.d $(UVMDIR)/src/uvm/tlm1/*.d $(UVMDIR)/src/uvm/seq/*.d $(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d
	dmd -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -shared -m64 -of$@ -L-ldl -L-lvpi -L-lphobos2 -L-R/home/puneet/local/dmd/lib $^

objs/libuvmso.a: $(VLANGDIR)/src/esdl/base/comm.d $(VLANGDIR)/src/esdl/base/core.d $(VLANGDIR)/src/esdl/base/time.d $(VLANGDIR)/src/esdl/intf/vpi.d $(VLANGDIR)/src/esdl/data/bvec.d $(VLANGDIR)/src/esdl/data/cstx.d $(VLANGDIR)/src/esdl/data/rand.d $(VLANGDIR)/src/esdl/data/obdd.d $(VLANGDIR)/src/esdl/data/queue.d $(VLANGDIR)/src/esdl/data/sync.d $(VLANGDIR)/src/esdl/data/packer.d $(UVMDIR)/src/uvm/meta/*.d $(UVMDIR)/src/uvm/base/*.d $(UVMDIR)/src/uvm/comps/*.d $(UVMDIR)/src/uvm/tlm1/*.d $(UVMDIR)/src/uvm/seq/*.d $(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d
	dmd -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -m64 -lib -of$@ -L-ldl -L-lvpi -L-lphobos2 -L-R/home/puneet/local/dmd/lib $^

hellod.vpi: hellod.d hello.o $(VLANGDIR)/src/esdl/base/comm.d $(VLANGDIR)/src/esdl/base/core.d $(VLANGDIR)/src/esdl/base/time.d $(VLANGDIR)/src/esdl/intf/vpi.d $(VLANGDIR)/src/esdl/data/bvec.d $(VLANGDIR)/src/esdl/data/cstx.d $(VLANGDIR)/src/esdl/data/rand.d $(VLANGDIR)/src/esdl/data/obdd.d $(VLANGDIR)/src/esdl/data/queue.d $(VLANGDIR)/src/esdl/data/sync.d $(VLANGDIR)/src/esdl/data/packer.d $(UVMDIR)/src/uvm/meta/*.d $(UVMDIR)/src/uvm/base/*.d $(UVMDIR)/src/uvm/comps/*.d $(UVMDIR)/src/uvm/tlm1/*.d $(UVMDIR)/src/uvm/seq/*.d $(UVMDIR)/src/uvm/vpi/uvm_svcmd_vpi.d
	dmd -I$(VLANGDIR)/src -I$(UVMDIR)/src $(DFLAGS) -shared -m64 -of$@ -L-ldl -L-lvpi -L-lphobos2 -L-R/home/puneet/local/dmd/lib $^

hello.vvp: hello.v
	iverilog -ohello.vvp hello.v


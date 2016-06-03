MODEL = 64
DFLAGS = -m$(MODEL) -fPIC -g -w -O # -version=UVM_NO_DEPRECATED
ESDLDIR = ${HOME}/code/vlang
VLANGDIR = ${HOME}/code/vlang-uvm

ESDLSOURCES := $(shell find $(ESDLDIR)/src -name '*.d')
VLANGSOURCES := $(shell find $(VLANGDIR)/src -name '*.d')

DMDDIR = ${HOME}/local/dmd$(MODEL)
DMD = $(DMDDIR)/bin/dmd

DMDLIBDIR = $(DMDDIR)/lib
PHOBOS = phobos2

LIBDIR = $(VLANGDIR)/lib

.PHONY: run_test

all: run_test

clean:
	rm -f test

test: test.d $(ESDLSOURCES) $(VLANGSOURCES)
	(cd $(LIBDIR); make libs)
	$(DMD) -m$(MODEL) -g -I$(VLANGDIR)/src -I$(ESDLDIR)/src $(DFLAGS)  -of$@ -L-l$(PHOBOS) -L-R$(DMDLIBDIR) -L-lesdl -L-lvlang -L-L$(LIBDIR) -L-R$(LIBDIR) $<

run_test: test
	./test +UVM_TESTNAME=test.test


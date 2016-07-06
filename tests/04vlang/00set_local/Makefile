include ../../test_defines.mk

.PHONY: run_test all libs

all: run_test

clean:
	rm -f test

libs:
	(cd $(LIBDIR); make libs;)

test: test.d libs
	$(DMD) -m$(MODEL) -g -I$(VLANGDIR)/src -I$(ESDLDIR)/src $(DFLAGS)  -of$@ -L-l$(PHOBOS) -L-R$(DMDLIBDIR) -L-lesdl -L-lvlang -L-L$(LIBDIR) -L-R$(LIBDIR) $<

run_test: test
	./test +UVM_TESTNAME=test.test


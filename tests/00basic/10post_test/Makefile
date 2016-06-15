#---------------------------------------------------------------------- 
#   Copyright 2016 Coverify Systems Technology
#   All Rights Reserved Worldwide 
# 
#   Licensed under the Apache License, Version 2.0 (the 
#   "License"); you may not use this file except in 
#   compliance with the License.  You may obtain a copy of 
#   the License at 
# 
#       http:#www.apache.org/licenses/LICENSE-2.0 
# 
#   Unless required by applicable law or agreed to in 
#   writing, software distributed under the License is 
#   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
#   CONDITIONS OF ANY KIND, either express or implied.  See 
#   the License for the specific language governing 
#   permissions and limitations under the License. 
#----------------------------------------------------------------------

include ../../test_defines.mk

.PHONY: all libs run_test

all: run_test

clean:
	rm -f test

libs:
	(cd $(LIBDIR); make libs;)

test: test.d libs
	$(DMD) -m$(MODEL) -g -I$(VLANGDIR)/src -I$(ESDLDIR)/src $(DFLAGS)  -of$@ -L-l$(PHOBOS) -L-R$(DMDLIBDIR) -L-lesdl -L-lvlang -L-L$(LIBDIR) -L-R$(LIBDIR) $<

run_test: test
	./test +UVM_TESTNAME=test.test


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

.PHONY: all libs run_test

all: run_test

clean:
	rm -f test

test: test.d
	ldc2 -w -O3 -release -of$@  -L-luvm-ldc-shared -L-lesdl-ldc-shared -L-lphobos2-ldc-shared -L-ldruntime-ldc-shared $<

run_test: test
	./test +UVM_TESTNAME=test.test


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

MODEL = 64
DFLAGS = -m$(MODEL) -g -fPIC -w -O # -version=UVM_NO_DEPRECATED
ESDLDIR = ${HOME}/code/vlang
VLANGDIR = ${HOME}/code/vlang-uvm

DMDDIR = /home/puneet/release/vlang-dev-1.9
DMD = $(DMDDIR)/bin/ldmd2

DMDLIBDIR = $(DMDDIR)/lib
PHOBOS = phobos2-ldc-shared
DRUNTIME = druntime-ldc-shared
UVMLIB = uvm-ldc-shared
ESDLLIB = esdl-ldc-shared

LIBDIR = $(VLANGDIR)/lib

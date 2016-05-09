//
//------------------------------------------------------------------------------
//   Copyright 2011 Mentor Graphics Corporation
//   Copyright 2011 Cadence Design Systems, Inc. 
//   Copyright 2011 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------------------------

module uvm.dpi.uvm_svcmd_dpi;


import esdl.intf.vpi;
import esdl.base.core: getRootEntity;
import std.conv;

public string[][] uvm_dpi_get_args() {
  s_vpi_vlog_info info;
  string[] argv;
  string[][] argvs;

  bool vpiUsable = cast(bool) vpi_get_vlog_info(&info);

  auto vlogargv = info.argv;
  auto vlogargc = info.argc;

  // use the vlang commandline arguments if we are not using Verilog
  // Note that command line arguments have to be passed at the time of
  // RootEntity elaboration
  string[] vlangargv = getRootEntity().getArgv();

  uint argc;

  if(vpiUsable) {
    argc = vlogargc;
    if(vlogargv is null) return argvs;
  }
  else {
    argc = cast(uint) vlangargv.length;
  }

  
  
  for (size_t i=0; i != argc; ++i) {

    string arg;
    if(vpiUsable) {
      char* vlogarg = *(vlogargv+i);
      arg = (vlogarg++).to!string;
    }
    else {
      arg = vlangargv[i];
    }
    
    if(arg == "-f" || arg == "-F") {
      argvs ~= argv;
      argv.length = 0;
    }
    else {
      argv ~= arg;
    }
  }
  argvs ~= argv;
  return argvs;
}

public string uvm_dpi_get_tool_name() {
  s_vpi_vlog_info info;
  vpi_get_vlog_info(&info);
  return info.product.to!string;
}

public string uvm_dpi_get_tool_version() {
  s_vpi_vlog_info info;
  vpi_get_vlog_info(&info);
  return info.product_version.to!string;
}

// No regexp stuff is required since we already have that in phobos

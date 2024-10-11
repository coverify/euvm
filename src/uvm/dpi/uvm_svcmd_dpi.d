//
//------------------------------------------------------------------------------
// Copyright 2014-2018 Coverify Systems Technology
// Copyright 2010-2012 AMD
// Copyright 2013-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 Mentor Graphics Corporation
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

  bool use_vpi_args = cast(bool) vpi_get_vlog_info(&info) &&
                      vpiGetProduct() != "Verilator";

  auto vlogArgv = info.argv;
  auto vlogArgc = info.argc;

  // use the esdl commandline arguments if we are not using Verilog
  // Note that command line arguments have to be passed at the time of
  // RootEntity elaboration

  uint argc;

  if(use_vpi_args) {
    argc = vlogArgc;
    if (vlogArgv is null) return argvs;
  }
  else {
    string[] esdlArgv = getRootEntity().getArgv();
    argc = cast(uint) esdlArgv.length;
  }

  
  
  for (size_t i=0; i != argc; ++i) {

    string arg;
    if(use_vpi_args) {
      char* vlogArg = *(vlogArgv+i);
      arg = (vlogArg++).to!string;
    }
    else {
      string[] esdlArgv = getRootEntity().getArgv();
      arg = esdlArgv[i];
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

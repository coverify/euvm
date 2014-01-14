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

module uvm.vpi.uvm_svcmd_vpi;


version(COSIM_VERILOG) {
  import esdl.intf.vpi;
  import std.conv;

  public string[][] vpi_get_args() {
    s_vpi_vlog_info info;
    string[] argv;
    string[][] argvs;

    vpi_get_vlog_info(&info);

    auto vlogargv = info.argv;
    auto vlogargc = info.argc;

    if(vlogargv is null) return argvs;

    for (size_t i=0; i != vlogargc; ++i) {
      char* vlogarg = *(vlogargv+i);
      string arg;
      arg = (vlogarg++).to!string;
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

  public string vpi_get_tool_name() {
    s_vpi_vlog_info info;
    vpi_get_vlog_info(&info);
    return info.product.to!string;
  }

  public string vpi_get_tool_version() {
    s_vpi_vlog_info info;
    vpi_get_vlog_info(&info);
    return info.product_version.to!string;
  }
}

 else {
   public string[][] vpi_get_args() {
     return null;
   }

   public string vpi_get_tool_name() {
     return "?";
   }

   public string vpi_get_tool_version() {
     return "?";
   }
 }

// No regexp stuff is required since we already have that in phobos

//----------------------------------------------------------------------
//   Copyright 2012-2016 Coverify Systems Technology
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2013-2014 NVIDIA Corporation
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
//----------------------------------------------------------------------

module uvm.base.uvm_version;

import std.conv: to;

enum string UVM_NAME = "UVM";
enum uint UVM_MAJOR_REV = 1;
enum uint UVM_MINOR_REV = 2;
enum string UVM_FIX_REV = "";

enum string uvm_co_copyright   = "(C) 2012-2018 Coverify Systems Technology";
enum string uvm_mgc_copyright  = "(C) 2007-2014 Mentor Graphics Corporation";
enum string uvm_cdn_copyright  = "(C) 2007-2014 Cadence Design Systems, Inc.";
enum string uvm_snps_copyright = "(C) 2006-2014 Synopsys, Inc.";
enum string uvm_cy_copyright   = "(C) 2011-2013 Cypress Semiconductor Corp.";
enum string uvm_nv_copyright   = "(C) 2013-2014 NVIDIA Corporation";
enum string uvm_revision = UVM_NAME ~ "-" ~ UVM_MAJOR_REV.to!string() ~
  "." ~ UVM_MINOR_REV.to!string() ~ UVM_FIX_REV;

string uvm_revision_string() {
  return uvm_revision;
}

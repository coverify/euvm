//
//------------------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
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
module uvm.comps.uvm_env;
import uvm.base;
import esdl.rand.misc: rand;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_env
//
// The base class for hierarchical containers of other components that
// together comprise a complete environment. The environment may
// initially consist of the entire testbench. Later, it can be reused as
// a sub-environment in even larger system-level environments.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 13.3.1

abstract class uvm_env: uvm_component, rand.barrier
{

  mixin uvm_abstract_component_essentials;

  // Function -- NODOCS -- new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.

  // @uvm-ieee 1800.2-2020 auto 13.3.2
  this(string name="env", uvm_component parent=null) {
    super(name,parent);
  }

}

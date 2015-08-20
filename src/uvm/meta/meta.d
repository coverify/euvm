// This file lists D routines required for coding UVM
//
//------------------------------------------------------------------------------
// Copyright 2012-2014 Coverify Systems Technology
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
module uvm.meta.meta;
// import std.traits: fullyQualifiedName;

public template qualifiedTypeName(T) {
  // typeid(T).stringof returns string of the form "&typeid(qualifiedTypeName)"
  enum string qualifiedTypeName = typeid(T).stringof[8..$-1];
  // enum string qualifiedTypeName = fullyQualifiedName!T;
}

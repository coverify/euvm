//
//------------------------------------------------------------------------------
//   Copyright 2012-2016 Coverify Systems Technology
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

module uvm.base.uvm_once;

import std.traits: fullyQualifiedName;

class uvm_once_base
{
  static get_instance(T)() {
    static T instance;
    if (instance is null) {
      instance = uvm_root_once.get_once!T();
    }
    return instance;
  }
}

class uvm_root_once
{
  // uvm_once_base[string] once_pool;
  uvm_once_base[ClassInfo] once_pool;
  
  static string get_instance_name(T)() {
    char[] name = (fullyQualifiedName!T).dup;
    foreach (ref c; name) {
      if (c == '.') {
	c = '_';
      }
    }
    name ~= "_";
    return cast(string) name;
  }
  
  static T get_once(T)() {
    import uvm.base.uvm_entity;
    uvm_root_once once = uvm_entity_base.get().root_once();
    synchronized(once) {
      T instance;
      enum string instName = get_instance_name!T;
      static if (__traits(hasMember, uvm_root_once, instName)) {
	if (__traits(getMember, once, instName) is null) {
	  instance = new T();
	  __traits(getMember, once, instName) = instance;
	}
	else {
	  instance = cast(T) inst;
	  assert(instance !is null);
	}
      }
      else {
	// auto lookup = instName in once.once_pool;
	auto tid = typeid(T);
	auto lookup = tid in once.once_pool;
	if (lookup !is null) {
	  instance = cast(T) *lookup;
	  assert(instance !is null);
	}
	else {
	  instance = new T();
	  // once.once_pool[instName] = instance;
	  once.once_pool[tid] = instance;
	}
      }
      return instance;
    }
  }
}

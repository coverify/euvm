//
//------------------------------------------------------------------------------
//   Copyright 2012-2021 Coverify Systems Technology
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

module uvm.base.uvm_scope;

import uvm.meta.meta: qualifiedTypeName;
// import uvm.base.uvm_entity: uvm_entity_base;

class uvm_scope_base
{
  static T get_instance(T)() {
    static T instance;
    if (instance is null) {
      instance = uvm_root_scope.get_scope!T();
    }
    return instance;
  }

  // static T get_instance(T)(uvm_entity_base entity) {
  //   return uvm_root_scope.get_scope!T(entity);
  // }
}

class uvm_root_scope
{
  uvm_scope_base[ClassInfo] _uvm_scope_pool;
  
  static string get_instance_name(T)() {
    char[] name = (qualifiedTypeName!T).dup;
    foreach (ref c; name) {
      if (c == '.') {
	c = '_';
      }
    }
    name ~= "_";
    return cast (string) name;
  }
  
  static T get_scope(T)() {
    import uvm.base.uvm_entity: uvm_entity_base;
    uvm_root_scope _scope = uvm_entity_base.get().get_root_scope();
    synchronized (_scope) {
      T instance;
      enum string instName = get_instance_name!T;
      static if (__traits(hasMember, uvm_root_scope, instName)) {
	if (__traits(getMember, _scope, instName) is null) {
	  instance = new T();
	  __traits(getMember, _scope, instName) = instance;
	}
	else {
	  instance = cast (T) inst;
	  assert (instance !is null);
	}
      }
      else {
	// auto lookup = instName in _scope._uvm_scope_pool;
	auto tid = typeid(T);
	auto lookup = tid in _scope._uvm_scope_pool;
	if (lookup !is null) {
	  instance = cast (T) *lookup;
	  assert (instance !is null);
	}
	else {
	  instance = new T();
	  // _scope._uvm_scope_pool[instName] = instance;
	  _scope._uvm_scope_pool[tid] = instance;
	}
      }
      return instance;
    }
  }

  // static T get_scope(T)(uvm_entity_base entity) {
  //   uvm_root_scope _scope = entity.get_root_scope();
  //   assert (_scope !is null);
  //   synchronized (_scope) {
  //     T instance;
  //     enum string instName = get_instance_name!T;
  //     static if (__traits(hasMember, uvm_root_scope, instName)) {
  // 	if (__traits(getMember, _scope, instName) is null) {
  // 	  assert (false, "Unknown Scope Instance");
  // 	}
  // 	else {
  // 	  instance = cast (T) inst;
  // 	  assert (instance !is null);
  // 	}
  //     }
  //     else {
  // 	// auto lookup = instName in _scope._uvm_scope_pool;
  // 	auto tid = typeid(T);
  // 	auto lookup = tid in _scope._uvm_scope_pool;
  // 	if (lookup !is null) {
  // 	  instance = cast (T) *lookup;
  // 	  assert (instance !is null);
  // 	}
  // 	else {
  // 	  instance = new T();
  // 	  // _scope._uvm_scope_pool[instName] = instance;
  // 	  _scope._uvm_scope_pool[tid] = instance;
  // 	  // import std.conv: to;
  // 	  // assert (false, "Unknown Scope Instance: " ~ tid.to!string());
  // 	}
  //     }
  //     return instance;
  //   }
  // }
  
}

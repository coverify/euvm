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

module uvm.base.uvm_entity;

import uvm.base.uvm_root: uvm_root;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_once;
import uvm.base.uvm_misc;

import uvm.meta.misc;
import uvm.meta.meta;
import esdl.base.core;
import core.sync.semaphore: Semaphore;

import std.random;

// This is where the uvm gets instantiated as part of the ESDL
// simulator. Unlike the SystemVerilog version where uvm_root is a
// singleton, we can have multiple instances of uvm_root, but each
// ESDL RootEntity could have only one instance of uvm_root.

class uvm_entity_base: Entity
{
  mixin(uvm_sync_string);
  this() {
    synchronized(this) {
      _uvm_root_init_semaphore = new Semaphore(); // count 0
      // uvm_once has some events etc that need to know the context for init
      set_thread_context();
      _root_once = new uvm_root_once();
    }
  }

  // Only for use by the uvm_root constructor -- use nowhere else
  static package uvm_entity_base _uvm_entity_inst;

  @uvm_immutable_sync
  private Semaphore _uvm_root_init_semaphore;

  // effectively immutable
  private uvm_root_once _root_once;
  
  uvm_root_once root_once() {
    return _root_once;
  }

  static uvm_entity_base get() {
    auto context = EntityIntf.getContextEntity();
    if(context !is null) {
      auto entity = cast(uvm_entity_base) context;
      assert(entity !is null);
      return entity;
    }
    return null;
  }

  abstract uvm_root _get_uvm_root();
  abstract uvm_root get_root();
  // The randomization seed passed from the top.
  // alias _get_uvm_root this;

  // This method would associate a free running thread to this UVM
  // ROOT instance -- this function can be called multiple times
  // within the same thread in order to switch context
  void set_thread_context() {
    auto proc = Process.self();
    if(proc !is null) {
      auto _entity = cast(uvm_entity_base) proc.getParentEntity();
      assert(_entity is null, "Default context already set to: " ~
	     _entity.getFullName());
    }
    this.setThreadContext();
  }
}

class uvm_entity(T): uvm_entity_base if(is(T: uvm_root))
{
  mixin(uvm_sync_string);
    
  // alias _get_uvm_root this;

  @uvm_private_sync
    bool _uvm_root_initialized;

  // The uvm_root instance corresponding to this RootEntity.
  // effectively immutable
  @uvm_immutable_sync
    private T _uvm_root_instance;

  this() {
    synchronized(this) {
      super();
      // set static variable that would later be used by uvm_root
      // constructor. Can not pass this instance as an argument to
      // the uvm_root constructor since the constructor has no
      // argument. If an argument is introduced, that will spoil
      // uvm_root user API.
      uvm_entity_base._uvm_entity_inst = this;
      _uvm_root_instance = new T();
      resetThreadContext();
      _seed = uniform!int;
    }
  }

  override void _esdl__postElab() {
    uvm_root_instance.set_name(getFullName() ~ ".(" ~
			       qualifiedTypeName!T ~ ")");
  }

  override T _get_uvm_root() {
    return uvm_root_instance;
  }

  // this is part of the public API
  // Make the uvm_root available only after the simulaion has
  // started and the uvm_root is ready to use
  override T get_root() {
    while(uvm_root_initialized is false) {
      uvm_root_init_semaphore.wait();
      uvm_root_init_semaphore.notify();
    }
    // expose the root_instance to the external world only after
    // elaboration is done
    uvm_root_instance.wait_for_end_of_elaboration();
    return uvm_root_instance;
  }

  void initial() {
    lockStage();
    fileCaveat();
    // init_domains can not be moved to the constructor since it
    // results in notification of some events, which can only
    // happen once the simulation starts
    uvm_root_instance.init_domains();
    wait(0);
    uvm_root_initialized = true;
    uvm_root_init_semaphore.notify();
    uvm_seed_map.set_seed(_seed);
    uvm_root_instance.initial();
  }

  Task!(initial) _init;

  uint _seed;

  void set_seed(uint seed) {
    synchronized(this) {
      if(_uvm_root_initialized) {
	uvm_report_fatal("SEED",
			 "Method set_seed can not be called after" ~
			 " the simulation has started",
			 uvm_verbosity.UVM_NONE);
      }
      _seed = seed;
    }
  }
}

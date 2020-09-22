//
//------------------------------------------------------------------------------
//   Copyright 2012-2019 Coverify Systems Technology
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
import uvm.base.uvm_globals: uvm_init;
import uvm.base.uvm_object_globals: uvm_core_state, m_uvm_core_state;
import uvm.base.uvm_once;

import uvm.meta.misc;
import uvm.meta.meta;

import esdl.base.core;
import core.sync.semaphore: Semaphore;


// This is where the uvm gets instantiated as part of the ESDL
// simulator. Unlike the SystemVerilog version where uvm_root is a
// singleton, we can have multiple instances of uvm_root, but each
// ESDL RootEntity could have only one instance of uvm_root.

class uvm_harness: RootEntity
{
  override size_t _esdl__defProcStackSize() {
    return 1024 * 1024;		// Todo use lower values if limited available memory
  }

  void config_stack(size_t size) {
    _esdl__configStack(size);
  }
  
  ubyte start() {
    return super.simulate();
  }

  void start_bg() {
    super.forkSim();
    foreach (child; getChildComps()) {
      auto entity = cast (uvm_entity_base) child;
      if (entity !is null) {
	entity.wait_for_end_of_elaboration();
      }
    }
  }
}

class uvm_tb_root: uvm_root
{
  override void initial() {
    run_test();
  }
}

alias uvm_testbench = uvm_tb;

class uvm_tb: uvm_harness
{
  uvm_entity!(uvm_tb_root) root_entity;
  void set_seed(uint seed) {
    root_entity.set_seed(seed);
  }
}

class uvm_tb_custom_root(ROOT) if (is (ROOT: uvm_root)) : uvm_harness
{
  uvm_entity!(ROOT) root_entity;
  void set_seed(uint seed) {
    root_entity.set_seed(seed);
  }
}

abstract class uvm_entity_base: Entity
{
  mixin (uvm_sync_string);
  this() {
    synchronized (this) {
      _uvm_root_init_semaphore = new Semaphore(); // count 0
      // uvm_once has some events etc that need to know the context for init
      set_thread_context();
      _root_once = new uvm_root_once();
      m_uvm_core_state = uvm_core_state.UVM_CORE_PRE_INIT;
    }
  }

  @uvm_immutable_sync
  private Semaphore _uvm_root_init_semaphore;

  // effectively immutable
  // @uvm_immutable_sync
  private uvm_root_once _root_once;
  
  uvm_root_once root_once() {
    return _root_once;
  }

  static uvm_entity_base get() {
    auto context = EntityIntf.getContextEntity();
    if (context !is null) {
      auto entity = cast (uvm_entity_base) context;
      assert (entity !is null);
      return entity;
    }
    return null;
  }

  abstract void wait_for_end_of_elaboration();
  abstract uvm_root _get_uvm_root();
  abstract uvm_root get_root();
  abstract uint get_seed();
  abstract void set_seed(uint seed);
  // The randomization seed passed from the top.
  // alias _get_uvm_root this;

  // This method would associate a free running thread to this UVM
  // ROOT instance -- this function can be called multiple times
  // within the same thread in order to switch context
  void set_thread_context() {
    auto proc = Process.self();
    if (proc !is null) {
      auto _entity = cast (uvm_entity_base) proc.getParentEntity();
      assert (_entity is null, "Default context already set to: " ~
	     _entity.getFullName());
    }
    this.setThreadContext();
  }
}

class uvm_entity(T): uvm_entity_base if (is (T: uvm_root))
{
  mixin (uvm_sync_string);
    
  // alias _get_uvm_root this;

  @uvm_private_sync
    private bool _uvm_root_initialized;

  // The uvm_root instance corresponding to this RootEntity.
  // effectively immutable
  @uvm_immutable_sync
    private T _uvm_root_instance;

  this() {
    import std.random;		// uniform
    synchronized (this) {
      super();
      /* Now handled in initial block
      // set static variable that would later be used by uvm_root
      // constructor. Can not pass this instance as an argument to
      // the uvm_root constructor since the constructor has no
      // argument. If an argument is introduced, that will spoil
      // uvm_root user API.
      // _uvm_root_instance = new T();
      // _uvm_root_instance.initialize(this);
      */
      resetThreadContext();
      _seed = uniform!int;
    }
  }

  // override void _esdl__postElab() {
  //   uvm_root_instance.set_name(getFullName() ~ ".(" ~
  // 			       qualifiedTypeName!T ~ ")");
  // }

  override T _get_uvm_root() {
    return uvm_root_instance;
  }

  // this is part of the public API
  // Make the uvm_root available only after the simulaion has
  // started and the uvm_root is ready to use
  override T get_root() {
    // expose the root_instance to the external world only after
    // elaboration is done
    this.wait_for_end_of_elaboration();
    return uvm_root_instance;
  }

  override void wait_for_end_of_elaboration() {
    while (uvm_root_initialized is false) {
      uvm_root_init_semaphore.wait();
      uvm_root_init_semaphore.notify();
    }
    uvm_root_instance.wait_for_end_of_elaboration();
  }

  void initial() {
    import uvm.base.uvm_misc: uvm_seed_map;
    lockStage();
    fileCaveat();

    m_uvm_core_state = uvm_core_state.UVM_CORE_INITIALIZING;

    // we do not set the uvm_root name as "__top__" because
    // we can have multiple uvm_root instances with different names
    _uvm_root_instance = new T();
    _uvm_root_instance.set_name(getFullName() ~ ".(" ~
				qualifiedTypeName!T ~ ")");
    _uvm_root_instance.initialize(this);

    uvm_init();

    // initialize parallelism for the uvm_root_instance
    configure_parallelism();

    wait(0);
    uvm_root_initialized = true;
    uvm_root_init_semaphore.notify();
    uvm_seed_map.set_seed(_seed);
    _uvm_root_instance.initial();
  }

  Task!(initial) _init;

  uint _seed;

  override final void set_seed(uint seed) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      if (_uvm_root_initialized) {
	uvm_report_fatal("SEED",
			 "Method set_seed can not be called after" ~
			 " the simulation has started",
			 uvm_verbosity.UVM_NONE);
      }
      _seed = seed;
    }
  }
  
  override final uint get_seed() {
    synchronized(this) {
      return _seed;
    }
  }

  // Configure parallelism for the uvm_root instance
  private void configure_parallelism() {
    // at instance level, we do not have a way for the user to add
    // attributes to uvm_root
    auto linfo = _esdl__uda!(_esdl__Multicore, T);
    auto pconf = this._esdl__getMulticoreConfig();
    assert (pconf !is null);
    auto config = linfo.makeCfg(pconf);
    uvm_root_instance._uvm__configure_parallelism(config);
  }
  
}

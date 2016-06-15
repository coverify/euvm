import std.stdio;
import esdl.base.core;
import esdl.base.comm;
import esdl.intf.vpi;
import uvm.base.uvm_object;
import uvm.base.uvm_component;
import uvm.base.uvm_queue;
import uvm.base.uvm_comparer;
import uvm.base.uvm_root: uvm_entity, uvm_top;
import uvm.base.uvm_object_defines;
import uvm.comps.uvm_test;

class test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  override public void report() {
    import std.stdio;
    writeln("** UVM TEST PASSED **");
  }
}

class Bar : uvm_component
{
  Foo test;
  uvm_queue!int q;
  uvm_comparer cmp;
  void message()
  {
    import uvm.base.uvm_misc;
    auto f = test.get_type();
    import std.stdio;
    writeln("Obj is named: ", test.get_full_name());
    writeln("Random seed is: ", uvm_global_random_seed);
    cmp = new uvm_comparer;
    cmp.compare("foo", 0, 1);
  }
  Task!message msg;

  this(string name, uvm_component parent) {
    super(name, parent);
  }
}

class Foo : uvm_object
{
  // Rand!uint a;
  // Rand!ubyte b;
  
  // Constraint! q{
  //   a + b < 32;
  // } sum;
}

class EsdlRoot: uvm_entity
{

  this(string name, uint seed) {
    super(name, seed);
  }

  void initial() {
    auto top = uvm_top();
    // import std.stdio;
    // writeln(top.get_full_name());
    if(top !is null) {
      top.run_test();
    }
  }

  Task!initial _init;

  override void doConfig() {
    timeUnit = 100.psec;
    timePrecision = 10.psec;
  }
}

static import core.runtime;
extern (C) void hellod() {
  // rt_init(0);
  import std.stdio;
  writeln("Hello World from D");
  // theRoot.elaborate();
  // for (size_t i=1; i!=1000; ++i) {
  //   // theRoot.doSim(i.nsec);
  //   // theRoot.waitSim();
  //   simulateAllRoots(i.nsec);
  //   // theRoot.simulate(i.nsec);
  // }
  // theRoot.terminate();
}

extern(C) void initEsdl() {
  import core.runtime;  
  Runtime.initialize();
  hello_register();

  import std.stdio;
  import std.random;
  // Root0 theRoot = new Root0("theRoot", uniform!uint());
  // theRoot.doElab();
  // theRoot.waitElab();
  auto theRoot = new EsdlRoot("theRoot", uniform!uint());
  theRoot.elaborate();
  theRoot.simulate(100.nsec);
  theRoot.terminate();

  // s_cb_data new_cb;
  // new_cb.reason = vpiCbStartOfSimulation;
  // new_cb.cb_rtn = &callback_cbNextSimTime;//next callback address
  // // new_cb.time = null;
  // // new_cb.obj = null;
  // // new_cb.value = null;
  // // new_cb.user_data = null;
  // vpi_register_cb(&new_cb);

  // s_cb_data end_cb;
  // new_cb.reason = vpiCbEndOfSimulation;
  // new_cb.cb_rtn = &callback_cleanup;//next callback address
  // // new_cb.time = null;
  // // new_cb.obj = null;
  // // new_cb.value = null;
  // // new_cb.user_data = null;
  // vpi_register_cb(&new_cb);



  auto precision = vpi_get(vpiTimePrecision,null);
  auto unit = vpi_get(vpiTimeUnit,null);
  writeln("precision: ", precision, " unit: ", unit);

  writeln(vpi_get_args());

}


int hello_compiletf(char*user_data) {
  return 0;
}

int hello_calltf(char*user_data) {
  writeln("Hello, World!");
  hellod();
  return 0;
}

void hello_register()
{
  import std.string;
  s_vpi_systf_data tf_data;

  tf_data.type      = vpiSysTask;
  tf_data.tfname    = cast(char*) "$hello".toStringz();
  tf_data.calltf    = &hello_calltf;
  tf_data.compiletf = &hello_compiletf;
  tf_data.sizetf    = null;
  tf_data.user_data = null;
  vpi_register_systf(&tf_data);
}

int callback_cbNextSimTime(p_cb_data cb) {
  s_vpi_time  now;
  now.type = vpiSimTime;
  vpi_get_time(null, &now);
  long time = now.high;
  time <<= 32;
  time += now.low;

  writefln("callback_cbNextSimTime time=%d", time);

  simulateAllRoots(time.nsec);

  s_cb_data new_cb;
  new_cb.reason = vpiCbReadOnlySynch;
  new_cb.cb_rtn = &callback_cbReadOnlySynch;//next callback address
  new_cb.time = &now;
  new_cb.obj = null;
  new_cb.value = null;
  new_cb.user_data = null;
  vpi_register_cb(&new_cb);
  return 0;
}

int callback_cbReadOnlySynch(p_cb_data cb) {
  s_vpi_time  now;
  now.type = vpiSimTime;
  vpi_get_time(null, &now);
  writefln("callback_cbReadOnlySync time=%d", now.low);

  s_cb_data new_cb;
  new_cb.reason = vpiCbNextSimTime;
  new_cb.cb_rtn = &callback_cbNextSimTime;//next callback address
  new_cb.time = null;
  new_cb.obj = null;
  new_cb.value = null;
  new_cb.user_data = null;
  vpi_register_cb(&new_cb);
  return 0;
}

int callback_cleanup(p_cb_data cb) {
  terminateAllRoots();
  import core.runtime;  
  Runtime.terminate();
  return 0;
}

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

void main(){}

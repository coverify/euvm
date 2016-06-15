//----------------------------------------------------------------------
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
//----------------------------------------------------------------------

import std.stdio;
import esdl.base.core;
import uvm.pkg;

class test: phasing_test
{
  mixin uvm_component_utils!(test);
  shared static int first_time_around;
  public this() {
    import std.stdio;
    writeln("Test Object is being initialized");
    super("", null);
    synchronized {
      uvm_report_info("Test", "Testing correct phase order...");
      predicted_phasing ~= "new";
      predicted_phasing ~= "common/build";
      predicted_phasing ~= "common/connect";
      predicted_phasing ~= "common/end_of_elaboration";
      predicted_phasing ~= "common/start_of_simulation";
      predicted_phasing ~= "common/run";
      predicted_phasing ~= "uvm/pre_reset";
      predicted_phasing ~= "uvm/reset";
      predicted_phasing ~= "uvm/post_reset";
      predicted_phasing ~= "uvm/pre_configure";
      predicted_phasing ~= "uvm/configure";
      predicted_phasing ~= "uvm/post_configure";
      predicted_phasing ~= "uvm/pre_main";
      predicted_phasing ~= "uvm/main";
      // predicted_phasing ~= "uvm/post_main";
      // predicted_phasing ~= "uvm/pre_shutdown";
      predicted_phasing ~= "uvm/shutdown";
      predicted_phasing ~= "uvm/post_shutdown";
      predicted_phasing ~= "common/extract";
      predicted_phasing ~= "common/check";
      predicted_phasing ~= "common/report";
      predicted_phasing ~= "common/final";
      first_time_around = 1;
    }
  }
  public this (string name="anon", uvm_component parent=null) {
    import std.stdio;
    writeln("Test Object is being initialized, " ~ name);
    super(name,parent);
    synchronized {
      uvm_report_info("Test", "Testing correct phase order...");
      predicted_phasing ~= "new";
      predicted_phasing ~= "common/build";
      predicted_phasing ~= "common/connect";
      predicted_phasing ~= "common/end_of_elaboration";
      predicted_phasing ~= "common/start_of_simulation";
      predicted_phasing ~= "common/run";
      predicted_phasing ~= "uvm/pre_reset";
      predicted_phasing ~= "uvm/reset";
      predicted_phasing ~= "uvm/post_reset";
      predicted_phasing ~= "uvm/pre_configure";
      predicted_phasing ~= "uvm/configure";
      predicted_phasing ~= "uvm/post_configure";
      predicted_phasing ~= "uvm/pre_main";
      predicted_phasing ~= "uvm/main";
      // predicted_phasing ~= "uvm/post_main";
      // predicted_phasing ~= "uvm/pre_shutdown";
      predicted_phasing ~= "uvm/shutdown";
      predicted_phasing ~= "uvm/post_shutdown";
      predicted_phasing ~= "common/extract";
      predicted_phasing ~= "common/check";
      predicted_phasing ~= "common/report";
      predicted_phasing ~= "common/final";
      first_time_around = 1;
    }
  }


  //task
  override void main_phase(uvm_phase phase) {
    super.main_phase(phase);
    phase.jump(uvm_shutdown_phase.get());
  }


}


// test base class intended to debug the proper order of phase execution

class phasing_test: uvm_test
{
  static shared string[] predicted_phasing; // ordered list of DOMAIN/PHASE strings to check against
  static shared string[] audited_phasing; // ordered list of DOMAIN/PHASE strings to check against

  public void audit(string item="") {
    if (item != "") {
      synchronized {
	audited_phasing ~= item;
      }
      uvm_report_info("Test", format("- debug: recorded phase %s",item));
    }
  }

  // task
  public void audit_task(uvm_phase phase, string item="") {
    phase.raise_objection(this);
    wait(10);
    audit(item);
    wait(10);
    phase.drop_objection(this);
  }

  static void check_phasing() {
    synchronized {
      long n_phases;
      writeln("");
      writeln("Checking predicted order or phase execution:");
      writeln("  +-----------------------------+-----------------------------+");
      writeln("  | Predicted Phase             | Actual Phase                |");
      writeln("  +-----------------------------+-----------------------------+");
      n_phases = predicted_phasing.length;
      if(audited_phasing.length > n_phases) n_phases = audited_phasing.length;
      for (long i=0; (i < n_phases); i++) {
	string predicted = (i >= predicted_phasing.length) ? "" : predicted_phasing[i];
	string audited = (i >= audited_phasing.length) ? "" : audited_phasing[i];
	if (predicted == audited)
	  writefln("  | %27s | %27s |     match", predicted, audited);
	else
	  writefln("  | %27s | %27s | <<< MISMATCH", predicted, audited);
      }
      writeln("  +-----------------------------+-----------------------------+");
    }
  }

  public this(string name, uvm_component parent) {
    super(name,parent); audit("new");
  }
  override public void build_phase(uvm_phase phase) {
    audit("common/build");
  }
  override public void connect_phase(uvm_phase phase) {
    audit("common/connect");
  }
  override public void end_of_elaboration_phase(uvm_phase phase) {
    audit("common/end_of_elaboration");
  }
  override public void start_of_simulation_phase(uvm_phase phase) {
    audit("common/start_of_simulation");
  }
  override public void run_phase(uvm_phase phase) {
    audit_task(phase,"common/run");
  }
  override public void pre_reset_phase(uvm_phase phase) {
    audit_task(phase,"uvm/pre_reset");
  }
  override public void reset_phase(uvm_phase phase) {
    audit_task(phase,"uvm/reset");
  }
  override public void post_reset_phase(uvm_phase phase) {
    audit_task(phase,"uvm/post_reset");
  }
  override public void pre_configure_phase(uvm_phase phase) {
    audit_task(phase,"uvm/pre_configure");
  }
  override public void configure_phase(uvm_phase phase) {
    audit_task(phase,"uvm/configure");
  }
  override public void post_configure_phase(uvm_phase phase) {
    audit_task(phase,"uvm/post_configure");
  }
  override public void pre_main_phase(uvm_phase phase) {
    audit_task(phase,"uvm/pre_main");
  }
  override public void main_phase(uvm_phase phase) {
    audit_task(phase,"uvm/main");
  }
  override public void post_main_phase(uvm_phase phase) {
    audit_task(phase,"uvm/post_main");
  }
  override public void pre_shutdown_phase(uvm_phase phase) {
    audit_task(phase,"uvm/pre_shutdown");
  }
  override public void shutdown_phase(uvm_phase phase) {
    audit_task(phase,"uvm/shutdown");
  }
  override public void post_shutdown_phase(uvm_phase phase) {
    audit_task(phase,"uvm/post_shutdown");
  }
  override public void extract_phase(uvm_phase phase) {
    audit("common/extract");
  }
  override public void check_phase(uvm_phase phase) {
    audit("common/check");
  }
  override public void report_phase(uvm_phase phase) {
    audit("common/report");
  }
  override public void final_phase(uvm_phase phase) {
    audit("common/final");
  }
}


class EsdlRoot: uvm_entity
{
  // UvmRoot uvmRoot;

  this(string name, uint seed) {
    super(name, seed);
  }

  override void doConfig() {
    timeUnit = 100.psec;
    timePrecision = 10.psec;
  }


  void initial() {
    lockStage();

    // uvm_component_registry!(test, "test.test").get();

    uvm_top.finish_on_completion = 0;
    run_test("test.test");
    phasing_test.check_phasing();
    auto svr = uvm_top.get_report_server();
    svr.summarize();
    if (svr.get_severity_count(UVM_FATAL) +
	svr.get_severity_count(UVM_ERROR) == 0)
      writeln("** UVM TEST PASSED **\n");
    else
      writeln("!! UVM TEST FAILED !!\n");
  }

  Task!initial _init;

}

void main()
{
  auto theRoot = new EsdlRoot("theRoot", uniform!uint());
  theRoot.elaborate();
  theRoot.simulate(100.nsec);
}

import std.stdio;

import esdl;
import uvm;

class myseq: uvm_sequence!uvm_sequence_item
{
  shared static int start_cnt = 0;
  shared static int end_cnt = 0;
  mixin uvm_object_utils!myseq;
  
  override public void frame() {
      synchronized start_cnt++;
      if (starting_phase !is null) starting_phase.raise_objection(this);
      uvm_info("INBODY", "Starting myseq!!!", UVM_NONE);
      wait(10);
      uvm_info("INBODY", "Ending myseq!!!", UVM_NONE);
      synchronized end_cnt++;
      if (starting_phase !is null) starting_phase.drop_objection(this);
    }

  public this (string name="myseq") {
    super(name);
  }

}

class myseqr: uvm_sequencer!uvm_sequence_item
{
  public this (string name, uvm_component parent) {
    super(name,parent);
  }

  mixin uvm_component_utils!(myseqr);

  override public void main_phase(uvm_phase phase) {
    uvm_info("MAIN","In main!!!", UVM_NONE);
    wait(100);
    uvm_info("MAIN","Exiting main!!!", UVM_NONE);
  }

}


class test: uvm_test
{
  myseqr seqr;

  public this() {
    super("", null);
  }
  
  public this (string name = "my_comp", uvm_component parent = null) {
    super(name, parent);
  }

  mixin uvm_component_utils!(test);

  override public void build_phase(uvm_phase phase) {
    seqr = new myseqr("seqr", this);
    uvm_config_db!(uvm_object_wrapper).set(this, "seqr.configure_phase", "default_sequence", myseq.type_id.get());
    uvm_config_db!(uvm_object_wrapper).set(this, "seqr.main_phase", "default_sequence", myseq.type_id.get());
  }

  override public void report_phase(uvm_phase phase) {
    synchronized {
      if(myseq.start_cnt != 2 && myseq.end_cnt != 2)
	writeln("*** UVM TEST FAILED ***");
      else
	writeln("*** UVM TEST PASSED ***");
    }
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
    timePrecision = 100.psec;
  }

  void initial() {
    lockStage();
    auto top = uvm_top();

    // uvm_component_registry!(test, "test.test").get();


    uvm_top.finish_on_completion = false;
    uvm_info("Test", "Phasing one component through default phases...", UVM_NONE);
    run_test("test.test");
  }

  Task!initial _init;

}

void main()
{
  auto theRoot = new EsdlRoot("theRoot", uniform!uint());
  theRoot.elaborate();
  theRoot.simulate();
}

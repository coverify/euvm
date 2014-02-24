import std.stdio;
import esdl.base.core;
import esdl.data.sync;
import uvm.base.uvm_root;
import uvm.comps.uvm_env;
import uvm.comps.uvm_driver;
import uvm.comps.uvm_test;
import uvm.base.uvm_component;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_comparer;
import uvm.base.uvm_phase;
import uvm.base.uvm_domain;
import uvm.base.uvm_message_defines;
import uvm.base.uvm_registry;
import uvm.base.uvm_runtime_phases;
import uvm.base.uvm_common_phases;
import uvm.base.uvm_config_db;
import uvm.seq.uvm_sequence;
import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequencer;

enum bus_op_t: ubyte {BUS_READ, BUS_WRITE};
enum status_t: ubyte {STATUS_OK, STATUS_NOT_OK};

enum int NUM_SEQS=10;
enum int NUM_LOOPS=10;

//--------------------------------------------------------------------
// bus_trans
//--------------------------------------------------------------------
@UVM_DEFAULT
class bus_trans: uvm_sequence_item
{

  bvec!12 addr;
  bvec!8 data;
  bus_op_t op;

  mixin uvm_object_utils!bus_trans;

  override void do_copy (uvm_object rhs) {
    auto rhs_ = cast(bus_trans) rhs;

    if(rhs_ is null) 
      uvm_error("do_copy", "cast failed, check type compatability");

    super.do_copy(rhs);
    uvm_field_auto_copy(this, rhs_);

    // this.addr = rhs_.addr;
    // this.data = rhs_.data;
    // this.op = rhs_.op;
  }

  override bool do_compare(uvm_object rhs,uvm_comparer comparer) {
    bus_trans rhs_ = cast(bus_trans) rhs;

    if(rhs_ is null) 
      uvm_fatal("do_compare", "cast failed, check type compatability");

    return ((op == rhs_.op) && (addr == rhs_.addr) && (data == rhs_.data));
  }

  override string convert2string() {
    import std.string: format;
    return format("op %s: addr=%03x, data=%02x", op, addr, data);
  }
		
  // NOTE: in contrast to the USE_FIELD_MACROS version this doesnt implement pack/unpack/print/record/...


  this(string name="") {
    super(name);
  }
};

//--------------------------------------------------------------------
// bus_req
//--------------------------------------------------------------------

class bus_req: bus_trans
{
  mixin uvm_object_utils!(bus_req);
  this (string name="") {
    super(name);
  }
}

//--------------------------------------------------------------------
// bus_rsp
//--------------------------------------------------------------------
class bus_rsp: bus_trans
{

  status_t status;
  
  this(string name="") {
    super(name);
  }

  mixin uvm_object_utils!(bus_rsp);

  override void do_copy (uvm_object rhs) {
    auto rhs_ = cast(bus_rsp) rhs;
    if(rhs_ is null) 
      uvm_fatal("do_copy", "cast failed, check type compatability");

    super.do_copy(rhs_);
    status = rhs_.status;
  }

  override string convert2string() {
    import std.string: format;
    return format("op %s, status=%s", super.convert2string(), status);
  }
		
  // NOTE: in contrast to the USE_FIELD_MACROS version this doesnt implement pack/unpack/print/record/...		
}

class my_driver(REQ, RSP): uvm_driver!(REQ, RSP)
{

  mixin uvm_component_utils!(my_driver!(REQ,RSP));

  private int data_array[512];

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  // task
  override void run_phase(uvm_phase phase) {
    while(true) {
      assert(seq_item_port !is null);
      seq_item_port.get(req);
      auto rsp = new RSP();
      rsp.set_id_info(req);

      // Actually do the read or write here
      if (req.op == bus_op_t.BUS_READ) {
	rsp.addr = req.addr[0..9];
	rsp.data = cast(bvec!8) data_array[rsp.addr].toBitVec;
	uvm_info("sending",rsp.convert2string,UVM_MEDIUM);
      }
      else {
	data_array[req.addr[0..9]] = req.data;
	uvm_info("sending",req.convert2string(),UVM_MEDIUM);
      }
      seq_item_port.put(rsp);
    }
  }
};

class sequenceA(REQ, RSP): uvm_sequence!(REQ, RSP)
{

  mixin uvm_object_utils!(sequenceA!(REQ,RSP));

  private shared static int g_my_id = 1;
  private int my_id;

  this(string name="") {
    super(name);
    synchronized(typeid(sequenceA!(REQ, RSP))) {
      my_id = g_my_id++;
    }
  }

  // task
  override void frame() {
    REQ  req;
    RSP  rsp;

    this.uvm_info("sequenceA", "Starting sequence", UVM_MEDIUM);

    for(uint i = 0; i < NUM_LOOPS; i++) {
      uvm_create(req);

      req.addr = cast(bvec!12) ((my_id * NUM_LOOPS) + i).toBitVec;
      req.data = cast(bvec!8) (my_id + i + 55).toBitVec;
      req.op   = bus_op_t.BUS_WRITE;

      REQ cloned = cast(REQ) req.clone;
      
      uvm_send(cloned);
      get_response(rsp);

      uvm_create(req);
      req.addr = cast(bvec!12) ((my_id * NUM_LOOPS) + i).toBitVec;

      req.data = 0;
      req.op   = bus_op_t.BUS_READ;

      uvm_send(req);
      get_response(rsp);

      if (rsp.data != (my_id + i + 55)) {
	uvm_error("SequenceA",
		  format("Error, addr: %0d, expected data: %0d, actual data: %0d",
			 req.addr, req.data, rsp.data));
      }
    }
    this.uvm_info("sequenceA", "Finishing sequence", UVM_MEDIUM);
  } // frame

}


class env: uvm_env
{
  mixin uvm_component_utils!env;
  private uvm_sequencer!(bus_req, bus_rsp) sqr;
  private my_driver!(bus_req, bus_rsp) drv ;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  override void build_phase(uvm_phase phase) {
    super.build_phase(phase);
    sqr = new uvm_sequencer!(bus_req, bus_rsp)("sequence_controller", this);

    // create and connect driver
    drv = new my_driver!(bus_req, bus_rsp)("my_driver", this);
    drv.seq_item_port.connect(sqr.seq_item_export);
  }

  // task
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    for (int i = 0; i < NUM_SEQS; i++) {
      fork({
    	  auto the_sequence = new sequenceA!(bus_req, bus_rsp)("sequence");
    	  the_sequence.start(sqr, null);
    	});
    }

    waitForks();
    phase.drop_objection(this);
  }

};

class EsdlRoot: uvm_root_entity
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
    //    lockStage();
    auto top = uvm_top();

    uvm_info("top","In top initial block", UVM_MEDIUM);
    auto e = new env("env", null);
    run_test();

  }

  Task!initial _init;

}

void main()
{
  auto theRoot = new EsdlRoot("theRoot", uniform!uint());
  theRoot.elaborate();
  theRoot.simulate();
}

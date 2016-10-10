import esdl;
import uvm;
import std.stdio;

class sha3_seq_item: uvm_sequence_item
{
  mixin uvm_object_utils;
  this(string name="") {
    super(name);
  }

  @UVM_DEFAULT {
    @rand!1024 ubyte[] phrase;
  }
}

class sha3_sequence: uvm_sequence!sha3_seq_item
{
  mixin uvm_object_utils;
  sha3_sequencer sequencer;

  this(string name = "sha3_sequence") {
    super(name);
    req = REQ.type_id.create("req");
  }

  override void frame() {
    for (size_t i=0; i!=1; ++i) {
      req.randomize();
      REQ tr = cast(REQ) req.clone;
      tr.print();
      start_item(tr);
      finish_item(tr);
    }
  }
}

class sha3_sequencer:  uvm_sequencer!sha3_seq_item
{
  mixin uvm_component_utils;
  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class sha3_agent: uvm_agent
{
  mixin uvm_component_utils;

  @UVM_BUILD {
    sha3_sequencer  sequencer;
  }

  this(string name, uvm_component parent) {
    super(name, parent);
  }
}

class axi_seq_item(int DW, int AW): uvm_sequence_item
{
  mixin uvm_object_utils;
  
  this(string name="") {
    super(name);
  }
  
  enum BW = DW/8;

  @UVM_DEFAULT {
    @rand UBit!AW addr;
    @rand Bit!DW  data;
    @UVM_BIN			// print in binary format
      @rand UBit!BW wstrb;
    @UVM_BIN			// print in binary format
      Bit!2         resp;
  }

  Constraint! q{
    (addr>>2) < 4;
    addr % BW == 0;
  } addrCst;

  override void do_vpi_put(uvm_vpi_iter iter) {
    iter.put_values(addr, wstrb, data);
  }

  override void do_vpi_get(uvm_vpi_iter iter) {
    iter.get_values(addr, wstrb, data, resp);
  }
};

class sha3_axi_sequence(int DW, int AW): uvm_sequence!(axi_seq_item!(DW, AW))
{
  mixin uvm_object_utils;
  axi_sequencer!(DW,AW) sequencer;
  sha3_seq_item sha3_item;

  this(string name = "axi_sequence") {
    super(name);
  }

  override void frame() {
    // reset
    req = REQ.type_id.create("req");
    req.addr = toBit!12;
    req.wstrb = toBit!(0xF);
    start_item(req);
    finish_item(req);
    // phrase
    sequencer.sha3_get_port.get(sha3_item);
    sha3_item.print();
    auto data = sha3_item.phrase;
    size_t n;
    for (size_t i=0; i!=data.length/4; ++i) {
      n = 4*i;
      req = REQ.type_id.create("req");
      uint word;
      for (size_t j=0; j!=4; ++j) {
	word += (cast(uint) data[n+j]) << ((3-j) * 8);
      }
      req.data = word;
      req.addr = 0;
      req.wstrb = toBit!0xF;
      req.print();
      start_item(req);
      finish_item(req);
    }
    // last byte_num
    auto m = data.length % 4;
    req = REQ.type_id.create("req");
    req.data = cast(uint) m;
    req.addr = toBit!4;
    req.wstrb = toBit!0xF;
    req.print();
    start_item(req);
    finish_item(req);
    // last
    req = REQ.type_id.create("req");
    uint word;
    for (size_t j=0; j!=m; ++j) {
      word += (cast(uint) data[n+j]) << ((m-1-j) * 8);
    }
    req.data = word;
    req.addr = 0;
    req.wstrb = toBit!0xF;
    req.print();
    start_item(req);
    finish_item(req);
  }
}

class axi_sequence(int DW, int AW): uvm_sequence!(axi_seq_item!(DW, AW))
{
  mixin uvm_object_utils;
  axi_sequencer!(DW,AW) sequencer;
  sha3_seq_item sha3_item;

  this(string name = "axi_sequence") {
    super(name);
    req = REQ.type_id.create("req");
  }

  override void frame() {
    for (size_t i=0; i!=16; i++) {
      req.addr = toBit!0;
      REQ tr = cast(REQ) req.clone;
      start_item(tr);
      finish_item(tr);
    }
  }
}

class axi_sequencer(int DW, int AW):  uvm_sequencer!(axi_seq_item!(DW, AW))
{
  mixin uvm_component_utils;
  @UVM_BUILD {
    uvm_seq_item_pull_port!sha3_seq_item sha3_get_port;
  }

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class axi_driver(int DW, int AW, string vpi_func):
  uvm_vpi_driver!(axi_seq_item!(DW, AW), vpi_func)
{
  enum BW = DW/8;
    
  alias REQ=axi_seq_item!(DW, AW);
  
  mixin uvm_component_utils;
  
  REQ tr;

  @UVM_BUILD
    uvm_analysis_port!REQ req_analysis_port;

  this(string name, uvm_component parent) {
    super(name,parent);
  }
  
  override void run_phase(uvm_phase phase) {
    uvm_info ("INFO" , "Called my_driver::run_phase", UVM_NONE);
    super.run_phase(phase);
    get_and_drive(phase);
  }
	    
  void get_and_drive(uvm_phase phase) {
    while(true) {
      
      seq_item_port.get_next_item(req);
      req.print;
      drive_vpi_port.put(req);
      item_done_event.wait();
      seq_item_port.item_done();
      //req_analysis_port.write(req);
    }
  }
}

class axi_scoreboard(int DW, int AW): uvm_scoreboard
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    synchronized(this) {
      super(name, parent);
    }
  }

  uint [1024] axi_arr;
  @UVM_BUILD {
    uvm_analysis_imp!(write_wr) req_analysis;
    uvm_analysis_imp!(write_rd) rsp_analysis;
  }
  
  void write_wr(axi_seq_item!(DW, AW) req) {
    req.print();
    synchronized(this) {
      uint be_mask = 0;
      for(int i=0; i!=4; i++) {
	if(req.wstrb[i] == 1) {
	  be_mask |= 0x000000FF << i*8;
	}
      }
	uint mem_read = axi_arr[req.addr]  & (~be_mask);
	req.data = req.data & be_mask;
	axi_arr[req.addr] = mem_read | req.data;
	uvm_info("WRTREQ" , format("Transaction Write %x @ %x mask %b",
				   req.data, req.addr, req.wstrb), UVM_NONE);
    }
  }
  
  void write_rd(axi_seq_item!(DW, AW) rsp) {
    rsp.print();
    synchronized(this) {
	uint axi_read = axi_arr[rsp.addr];
	if(axi_read == rsp.data) {
	  uvm_info ("MATCH" , format("Transaction Matched %x != %x @%s",
				     axi_read, rsp.data, rsp.addr), UVM_NONE);
	}
	else {
	  uvm_info("UNMTCH" , format("Transaction Unmatched %x != %x @ %x",
				     axi_read, rsp.data, rsp.addr /*, rsp.wstrb)*/ ), UVM_NONE);
	}
    }
  }
}

class axi_env(int DW, int AW): uvm_env
{
  mixin uvm_component_utils;
  @UVM_BUILD {
    axi_agent!(DW, AW, "axiread","$put_axiread_rsp") rd_agent;
    axi_agent!(DW, AW, "axiwrite","$put_axiwrite_rsp") wr_agent;
    sha3_agent phrase_agent;
    axi_scoreboard!(DW, AW) scoreboard;
    // axi_monitor!(DW, AW, "$put_axiwrite_rsp") wr_monitor;
    // axi_monitor!(DW,AW,"$put_axiwrite_rsp") rd_monitor;
  }

  this(string name , uvm_component parent) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    super.connect_phase(phase);
    wr_agent.monitor.rsp_port.connect(scoreboard.req_analysis);
    rd_agent.monitor.rsp_port.connect(scoreboard.rsp_analysis);
    wr_agent.sequencer.sha3_get_port.connect(phrase_agent.sequencer.seq_item_export);
  }
}
      
class axi_agent(int DW, int AW, string DRI_VPI, string MON_VPI): uvm_agent
{
  mixin uvm_component_utils;

  @UVM_BUILD {
    axi_driver!(DW, AW, DRI_VPI)     driver;
    axi_sequencer!(DW, AW)  sequencer;
    axi_monitor!(DW, AW, MON_VPI)    monitor;
  }

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    super.connect_phase(phase);
    if(get_is_active() == UVM_ACTIVE) {
      driver.seq_item_port.connect(sequencer.seq_item_export);
    }
  }
}

class axi_monitor(int DW, int AW, string vpi_func):
  uvm_vpi_monitor!(axi_seq_item!(DW, AW), vpi_func)
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }
}

class random_test_parameterized(int DW, int AW): uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD {
    axi_env!(DW, AW) env;
  }

  override void run_phase(uvm_phase  phase) {
    sha3_sequence sha3_seq;
    sha3_axi_sequence!(DW, AW) wr_seq;
    axi_sequence!(DW, AW) rd_seq;
    phase.raise_objection(this, "axi_test");
    phase.get_objection.set_drain_time(this, 20.nsec);
    fork ({
	sha3_seq = sha3_sequence.type_id.create("sha3_seq");
	sha3_seq.sequencer = env.phrase_agent.sequencer;
	sha3_seq.randomize();
	sha3_seq.start(env.phrase_agent.sequencer);
      },
      {
	wr_seq = sha3_axi_sequence!(DW, AW).type_id.create("wr_seq");
	wr_seq.sequencer = env.wr_agent.sequencer;
	assert(wr_seq.sequencer !is null);
	wr_seq.randomize();
	wr_seq.start(env.wr_agent.sequencer);
      }).join();
    rd_seq = axi_sequence!(DW, AW).type_id.create("rd_seq");
    rd_seq.sequencer= env.rd_agent.sequencer;
    rd_seq.randomize();
    rd_seq.start(env.rd_agent.sequencer);

    phase.drop_objection(this, "axi_test");
  }
}

class random_test: random_test_parameterized!(32, 4)
{
  mixin uvm_component_utils;
  this(string name, uvm_component parent) {
    super(name, parent);
  }
}

class directed_test_parameterized(int DW, int AW): uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD {
    axi_env!(DW, AW) env;
  }

  override void run_phase(uvm_phase  phase) {
    axi_sequence!(DW, AW) wr_seq, rd_seq;
    phase.raise_objection(this, "axi_test");
    phase.get_objection.set_drain_time(this, 20.nsec);
    fork ({
	wr_seq = axi_sequence!(DW, AW).type_id.create("wr_seq");
	wr_seq.sequencer= env.wr_agent.sequencer;
	wr_seq.randomize();
	wr_seq.start(env.wr_agent.sequencer);
      },
      {
	rd_seq = axi_sequence!(DW, AW).type_id.create("rd_seq");
	rd_seq.sequencer= env.rd_agent.sequencer;
	rd_seq.randomize();
	rd_seq.start(env.rd_agent.sequencer);
      }).join();
    phase.drop_objection(this, "axi_test");
  }
}

class directed_test: directed_test_parameterized!(32, 4)
{
  mixin uvm_component_utils;
  this(string name, uvm_component parent) {
    super(name, parent);
  }
}

class my_root: uvm_root
{
  mixin uvm_component_utils;

  override void initial() {
    set_timeout(0.nsec, false);
    run_test();
  }
}

class TestBench: uvm_testbench
{
  uvm_entity!(my_root) tb;
}

void initializeESDL() {
  Vpi.initialize();

  TestBench test = new TestBench;
  test.multiCore(0, 0);
  test.elaborate("test");
  test.tb.set_seed(100);
  test.setVpiMode();

  test.start_bg();
}

alias funcType = void function();
shared extern(C) funcType[2] vlog_startup_routines = [&initializeESDL, null];

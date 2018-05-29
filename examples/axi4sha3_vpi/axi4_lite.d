import esdl;
import uvm;
import std.stdio;

extern(C) ubyte* sponge(ubyte*, uint);

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

  string phrase;

  void set_phrase(string ph) {
    phrase = ph;
  }
  
  this(string name = "sha3_sequence") {
    super(name);
  }

  override void frame() {
    req = REQ.type_id.create("req");
    for (size_t i=0; i!=1; ++i) {
      if (phrase == "") {
	req.randomize();
      }
      else {
	req.phrase = cast(ubyte[]) phrase;
      }
      REQ tr = cast(REQ) req.clone;
      // tr.print();
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

  // sequence
  // no data -- addr 12
  // loop on data (except last word) -- addr 0
  // number of remaining bytes as data -- addr 4
  // remaining data addr 0
  override void frame() {
    sequencer.sha3_get_port.get(sha3_item);
    // sha3_item.print();
    // reset
    req = REQ.type_id.create("req");
    req.addr = toBit!12;
    req.wstrb = toBit!(0xF);
    start_item(req);
    finish_item(req);
    // phrase
    auto data = sha3_item.phrase;
    for (size_t i=0; i!=data.length/4; ++i) {
      auto data_req = REQ.type_id.create("req");
      uint word = 0;
      for (size_t j=0; j!=4; ++j) {
	word += (cast(uint) data[4*i+j]) << ((3-j) * 8);
      }
      data_req.data = word;
      data_req.addr = 0;
      data_req.wstrb = toBit!0xF;
      // data_req.print();
      start_item(data_req);
      finish_item(data_req);
    }
    // last byte_num
    auto m = data.length % 4;
    req = REQ.type_id.create("req");
    req.data = cast(uint) m;
    req.addr = toBit!4;
    req.wstrb = toBit!0xF;
    // req.print();
    start_item(req);
    finish_item(req);
    // last
    req = REQ.type_id.create("req");
    uint word = 0;
    for (size_t j=0; j!=m; ++j) {
      word += (cast(uint) data[data.length/4 + j]) << ((3-j) * 8);
    }
    req.data = word;
    req.addr = 0;
    req.wstrb = toBit!0xF;
    // req.print();
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

class axi_driver(int DW, int AW, string vpi_func): uvm_vpi_driver!(axi_seq_item!(DW, AW), vpi_func)
{
  enum BW = DW/8;
    
  alias REQ=axi_seq_item!(DW, AW);
  
  mixin uvm_component_utils;
  
  REQ tr;

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
      // req.print;
      drive_vpi_port.put(req);
      item_done_event.wait();
      seq_item_port.item_done();
    }
  }
}

class sha3_req_monitor(int DW, int AW): uvm_monitor
{
  sha3_seq_item sha3_item;
  bool last_word;		// next word is last_word
  int byte_num;			// number of bytes in the last word
  
  @UVM_BUILD {
    uvm_analysis_imp!(write) axi_analysis;
    uvm_analysis_port!sha3_seq_item sha3_port;
  }

  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name,parent);
  }
  
  void write(axi_seq_item!(DW, AW) req) {
    if (sha3_item is null) {
      sha3_item = new sha3_seq_item("monitored sha3 req");
    }
    if (req.addr == 0x0C) {	// reset
      sha3_item.phrase.length = 0;
      last_word = false;
      byte_num = 0;
    }
    else if (req.addr == 0x04) {	// reset
      last_word = true;
      byte_num = req.data;
    }
    else {
      int n = 4;
      if (last_word) n = byte_num;
      for (size_t i=0; i!=n; ++i) {
	sha3_item.phrase ~= cast(ubyte) (req.data >> ((3-i)*8));
      }
      if (last_word) {
	last_word = false;
	// sha3_item.print;
	sha3_port.write(sha3_item);
	sha3_item = null;
      }
    }
  }
}

class sha3_rsp_monitor(int DW, int AW): uvm_monitor
{
  sha3_seq_item sha3_item;
  bool last_word;		// next word is last_word
  int counter;			// number of bytes in the last word
  
  @UVM_BUILD {
    uvm_analysis_imp!(write) axi_analysis;
    uvm_analysis_port!sha3_seq_item sha3_port;
  }

  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name,parent);
  }
  
  void write(axi_seq_item!(DW, AW) rsp) {
    if (sha3_item is null) {
      sha3_item = new sha3_seq_item("monitored sha3 rsp");
      counter = 0;
    }
    for (size_t i=0; i!=4; ++i) {
      sha3_item.phrase ~= cast(ubyte) (rsp.data >> ((3-i)*8));
    }
    counter++;
    if (counter == 16) {
      counter = 0;
      // sha3_item.print();
      sha3_port.write(sha3_item);
      sha3_item = null;
    }
  }
}

class axi_scoreboard(int DW, int AW): uvm_scoreboard
{
  mixin uvm_component_utils;

  sha3_seq_item prev_req;

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
  
  void write_wr(sha3_seq_item req) {
    prev_req = req;
    // req.print();

  }
  
  void write_rd(sha3_seq_item rsp) {
    // rsp.print();
    auto expected = sponge(prev_req.phrase.ptr,
			   cast(uint) prev_req.phrase.length);

    if (expected[0..64] == rsp.phrase) {
      uvm_info("MATCHED", "Scoreboard received expected response", UVM_NONE);
    }
    else {
      prev_req.print();
      uvm_error("MISMATCHED", format("%s: expected \n %s: actual",
				     expected[0..64], rsp.phrase));
    }
  }
}

class axi_env(int DW, int AW): uvm_env
{
  mixin uvm_component_utils;
  @UVM_BUILD {
    axi_agent!(DW, AW, "axiread","axiread") rd_agent;
    axi_agent!(DW, AW, "axiwrite","axiwrite") wr_agent;
    sha3_agent phrase_agent;
    axi_scoreboard!(DW, AW) scoreboard;
    sha3_req_monitor!(DW, AW) req_monitor;
    sha3_rsp_monitor!(DW, AW) rsp_monitor;
  }

  this(string name , uvm_component parent) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    super.connect_phase(phase);
    // wr_agent.monitor.rsp_port.connect(scoreboard.req_analysis);
    // rd_agent.monitor.rsp_port.connect(scoreboard.rsp_analysis);
    req_monitor.sha3_port.connect(scoreboard.req_analysis);
    rsp_monitor.sha3_port.connect(scoreboard.rsp_analysis);
    wr_agent.monitor.rsp_port.connect(req_monitor.axi_analysis);
    rd_agent.monitor.rsp_port.connect(rsp_monitor.axi_analysis);
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

class axi_monitor(int DW, int AW, string vpi_func): uvm_vpi_monitor!(axi_seq_item!(DW, AW), vpi_func)
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
    sha3_seq = sha3_sequence.type_id.create("sha3_seq");
    for (size_t i=0; i!=50; ++i) {
      fork ({
	  sha3_seq.sequencer = env.phrase_agent.sequencer;
	  // sha3_seq.set_phrase("The quick brown fox jumps over the lazy dog");
	  // sha3_seq.randomize();
	  sha3_seq.start(env.phrase_agent.sequencer);
	},
	{
	  wr_seq = sha3_axi_sequence!(DW, AW).type_id.create("wr_seq");
	  wr_seq.sequencer = env.wr_agent.sequencer;
	  assert(wr_seq.sequencer !is null);
	  // wr_seq.randomize();
	  wr_seq.start(env.wr_agent.sequencer);
	}).join();
      rd_seq = axi_sequence!(DW, AW).type_id.create("rd_seq");
      rd_seq.sequencer= env.rd_agent.sequencer;
      // rd_seq.randomize();
      rd_seq.start(env.rd_agent.sequencer);
    }
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
  test.multicore(0, 4);
  test.elaborate("test");
  test.tb.set_seed(100);
  test.setVpiMode();

  test.start_bg();
}

alias funcType = void function();
shared extern(C) funcType[2] vlog_startup_routines = [&initializeESDL, null];

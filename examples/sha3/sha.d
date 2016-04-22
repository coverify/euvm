import esdl;
import uvm;
import std.stdio;
import esdl.intf.vpi;
import std.string: format;

extern(C) ubyte* sponge(ubyte*, uint);

@UVM_DEFAULT
class sha_st: uvm_sequence_item
{
  @rand ubyte data;
  bool start;
  bool end;
  bool reset;

  mixin uvm_object_utils;
   
  this(string name = "sha_st") {
    super(name);
  }

  Constraint! q{
    data >= 0x30;
    data <= 0x7a;
  } cst_ascii;

  // override public string convert2string() {
  //   if(kind == kind_e.WRITE)
  //     return format("kind=%s addr=%x wdata=%x",
  // 		    kind, addr, wdata);
  //   else
  //     return format("kind=%s addr=%x rdata=%x",
  // 		    kind, addr, rdata);
  // }

  // void postRandomize() {
  //   // writeln("post_randomize: ", this.convert2string);
  // }
}

@UVM_DEFAULT
class sha_phrase_seq: uvm_sequence!sha_st
{
  ubyte[] phrase;

  mixin uvm_object_utils;

  sha_st reset;
  sha_st req;
  sha_st end;

  this(string name="") {
    super(name);
  }

  void set_phrase(string phrase) {
    reset = sha_st.type_id.create(get_name() ~ ".reset");
    reset.reset = true;
    req = sha_st.type_id.create(get_name() ~ ".req");
    end = sha_st.type_id.create(get_name() ~ ".end");
    end.end = true;
    this.phrase = cast(ubyte[]) phrase;
  }

  bool is_finalized() {
    return (end !is null);
  }

  void opOpAssign(string op)(sha_st item) if(op == "~")
    {
      assert(item !is null);
      assert((end is null), "Adding items to a finalized sha_phrase_seq is illegal");

      if (item.start is true) {
	assert(phrase.length == 0 && reset is null);
	reset = sha_st.type_id.create(get_name() ~ ".reset");
	reset.reset = true;
      }

      if (item.end is true) {
	end = sha_st.type_id.create(get_name() ~ ".end");
	end.end = true;
      }
      else {
	phrase ~= item.data;
      }
    }
  // task
  override void frame() {
    // uvm_info("sha_st_seq", "Starting sequence", UVM_MEDIUM);

    // atomic sequence
    // uvm_create(req);

    wait_for_grant();
    
    send_request(reset);

    for (size_t i=0; i!=phrase.length; ++i) {
      wait_for_grant();
      if(i == 0) {req.start = true;}
      else {req.start = false;}
      req.data = cast(ubyte) phrase[i];
      req.end = false;
      sha_st cloned = cast(sha_st) req.clone;
      send_request(cloned);
    }
    
    wait_for_grant();
    
    send_request(end);

    // uvm_info("sha_st", "Finishing sequence", UVM_MEDIUM);
  } // frame

}

@UVM_DEFAULT
class sha_st_seq: uvm_sequence!sha_st
{
  sha_st reset;
  sha_st req;
  sha_st end;
  mixin uvm_object_utils;

  @rand uint seq_size;

  this(string name="") {
    super(name);
    reset = sha_st.type_id.create(name ~ ".reset");
    req = sha_st.type_id.create(name ~ ".req");
    end = sha_st.type_id.create(name ~ ".end");
    reset.reset = true;
    end.end = true;
  }

  Constraint!q{
    seq_size < 64;
    seq_size > 16;
  } seq_size_cst;

  // task
  override void frame() {
    // uvm_info("sha_st_seq", "Starting sequence", UVM_MEDIUM);

    // atomic sequence
    // uvm_create(req);

    wait_for_grant();
    
    send_request(reset);

    for (size_t i=0; i!=seq_size; ++i) {
      wait_for_grant();
      req.randomize();
      if(i == 0) {req.start = true;}
      else {req.start = false;}
      // if(i == seq_size - 1) {req.end = true;}
      req.end = false;
      sha_st cloned = cast(sha_st) req.clone;
      send_request(cloned);
    }
    
    wait_for_grant();
    
    send_request(end);

    // uvm_info("sha_st", "Finishing sequence", UVM_MEDIUM);
  } // frame

}

class sha_st_driver_cbs: uvm_callback
{
  void trans_received (sha_st_driver xactor , sha_st cycle) {}
  void trans_executed (sha_st_driver xactor , sha_st cycle) {}
}

class sha_st_driver: uvm_driver!sha_st
{

  mixin uvm_component_utils;
  
  uvm_put_port!sha_st req_egress;
  uvm_analysis_port!sha_st req_analysis;
  
  /* override void build_phase(uvm_phase phase) { */
  /*   // req_egress = new uvm_put_port!sha_st("req_egress", this); */
  /*   // req_fifo = new uvm_tlm_fifo_egress!sha_st("req_fifo", this, 0); */
  /*   // ingress = new uvm_get_port!sha_st("ingress", this); */
  /* } */

  Event trig;
  // sha_st_vif sigs;
  // sha_st_config cfg;

  this(string name, uvm_component parent = null) {
    super(name,parent);
  }


  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);

    while(true) {
      sha_st req;

      
      seq_item_port.get_next_item(req);

      this.trans_received(req);

      version(NODESIGN) {
	// req.print();
      }
      else {
	req_egress.put(req);
      }
      
      req_analysis.write(req);
      
      this.trans_executed(req);

      seq_item_port.item_done();
      
    }
  }

  override void final_phase(uvm_phase phase) {
    req_egress.put(null);
  }

  protected void trans_received(sha_st tr) {}
    
 
  protected void trans_executed(sha_st tr) {}

}

class sha_scoreboard: uvm_scoreboard
{
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  mixin uvm_component_utils;

  uvm_phase phase_run;

  uint matched;

  sha_phrase_seq[] req_queue;
  sha_phrase_seq[] rsp_queue;

  uvm_analysis_imp!(sha_scoreboard, write_req) req_analysis;
  uvm_analysis_imp!(sha_scoreboard, write_rsp) rsp_analysis;

  override void run_phase(uvm_phase phase) {
    phase_run = phase;
    uvm_wait_for_ever();
  }

  void write_req(sha_phrase_seq seq) {
    synchronized(this) {
      // seq.print();
      /* import std.stdio; */
      /* stderr.writeln("Given:", seq.phrase); */
      /* auto expected = sponge(seq.phrase.ptr, */
      /* 			     cast(uint) seq.phrase.length); */
      /* stderr.writeln("Done: "); */
      /* stderr.writeln("Ecpected: ", expected[0..64]); */
      
      req_queue ~= seq;
      assert(phase_run !is null);
      phase_run.raise_objection(this);
      // writeln("Received request: ", matched + 1);
    }
  }

  void write_rsp(sha_phrase_seq seq) {
    synchronized(this) {
      // seq.print();
      rsp_queue ~= seq;
      auto expected = sponge(req_queue[matched].phrase.ptr,
			     cast(uint) req_queue[matched].phrase.length);
      ++matched;
      import std.stdio;
      // writeln("Ecpected: ", expected[0..64]);
      if (expected[0..64] == seq.phrase) {
	uvm_info("MATCHED",
		 format("Scoreboard received expected response #%d", matched),
		 UVM_NONE);
      }
      else {
	uvm_error("MISMATCHED", "Scoreboard received unmatched response");
      }
      
      assert(phase_run !is null);
      phase_run.drop_objection(this);
    }
  }

}

class sha_st_monitor: uvm_monitor
{

  mixin uvm_component_utils;
  
  uvm_analysis_imp!(sha_st, sha_st_monitor) ingress;
  uvm_analysis_port!sha_phrase_seq egress;


  this(string name, uvm_component parent = null) {
    super(name, parent);
    
  }

  sha_phrase_seq seq;

  void write(sha_st item) {
    if (seq is null) {
      seq = new sha_phrase_seq();
    }

    if (item.reset) { // valid will be low
      // do nothing
    }
    else {
      seq ~= item;
    }

    if (seq.is_finalized()) {
      egress.write(seq);
      seq = null;
    }
  }
  
}


class sha_st_sequencer: uvm_sequencer!sha_st
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class sha_st_agent: uvm_agent
{

  sha_st_sequencer sequencer;
  sha_st_driver    driver;

  sha_st_monitor   req_monitor;
  sha_st_monitor   rsp_monitor;

  sha_scoreboard   scoreboard;
  
  mixin uvm_component_utils;
   
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    driver.seq_item_port.connect(sequencer.seq_item_export);
    auto root = cast(sha_st_root) get_root();
    assert(root !is null);
    driver.req_analysis.connect(req_monitor.ingress);
    root.rsp_anaylsis.connect(rsp_monitor.ingress);
    driver.req_egress.connect(root.req_fifo.put_export);
    // scoreboard connections
    req_monitor.egress.connect(scoreboard.req_analysis);
    rsp_monitor.egress.connect(scoreboard.rsp_analysis);
  }
}

class RandomTest: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  sha_st_env env;
  
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    auto rand_sequence = new sha_st_seq("sha_st_seq");

    for (size_t i=0; i!=108; ++i) {
      rand_sequence.randomize();
      auto sequence = cast(sha_st_seq) rand_sequence.clone();
 /*      writeln("Generated ", i, */
 /* " seq with ", sequence.seq_size, " transactions"); */
      sequence.start(env.agent.sequencer, null);
    }
    
    // waitForks();
    
    phase.drop_objection(this);
  }
}

class QuickFoxTest: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  sha_st_env env;
  
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    auto sequence = new sha_phrase_seq("QuickFoxSeq");
    sequence.set_phrase("The quick brown fox jumps over the lazy dog");

    sequence.start(env.agent.sequencer, null);

    // waitForks();
    
    phase.drop_objection(this);
  }
}

class sha_st_env: uvm_env
{
  mixin uvm_component_utils;
  private sha_st_agent agent;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  // task
 /*  override void run_phase(uvm_phase phase) { */
 /*    phase.raise_objection(this); */
 /*    auto rand_sequence = new sha_st_seq("sha_st_seq"); */

 /*    for (size_t i=0; i!=100; ++i) { */
 /*      rand_sequence.randomize(); */
 /*      auto sequence = cast(sha_st_seq) rand_sequence.clone(); */
 /*      writeln("Generated ", i, */
 /* " seq with ", sequence.seq_size, " transactions"); */
 /*      sequence.start(agent.sequencer, null); */
 /*    } */
    
 /*    // waitForks(); */
    
 /*    phase.drop_objection(this); */
 /*  } */
};

version(EDISON) {
  enum DRIVER {
    DATA_0 = 31,
    DATA_1 = 32,
    DATA_2 = 35,
    DATA_3 = 36,
    DATA_4 = 37,
    DATA_5 = 38,
    DATA_6 = 40,
    DATA_7 = 41,
    END    = 21,
    VALID  = 23,
    READY  = 24,
    RESET  = 25,
    CLK    = 26
  }
      
  struct DriverPin {
    import esdl.intf.mraa;
    import core.stdc.stdlib: exit;
    import core.thread: Thread;
    import core.time: dur;
    mraa_gpio_context pin;
    this(DRIVER num) {
      pin = mraa_gpio_init(num);
      if ( pin is null ) {
	stderr.writeln("Error opening pin: ", num);
	exit(1);
      }
      auto r = mraa_gpio_dir(pin, mraa_gpio_dir_t.MRAA_GPIO_OUT);
      if ( r != mraa_result_t.MRAA_SUCCESS ) {
	mraa_result_print(r);
	Thread.sleep(dur!("seconds")(1));
      }
    }
    ~this() {
      auto r = mraa_gpio_close(pin);
      if ( r != mraa_result_t.MRAA_SUCCESS ) {
	mraa_result_print(r);
	Thread.sleep(dur!("seconds")(1));
      }
    }
    void write(bool val) {
      auto r = mraa_gpio_write(pin, val);
      if ( r != MRAA_SUCCESS ) {
	mraa_result_print(r);
      }
    }
  }

  enum SNOOPER {
    DATA_0 = 45,
    DATA_1 = 46,
    DATA_2 = 47,
    DATA_3 = 48,
    DATA_4 = 49,
    DATA_5 = 50,
    DATA_6 = 51,
    DATA_7 = 52,
    END    = 53,		/* 39 */
    VALID  = 54,
    READY  = 55
  }
      
  struct SnooperPin {
    import esdl.intf.mraa;
    import core.stdc.stdlib: exit;
    import core.thread: Thread;
    import core.time: dur;
    import std.conv;

    SNOOPER pinNum;
    mraa_gpio_context pin;
    this(SNOOPER num) {
      pinNum = num;
      pin = mraa_gpio_init(num);
      if ( pin is null ) {
	stderr.writeln("Error opening pin: ", num);
	exit(1);
      }
      auto r = mraa_gpio_dir(pin, mraa_gpio_dir_t.MRAA_GPIO_IN);
      if ( r != mraa_result_t.MRAA_SUCCESS ) {
	mraa_result_print(r);
	Thread.sleep(dur!("seconds")(1));
      }
    }
    ~this() {
      auto r = mraa_gpio_close(pin);
      if ( r != mraa_result_t.MRAA_SUCCESS ) {
	mraa_result_print(r);
	Thread.sleep(dur!("seconds")(1));
      }
    }
    bool read() {
      auto val = mraa_gpio_read(pin);
      if (val == -1) {
	assert(false, "Error reading input: " ~ pinNum.to!string);
      }
      if (val == 0) {
	return false;
      }
      else {
	return true;
      }
    }
  }
}

class sha_st_root: uvm_root
{
  mixin uvm_component_utils;

  // sha_st_env env;

  uvm_tlm_gen_rsp_channel!sha_st rsp_fifo;
  uvm_tlm_fifo_egress!sha_st req_fifo;


  uvm_put_port!sha_st rsp_egress;
  uvm_get_port!sha_st req_ingress;

  uvm_get_port!sha_st rsp_ingress;

  uvm_get_port!sha_st rsp_generator;

  uvm_analysis_port!sha_st rsp_anaylsis;

  override void initial() {
    set_timeout(0.nsec, false);
    run_test();
  }

  override void build_phase(uvm_phase phase) {
    req_fifo = new uvm_tlm_fifo_egress!sha_st("req_fifo", this, 0);
  }
  
  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);
    version(EDISON) {
      import core.thread;
      auto fifoThread = new Thread(&driveGPIO).start();//thread
    }
    
    while(true) {
      sha_st item;
      rsp_ingress.get(item);
      rsp_anaylsis.write(item);
    }
  }
    
  version(EDISON) {
    void driveGPIO() {
      import esdl.intf.mraa;
      import core.stdc.stdlib: exit;
      import core.thread: Thread;
      import core.time: dur;
    
      bool hw_ready;
      bool start_out = true;

      this.set_thread_context();

      /* Create access to GPIO pin */

      mraa_init();

      DriverPin data_in_0 = DriverPin(DRIVER.DATA_0);
      DriverPin data_in_1 = DriverPin(DRIVER.DATA_1);
      DriverPin data_in_2 = DriverPin(DRIVER.DATA_2);
      DriverPin data_in_3 = DriverPin(DRIVER.DATA_3);
      DriverPin data_in_4 = DriverPin(DRIVER.DATA_4);
      DriverPin data_in_5 = DriverPin(DRIVER.DATA_5);
      DriverPin data_in_6 = DriverPin(DRIVER.DATA_6);
      DriverPin data_in_7 = DriverPin(DRIVER.DATA_7);
      DriverPin end_in    = DriverPin(DRIVER.END);
      DriverPin valid_in  = DriverPin(DRIVER.VALID);
      DriverPin ready_out = DriverPin(DRIVER.READY);
      DriverPin reset     = DriverPin(DRIVER.RESET);
      DriverPin clk       = DriverPin(DRIVER.CLK);
    
      SnooperPin data_out_0 = SnooperPin(SNOOPER.DATA_0);
      SnooperPin data_out_1 = SnooperPin(SNOOPER.DATA_1);
      SnooperPin data_out_2 = SnooperPin(SNOOPER.DATA_2);
      SnooperPin data_out_3 = SnooperPin(SNOOPER.DATA_3);
      SnooperPin data_out_4 = SnooperPin(SNOOPER.DATA_4);
      SnooperPin data_out_5 = SnooperPin(SNOOPER.DATA_5);
      SnooperPin data_out_6 = SnooperPin(SNOOPER.DATA_6);
      SnooperPin data_out_7 = SnooperPin(SNOOPER.DATA_7);
      SnooperPin end_out    = SnooperPin(SNOOPER.END);
      SnooperPin valid_out  = SnooperPin(SNOOPER.VALID);
      SnooperPin ready_in   = SnooperPin(SNOOPER.READY);
    
      reset.write(0);
      for (size_t i=0; i!=4; ++i) {
	clk.write(0);
	Thread.sleep(dur!("usecs")(50));
	clk.write(1);
	Thread.sleep(dur!("usecs")(50));
      }
      reset.write(1);
      ready_out.write(1);

      for (size_t i=0; i!=4; ++i) {
	clk.write(0);
	Thread.sleep(dur!("usecs")(50));
	clk.write(1);
	Thread.sleep(dur!("usecs")(50));
      }

      reset.write(0);

      for (size_t i=0; i!=40; ++i) {
	clk.write(0);
	Thread.sleep(dur!("usecs")(50));
	clk.write(1);
	Thread.sleep(dur!("usecs")(50));
      }

      /* Create signal handler so we can exit gracefully */
      // signal(SIGINT, &sig_handler);

      /* Turn LED off and on forever until SIGINT (Ctrl+c) */
      while ( true ) {
	import std.stdio;

	clk.write(0);

	sha_st tx;
	assert(req_ingress !is null);

	if (hw_ready is true) {
	  // auto valid = req_ingress.try_get(tx);
	  req_ingress.get(tx);
	  auto valid = true;

	  
	
	  if(valid && tx !is null) {
	    reset.write(tx.reset);
	  }

	  if(valid && tx !is null && tx.reset is false) {
	    // tx.print();
	    valid_in.write(1);
	    UBit!8 d = tx.data;
	    data_in_0.write(d[0]);
	    data_in_1.write(d[1]);
	    data_in_2.write(d[2]);
	    data_in_3.write(d[3]);
	    data_in_4.write(d[4]);
	    data_in_5.write(d[5]);
	    data_in_6.write(d[6]);
	    data_in_7.write(d[7]);
	    end_in.write(tx.end);
	  } else {
	    valid_in.write(0);
	    data_in_0.write(0);
	    data_in_1.write(0);
	    data_in_2.write(0);
	    data_in_3.write(0);
	    data_in_4.write(0);
	    data_in_5.write(0);
	    data_in_6.write(0);
	    data_in_7.write(0);
	    end_in.write(0);
	  }


	  if(valid && tx is null) {
	    break;
	  }
	}
	else {
	  reset.write(0);
	  valid_in.write(0);
	  data_in_0.write(0);
	  data_in_1.write(0);
	  data_in_2.write(0);
	  data_in_3.write(0);
	  data_in_4.write(0);
	  data_in_5.write(0);
	  data_in_6.write(0);
	  data_in_7.write(0);
	  end_in.write(0);
	}

	Thread.sleep(dur!("usecs")(50));
	clk.write(1);
	Thread.sleep(dur!("usecs")(50));
	hw_ready       = ready_in.read();
	bool out_valid = valid_out.read();
	if (out_valid) {
	  import std.stdio;
	  // stderr.writeln("Receiving output");
	  sha_st rsp;
	  rsp_generator.get(rsp);
	  UBit!8 out_data;
	  out_data[0] = data_out_0.read();
	  out_data[1] = data_out_1.read();
	  out_data[2] = data_out_2.read();
	  out_data[3] = data_out_3.read();
	  out_data[4] = data_out_4.read();
	  out_data[5] = data_out_5.read();
	  out_data[6] = data_out_6.read();
	  out_data[7] = data_out_7.read();
	  bool out_end = end_out.read();

	  rsp.data = out_data;
	  rsp.end = out_end;
	  
	  if(start_out is true) {
	    rsp.start = true;
	    start_out = false;
	  }
	  else {
	    rsp.start = false;
	  }
	  if (rsp.end == true) {
	    start_out = true;
	  }

	  rsp_egress.put(rsp);
	  
	}
	
      }

    }
  }
  

  override void connect_phase(uvm_phase phase) {
    req_ingress.connect(req_fifo.get_export);
    rsp_ingress.connect(rsp_fifo.get_export);
    rsp_egress.connect(rsp_fifo.put_export);
    rsp_generator.connect(rsp_fifo.gen_export);
  }

  
}

class TestBench: RootEntity
{
  uvm_root_entity!(sha_st_root) tb;
}


extern(C) int initEsdl() {
  import core.runtime;  
  import std.random: uniform;
  import std.stdio;
  import esdl.intf.vpi;
  import core.memory;

  Runtime.initialize();

  // GC.disable();
  
  writeln("Configuring ESDL");
  writeln("Product: ", vpiGetProduct());

  assert(vpiIsUsable());

  s_cb_data end_cb;
  end_cb.reason = vpiCbEndOfSimulation;
  end_cb.cb_rtn = &callback_cleanup;//next callback address
  vpi_register_cb(&end_cb);

  TestBench test = new TestBench;
  test.multiCore(0, 0);
  test.elaborate("test");
  test.tb.set_seed(100);

  void* tb = cast(void*) test;

  pull_sha_register(tb);
  resp_sha_register(tb);
  
  s_cb_data elab_cb;
  elab_cb.reason = vpiCbStartOfSimulation;
  elab_cb.cb_rtn = &startESDL;
  elab_cb.user_data = tb;
  vpi_register_cb(&elab_cb);

  return 0;
}

int startESDL(p_cb_data cb) {
  import core.memory: GC;

  TestBench test = cast(TestBench) cb.user_data;

  // GC.addRoot(cast(void*) test);

  test.forkSim();
  auto sha_tb = test.tb.get_root();

  return 0;

}

int callback_cleanup(p_cb_data cb) {
  import core.runtime;
  Runtime.terminate();
  return 0;
}

//pull_sha_compiletf
int pull_sha_compiletf(char* user_data)
{

  auto systf_handle = vpi_handle(vpiSysTfCall, null);
  assert(systf_handle !is null);

  auto arg_iterator = vpi_iterate(vpiArgument, systf_handle);
  assert(arg_iterator !is null);

  for (size_t i=0; i!=6; ++i) {	/* there have to be 4 arguments */
    auto arg_handle = vpi_scan(arg_iterator);
    if((i < 5 && arg_handle is null) || (i == 5 && arg_handle !is null)) {
      writeln("ERROR: $pull_sha requires 5 arguments!");
      writeln("ERROR: ", i, " are provided!!");
      break;
    }
  }
  //}
  return 0;
}

//pull_sha_calltf
int pull_sha_calltf(char* user_data)
{

  TestBench test = cast(TestBench) user_data;
  assert(test !is null);
  
  auto sha_tb = test.tb.get_root();
  assert(sha_tb !is null);

  sha_tb.set_thread_context();
  
  if(test.isTerminated()) {
    import std.stdio;
    stderr.writeln(" > Sending vpiFinish signal to the Verilog Simulator");
    vpi_control(vpiFinish, 1);
  }
  /* else { */
  /*   import std.stdio; */
  /*   writeln(" > hmmmm"); */
  /* } */

  auto systf_handle = vpi_handle(vpiSysTfCall, null);
  assert(systf_handle !is null);


  auto arg_iterator = vpi_iterate(vpiArgument, systf_handle);
  assert(arg_iterator !is null);

  sha_st req;
  /* static sha_st invalid; */
  /* if (invalid is null) invalid = new sha_st(); */

  sha_tb.req_ingress.get(req);

  if(req is null) {
    // if(test.isTerminated()) {
    writeln(" > Sending vpiFinish signal to the Verilog Simulator -- null");
    vpi_control(vpiFinish, 1);
    // }
  }
  else {
    vpiPutValues(arg_iterator, true, req.reset,
		 req.data, req.end);
  }
  return 0;
}


void pull_sha_register(void* tb)
{
  import std.string;
  s_vpi_systf_data tf_data;

  tf_data.type = vpiSysFunc;
  tf_data.sysfunctype = vpiSysFuncSized;
  tf_data.tfname = cast(char*) "$pull_sha".toStringz;
  tf_data.calltf = &pull_sha_calltf;
  tf_data.compiletf = &pull_sha_compiletf;
  //  tf_data.sizetf = 0;
  tf_data.user_data = tb;
  vpi_register_systf(&tf_data);
}

int resp_sha_compiletf(char* user_data)
{
  // do{
  auto systf_handle = vpi_handle(vpiSysTfCall, null);
  assert(systf_handle !is null);

  auto arg_iterator = vpi_iterate(vpiArgument, systf_handle);

  assert(arg_iterator !is null);

  for (size_t i=0; i!=5; ++i) {	/* there have to be 4 arguments */
    auto arg_handle = vpi_scan(arg_iterator);
    if((i < 4 && arg_handle is null) || (i == 4 && arg_handle !is null)) {
      writeln("ERROR: $resp_sha requires 4 arguments!");
      writeln("ERROR: ", i, " are provided!!");
      break;
    }
  }
  return 0;
}

int resp_sha_calltf(char* user_data)
{
  TestBench test = cast(TestBench) user_data;
  assert(test !is null);

  auto sha_tb = test.tb.get_root();
  assert(sha_tb !is null);

  sha_tb.set_thread_context();
  
  /* if(test.isTerminated()) { */
  /*   import std.stdio; */
  /*   writeln(" > Sending vpiFinish signal to the Verilog Simulator"); */
  /*   stdout.flush(); */
  /*   vpi_control(vpiFinish, 1); */
  /* } */

  auto systf_handle = vpi_handle(vpiSysTfCall, null);
  assert(systf_handle !is null);
  
  auto arg_iterator = vpi_iterate(vpiArgument, systf_handle);
  assert(arg_iterator !is null);

  bool valid_out;

  vpiGetValues(arg_iterator, valid_out);

  if (valid_out) {
    static bool start_out = true;
    bool reset;
    // auto rsp = new sha_st();
    sha_st rsp;
    sha_tb.rsp_generator.get(rsp);
    vpiGetValues(arg_iterator, reset, rsp.data, rsp.end);
    if(start_out is true) {
      rsp.start = true;
      start_out = false;
    }
    else {
      rsp.start = false;
    }
    if (rsp.end == true) {
      start_out = true;
    }
    // rsp.print();
  
    sha_tb.rsp_egress.put(rsp);

  }
  return 0;
}

void resp_sha_register(void* tb)
{
  import std.string;
  s_vpi_systf_data af_data;

  af_data.type = vpiSysFunc;
  af_data.sysfunctype = vpiSysFuncSized;
  af_data.tfname = cast(char*) "$resp_sha".toStringz;
  af_data.calltf = &resp_sha_calltf;
  af_data.compiletf = &resp_sha_compiletf;
  //af_data.sizetf = 0;
  af_data.user_data = tb;
  vpi_register_systf(&af_data);
}



void main(string[] argv)
{
  import std.random: uniform;
  import std.stdio;
  /* import core.memory: GC; */

  /* GC.disable(); */

  TestBench test = new TestBench;
  test.multiCore(0, 0);
  test.elaborate("test", argv);
  test.tb.set_seed(100);
  test.simulate();

}


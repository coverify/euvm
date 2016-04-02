import esdl;
import uvm;
import std.stdio;
import esdl.intf.vpi;
import std.string: format;

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
    uvm_info("sha_st_seq", "Starting sequence", UVM_MEDIUM);

    // atomic sequence
    // uvm_create(req);

    wait_for_grant();
    
    send_request(reset);

    for (size_t i=0; i!=phrase.length; ++i) {
      wait_for_grant();
      if(i == 0) {req.start = true;}
      else {req.start = false;}
      req.data = cast(ubyte) phrase[i];
      // if(i == seq_size - 1) {req.end = true;}
      req.end = false;
      sha_st cloned = cast(sha_st) req.clone;
      send_request(cloned);
    }
    
    wait_for_grant();
    
    send_request(end);

    uvm_info("sha_st", "Finishing sequence", UVM_MEDIUM);
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
    uvm_info("sha_st_seq", "Starting sequence", UVM_MEDIUM);

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

    uvm_info("sha_st", "Finishing sequence", UVM_MEDIUM);
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
  /*   // fifo_out = new uvm_tlm_fifo_egress!sha_st("fifo_out", this, 0); */
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

      // push the transaction
      // ....
      // req_egress.put(req);

      this.trans_received(req);
      // uvm_do_callbacks(sha_st_driver,sha_st_driver_cbs,trans_received(this,req));
         
      // get the reponse
      // ingress.get(rsp);

      // writeln(rsp.convert2string());

      req_egress.put(req);
      req_analysis.write(req);
      
      this.trans_executed(req);

      seq_item_port.item_done();
      
      // uvm_do_callbacks(sha_st_driver,sha_st_driver_cbs,trans_executed(this,req));

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

  sha_st_monitor   input_mon;
  sha_st_monitor   output_mon;

  mixin uvm_component_utils;
   
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    driver.seq_item_port.connect(sequencer.seq_item_export);
    auto root = cast(sha_st_root) get_root();
    assert(root !is null);
    driver.req_analysis.connect(input_mon.ingress);
    root.rsp_anaylsis.connect(output_mon.ingress);
    driver.req_egress.connect(root.fifo_out.put_export);
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

    for (size_t i=0; i!=100; ++i) {
      rand_sequence.randomize();
      auto sequence = cast(sha_st_seq) rand_sequence.clone();
      writeln("Generated ", i,
 " seq with ", sequence.seq_size, " transactions");
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

class sha_st_root: uvm_root
{
  mixin uvm_component_utils;

  // sha_st_env env;

  uvm_tlm_fifo_ingress!sha_st fifo_in;
  uvm_tlm_fifo_egress!sha_st fifo_out;


  uvm_put_port!sha_st rsp_egress;
  uvm_get_port!sha_st req_ingress;

  uvm_get_port!sha_st rsp_ingress;

  uvm_analysis_port!sha_st rsp_anaylsis;

  override void initial() {
    set_timeout(0.nsec, false);
    run_test();
  }

  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);
    version(EDISON) {
      auto fifoThread = new Thread(&driveGPIO).start();//thread
    }
    
    while(true) {
      sha_st item;
      rsp_ingress.get(item);
      rsp_anaylsis.write(item);
    }
  }
    
  void driveGPIO() {
    import esdl.intf.mraa;
    import core.stdc.stdlib: exit;
    import core.thread: Thread;
    import core.time: dur;
    
    enum CLK_PIN = 31;
    enum VLD_PIN = 32;

    this.set_thread_context();
    mraa_result_t r = mraa_result_t.MRAA_SUCCESS;
    /* Create access to GPIO pin */
    mraa_gpio_context clk;
    mraa_gpio_context vld;

    scope(exit) {
      /* Clean up CLK and exit */
      r = mraa_gpio_close(clk);
      if ( r != MRAA_SUCCESS ) {
	mraa_result_print(r);
      }
      r = mraa_gpio_close(vld);
      if ( r != MRAA_SUCCESS ) {
	mraa_result_print(r);
      }
    }

    mraa_init();

    clk = mraa_gpio_init(CLK_PIN);
    if ( clk is null ) {
      stderr.writeln("Error opening CLK\n");
      exit(1);
    }
    vld = mraa_gpio_init(VLD_PIN);
    if ( vld is null ) {
      stderr.writeln("Error opening VLD\n");
      exit(1);
    }

    /* Set CLK direction to out */
    r = mraa_gpio_dir(clk, mraa_gpio_dir_t.MRAA_GPIO_OUT);
    if ( r != MRAA_SUCCESS ) {
      Thread.sleep(dur!("msecs")(1));
    }

    r = mraa_gpio_dir(vld, mraa_gpio_dir_t.MRAA_GPIO_OUT);
    if ( r != MRAA_SUCCESS ) {
      Thread.sleep(dur!("msecs")(1));
    }

    /* Create signal handler so we can exit gracefully */
    // signal(SIGINT, &sig_handler);

    /* Turn LED off and on forever until SIGINT (Ctrl+c) */
    while ( true ) {
      r = mraa_gpio_write(clk, 0);
      if ( r != MRAA_SUCCESS ) {
	mraa_result_print(r);
      }

      sha_st tx;
      assert(req_ingress !is null);
      
      auto valid = req_ingress.try_get(tx);
      if(valid && tx !is null) {
	// tx.print();
	import std.stdio;
	writeln("Data is: ", tx.data);
      	r = mraa_gpio_write(vld, 1);
      } else {
      	r = mraa_gpio_write(vld, 0);
      }
      if ( r != MRAA_SUCCESS ) {
      	mraa_result_print(r);
      }

      if(valid && tx is null) {
      	break;
      }
      
      Thread.sleep(dur!("msecs")(1));
      r = mraa_gpio_write(clk, 1);
      if ( r != MRAA_SUCCESS ) {
	mraa_result_print(r);
      }
      Thread.sleep(dur!("msecs")(1));
    }

  }
  

  override void connect_phase(uvm_phase phase) {
    req_ingress.connect(fifo_out.get_export);
    rsp_ingress.connect(fifo_in.get_export);
    rsp_egress.connect(fifo_in.put_export);
  }

  
}

class TestBench: RootEntity
{
  uvm_root_entity!(sha_st_root) tb;

  // public override void doFinish() {
  //   foreach(p; tb.get_root().fifo_out) {
  //     p.put(null);
  //   }
    
  // }
}


extern(C) int initEsdl() {
  import core.runtime;  
  import std.random: uniform;
  import std.stdio;
  import esdl.intf.vpi;
  import core.memory;

  Runtime.initialize();
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

  GC.addRoot(cast(void*) test);

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
    writeln(" > Sending vpiFinish signal to the Verilog Simulator");
    vpi_control(vpiFinish, 1);
    // }
  }
  else {
    writeln(" > Got req to handle");
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
      writeln("ERROR: $pull_sha requires 4 arguments!");
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
    import std.stdio;
    writeln("###############");
    static bool start_out = true;
    bool reset;
    auto rsp = new sha_st();
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
    rsp.print();
  
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
  test.multiCore(1, 0);
  test.elaborate("test", argv);
  test.tb.set_seed(100);
  test.simulate();

}


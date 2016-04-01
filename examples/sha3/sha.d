import esdl;
import uvm;
import std.stdio;
import esdl.intf.vpi;
import std.string: format;

enum COUNT = 1;

@UVM_DEFAULT
class avl_st: uvm_sequence_item
{
  @rand ubyte data;
  bool start;
  bool end;
  bool reset;

  mixin uvm_object_utils;
   
  this(string name = "avl_st") {
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
class avl_st_seq: uvm_sequence!avl_st
{
  avl_st reset;
  avl_st req;
  avl_st end;
  mixin uvm_object_utils;

  @rand uint seq_size;

  this(string name="") {
    super(name);
    reset = avl_st.type_id.create(name ~ ".reset");
    req = avl_st.type_id.create(name ~ ".req");
    end = avl_st.type_id.create(name ~ ".end");
    reset.reset = true;
    end.end = true;
  }

  Constraint!q{
    seq_size < 64;
    seq_size > 16;
  } seq_size_cst;

  // task
  override void frame() {
    uvm_info("avl_st_seq", "Starting sequence", UVM_MEDIUM);

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
      avl_st cloned = cast(avl_st) req.clone;
      send_request(cloned);
    }
    
    wait_for_grant();
    
    send_request(end);

    uvm_info("avl_st", "Finishing sequence", UVM_MEDIUM);
  } // frame

}

class avl_st_driver_cbs: uvm_callback
{
  void trans_received (avl_st_driver xactor , avl_st cycle) {}
  void trans_executed (avl_st_driver xactor , avl_st cycle) {}
}

class avl_st_driver: uvm_driver!avl_st
{

  mixin uvm_component_utils;
  
  uvm_put_port!avl_st egress;
  
  /* override void build_phase(uvm_phase phase) { */
  /*   // egress = new uvm_put_port!avl_st("egress", this); */
  /*   // fifo_out = new uvm_tlm_fifo_egress!avl_st("fifo_out", this, 0); */
  /*   // ingress = new uvm_get_port!avl_st("ingress", this); */
  /* } */

  Event trig;
  // avl_st_vif sigs;
  // avl_st_config cfg;

  this(string name, uvm_component parent = null) {
    super(name,parent);
  }

  override void connect_phase(uvm_phase phase) {
    auto root = cast(avl_st_root) get_root();
    assert(root !is null);
    egress.connect(root.fifo_out.put_export);
  }

  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);

    while(true) {
      avl_st req;

      
      seq_item_port.get_next_item(req);

      // push the transaction
      // ....
      // egress.put(req);

      this.trans_received(req);
      // uvm_do_callbacks(avl_st_driver,avl_st_driver_cbs,trans_received(this,req));
         
      // get the reponse
      // ingress.get(rsp);

      // writeln(rsp.convert2string());

      version(EDISON) {
	egress.put(req);
      }
      else {
	egress.put(req);
	// req.print();
      }
      
      this.trans_executed(req);

      seq_item_port.item_done();
      
      // uvm_do_callbacks(avl_st_driver,avl_st_driver_cbs,trans_executed(this,req));

    }
  }

  override void final_phase(uvm_phase phase) {
    egress.put(null);
  }

  protected void trans_received(avl_st tr) {}
    
 
  protected void trans_executed(avl_st tr) {}

}

class avl_st_sequencer: uvm_sequencer!avl_st
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class avl_st_agent: uvm_agent
{

  avl_st_sequencer sequencer;
  avl_st_driver    driver;
  // avl_st_monitor   mon;

  // avl_st_vif       vif;

  mixin uvm_component_utils;
   
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  // override void build_phase(uvm_phase phase) {
  //   sequencer = avl_st_sequencer.type_id.create("sequencer", this);
  //   driver = avl_st_driver.type_id.create("driver", this);
  //   // mon = avl_st_monitor::type_id::create("mon", this);
  // }

  override void connect_phase(uvm_phase phase) {
    driver.seq_item_port.connect(sequencer.seq_item_export);
  }
}

class RandomTest: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  avl_st_env env;
  
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    auto rand_sequence = new avl_st_seq("avl_st_seq");

    for (size_t i=0; i!=100; ++i) {
      rand_sequence.randomize();
      auto sequence = cast(avl_st_seq) rand_sequence.clone();
      writeln("Generated ", i,
 " seq with ", sequence.seq_size, " transactions");
      sequence.start(env.agent.sequencer, null);
    }
    
    // waitForks();
    
    phase.drop_objection(this);
  }
}

class avl_st_env: uvm_env
{
  mixin uvm_component_utils;
  private avl_st_agent agent;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  // task
 /*  override void run_phase(uvm_phase phase) { */
 /*    phase.raise_objection(this); */
 /*    auto rand_sequence = new avl_st_seq("avl_st_seq"); */

 /*    for (size_t i=0; i!=100; ++i) { */
 /*      rand_sequence.randomize(); */
 /*      auto sequence = cast(avl_st_seq) rand_sequence.clone(); */
 /*      writeln("Generated ", i, */
 /* " seq with ", sequence.seq_size, " transactions"); */
 /*      sequence.start(agent.sequencer, null); */
 /*    } */
    
 /*    // waitForks(); */
    
 /*    phase.drop_objection(this); */
 /*  } */
};

class avl_st_root: uvm_root
{
  mixin uvm_component_utils;

  // avl_st_env env;

  uvm_tlm_fifo_ingress!avl_st[COUNT] fifo_in;
  uvm_tlm_fifo_egress!avl_st fifo_out;


  uvm_put_port!avl_st[COUNT] egress;

  uvm_get_port!avl_st ingress;

  override void initial() {
    set_timeout(0.nsec, false);
    // for (size_t i=0; i!=COUNT; ++i)
    //   {
    // 	ingress[i] = new uvm_get_port!avl_st(format("ingress[%s]", i), this);
    // 	egress[i] = new uvm_put_port!avl_st(format("egress[%s]", i), this);

    // 	fifo_out[i] = new uvm_tlm_fifo_egress!avl_st(format("fifo_out[%s]", i),
    // 						     null, 1);
    // 	fifo_in[i] = new uvm_tlm_fifo_ingress!avl_st(format("fifo_in[%s]", i),
    // 						     null, 1);

    //   }
    // env = new avl_st_env("env", null);
    run_test();
  }

  override void run_phase(uvm_phase phase) {
    version(EDISON) {
      auto fifoThread = new Thread(&driveGPIO).start();//thread
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

      avl_st tx;
      assert(ingress !is null);
      
      auto valid = ingress.try_get(tx);
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
    ingress.connect(fifo_out.get_export);
    
    for (size_t i=0; i!=COUNT; ++i)
      {
	egress[i].connect(fifo_in[i].put_export);
      }
  }

  
}

class TestBench: RootEntity
{
  uvm_root_entity!(avl_st_root) tb;

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

  /* resp_sha_register(tb); */
  pull_sha_register(tb);
  
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
      writeln("ERROR: only ", i, " are provided!!");
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

  avl_st req;
  /* static avl_st invalid; */
  /* if (invalid is null) invalid = new avl_st(); */

  sha_tb.ingress.get(req);

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

/* int resp_sha_compiletf(char* user_data) */
/* { */
/*   vpiHandle systf_handle, arg_iterator, arg_handle; */

/*   // do{ */
/*   systf_handle = vpi_handle(vpiSysTfCall, null); */
/*   assert(systf_handle !is null); */

/*   arg_iterator = vpi_iterate(vpiArgument, systf_handle); */

/*   assert(arg_iterator !is null); */

/*   //  else{ */
/*   for(size_t i=0; i!=5; ++i){ */
/*     arg_handle = vpi_scan(arg_iterator); */
/*     if(arg_handle !is null){ */
/*       writeln("ERROR: $resp_sha requires 5 arguments!"); */
/*       writeln("ERROR: only ", i, " are provided!!"); */
/*       break; */
/*     } */
/*   } */
/*   //} */
/*   return 0; */
/* } */

/* int resp_sha_calltf(char* user_data) */
/* { */
/*   import std.stdio; */

/*   vpiHandle systf_handle; */
/*   vpiHandle arg_iterator; */

/*   uint index; */
 
/*   TestBench test = cast(TestBench) user_data; */
/*   if(test.isTerminated()) { */
/*     import std.stdio; */
/*     writeln(" > Sending vpiFinish signal to the Verilog Simulator"); */
/*     stdout.flush(); */
/*     vpi_control(vpiFinish, 1); */
/*   } */
/*   else { */
/*     import std.stdio; */
/*     writeln(" > hmmmm"); */
/*   } */

/*   systf_handle = vpi_handle(vpiSysTfCall, null); */
/*   assert(systf_handle !is null); */
  
/*   arg_iterator = vpi_iterate(vpiArgument, systf_handle); */
  
/*   assert(arg_iterator !is null); */

/*   vpiGetValues(arg_iterator, index); */
/*   sha_tb.set_thread_context(); */
/*   sha_rw rsp = new sha_rw(); */
/*   vpiGetValues(arg_iterator, rsp.addr, rsp.kind, rsp.wdata, rsp.rdata); */
/*   rsp.print(); */
  
/*   sha_tb.egress[index].put(rsp); */

/*   return 0; */
/* } */

/* void resp_sha_register(void* tb) */
/* { */
/*   import std.string; */
/*   s_vpi_systf_data af_data; */

/*   af_data.type = vpiSysFunc; */
/*   af_data.sysfunctype = vpiSysFuncSized; */
/*   af_data.tfname = cast(char*) "$resp_sha".toStringz; */
/*   af_data.calltf = &resp_sha_calltf; */
/*   af_data.compiletf = &resp_sha_compiletf; */
/*   //af_data.sizetf = 0; */
/*   af_data.user_data = tb; */
/*   vpi_register_systf(&af_data); */
/* } */



void main()
{
  import std.random: uniform;
  import std.stdio;
  /* import core.memory: GC; */

  /* GC.disable(); */

  TestBench test = new TestBench;
  test.multiCore(1, 0);
  test.elaborate("test");
  test.tb.set_seed(100);
  test.simulate();

}


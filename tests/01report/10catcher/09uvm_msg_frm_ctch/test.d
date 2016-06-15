//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
//   Copyright 2016 Coverify Systems Technology
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

//////////////distrib/src/base/uvm_object_globals.svh////////////////////////////
//////// uvm_severity   
////////
///////typedef enum uvm_severity
///////{
///////  UVM_INFO,
///////  UVM_WARNING,
///////  UVM_ERROR,
///////  UVM_FATAL
/////////} uvm_severity;
//////////////////////////


///////uvm_misc.svh////////////
/////////
////// typedef enum {UVM_APPEND, UVM_PREPEND} uvm_apprepend;
///////////////////////////////
///////////////////////////////

import esdl;
import uvm;
import std.stdio;

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

class test_root:uvm_root
{
  mixin uvm_component_utils;
}
 
class my_catcher_info: uvm_report_catcher
{
  // this(string name)
  // {
  //   super(name);
  // }
   
  override  action_e do_catch()
  {
    import std.stdio;
    if(get_name() != get_id()) return THROW;
    if(get_severity() != UVM_INFO) return THROW;
    writeln("Info Catcher Caught a message...\n");
    //to be done
      
    uvm_info("INFO CATCHER", "From my_catcher_info catch()" , UVM_MEDIUM);
     
    return THROW;
  }
}
  
class my_catcher_warning: uvm_report_catcher
{
  // this(string name) {
  // 	super.new(name);
  // }
  override  action_e do_catch()
  {
    import std.stdio;
    if(get_name() != get_id()) return THROW;
    if(get_severity() != UVM_WARNING) return THROW;
    writeln("Warning Catcher Caught a message...\n");
    // to be done
    uvm_warning("WARNING CATCHER","From my_catcher_warning catch()");
  
     
    return THROW;
  }
}

class my_catcher_error : uvm_report_catcher
{
  // this(string name){
  // 	 super.new(name);
  // 	}   
   
  override    action_e do_catch()
  {
    import std.stdio;
    if(get_name() != get_id()) return THROW;
    if(get_severity() != UVM_ERROR) return THROW;
    writeln("Error Catcher Caught a message...\n");
    // to be done
    uvm_error( "ERROR CATCHER ","From my_catcher_error catch() ");
  
     
    return THROW;
  }
}

class my_catcher_fatal: uvm_report_catcher
{
  // this(string name)
  // 	{
  // 	 super.new(name)
  // 	} 
  
   
  override  action_e do_catch()
  {
    import std.stdio;	
    if(get_name() != get_id()) return THROW;
    if(get_severity() != UVM_FATAL) return THROW;
    writeln("Fatal Catcher Caught a Fatal message...\n");
    // to be done
    uvm_info("FATAL CATCHER", "From my_catcher_fatal catch()", UVM_NONE);
  
    
    return THROW;
  }
}

class test: uvm_test
{
  mixin uvm_component_utils;
  this(string name, uvm_component parent = null)
  {
    super(name, parent);
     
  }

  override  void  run()
  {
    my_catcher_info ctchr1 = new my_catcher_info;
    my_catcher_warning ctchr2 = new my_catcher_warning;
    my_catcher_error ctchr3 = new my_catcher_error;
    my_catcher_fatal ctchr4 = new my_catcher_fatal;
    import std.stdio;
    writeln("UVM TEST - Same catcher type - different IDs\n");
  
           
          

    writeln("adding a catcher of type my_catcher_info with id of Catcher1\n");
    uvm_report_cb.add(null,ctchr1);
          
    writeln("adding a catcher of type my_catcher_warning with id of Catcher2\n");
    uvm_report_cb.add(null,ctchr2);

    writeln("adding a catcher of type my_catcher_error with id of Catcher3\n");
    uvm_report_cb.add(null,ctchr3);
          
    writeln("adding a catcher of type my_catcher_fatal with id of Catcher4\n");
    uvm_report_cb.add(null,ctchr4);
          
    uvm_info("Catcher1", "This Info message is for Catcher1", UVM_MEDIUM);
    uvm_warning("Catcher2", "This Warning message is for Catcher2");
    uvm_error ("Catcher3", "This Error message is for Catcher3");
    //`uvm_fatal ("Catcher4", "This fatal message is for Catcher4");
    uvm_info("XYZ", "This second message is for No One", UVM_MEDIUM);

          
        
  

    writeln("UVM TEST EXPECT 2 UVM_ERROR\n");
  
    uvm_top.stop_request();
  }

  override   void report()
  {
    import std.stdio; 
    writeln("** UVM TEST PASSED **\n");
  }
}

int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0,0);
  tb.elaborate("test", argv);
  auto error = tb.simulate();	// error is expected
  if (error != 0) return 0;
  else return 1;
} 



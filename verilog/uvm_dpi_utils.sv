`ifndef _UVM_DPI_UTILS_SV_
`define _UVM_DPI_UTILS_SV_

module uvm_dpi_utils();
   import "DPI-C" function void uvm_dpi_init();

   export "DPI-C" function uvm_dpi_get_time;
   export "DPI-C" function uvm_dpi_get_testname;
   export "DPI-C" function uvm_dpi_get_verbosity;
   export "DPI-C" function uvm_dpi_get_plusarg;
   export "DPI-C" function uvm_dpi_is_usable;

   function longint uvm_dpi_get_time();
      return $time;
   endfunction: uvm_dpi_get_time

   function string uvm_dpi_get_testname();
      string arg;
      if ($value$plusargs("UVM_TESTNAME=%s", arg)) begin
	 $display("Found plusarg: %s\n", arg);
      end
      else begin
	 $display("Not Found any UVM_TESTNAME= in command line");
      end
      return arg;
   endfunction: uvm_dpi_get_testname

   function string uvm_dpi_get_verbosity();
      string arg;
      if ($value$plusargs("UVM_VERBOSITY=%s", arg)) begin
	 $display("Found plusarg: %s\n", arg);
      end
      else begin
	 $display("Not Found any UVM_VERBOSITY= in command line");
      end
      return arg;
   endfunction: uvm_dpi_get_verbosity


   function bit uvm_dpi_is_usable();
      return 1;
   endfunction: uvm_dpi_is_usable
   
   // does not currently work with vivado -- seems vivado needs a
   // string literal with $value$plusargs, it does not with with a
   // string variable as of version 2018.1
   function string uvm_dpi_get_plusarg(string prefix);
      string arg;
      if ($value$plusargs(prefix, arg)) begin
	 $display("Found plusarg: %s\n", arg);
      end
      else begin
	 $display("Not Found plusarg for prefix %s\n", prefix);
      end
      return arg;
   endfunction

   initial begin
      $display("Initializing UVM DPI module");
      uvm_dpi_init();      
   end
   
endmodule

`endif // _UVM_DPI_UTILS_SV_

`timescale 1ns / 1ps
`define clk 2

module axi_tb #	(parameter integer DW	= 32,
		 parameter integer AW = 4)();

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire 			      s00_axi_arready; // From dut of sha3_wrapper_v1_0.v
   wire 			      s00_axi_awready; // From dut of sha3_wrapper_v1_0.v
   wire [1:0] 			      s00_axi_bresp; // From dut of sha3_wrapper_v1_0.v
   wire 			      s00_axi_bvalid; // From dut of sha3_wrapper_v1_0.v
   wire [DW-1:0]    s00_axi_rdata;// From dut of sha3_wrapper_v1_0.v
   wire [1:0] 			      s00_axi_rresp; // From dut of sha3_wrapper_v1_0.v
   wire 			      s00_axi_rvalid; // From dut of sha3_wrapper_v1_0.v
   wire 			      s00_axi_wready; // From dut of sha3_wrapper_v1_0.v
   // End of automatics
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg 				      s00_axi_aclk;
   //reg 				      s00_axi_aclk; // To dut of sha3_wrapper_v1_0.v
   reg [AW-1:0]     s00_axi_araddr;// To dut of sha3_wrapper_v1_0.v
   reg 				      s00_axi_aresetn; // To dut of sha3_wrapper_v1_0.v
   reg [2:0] 			      s00_axi_arprot; // To dut of sha3_wrapper_v1_0.v
   reg 				      s00_axi_arvalid; // To dut of sha3_wrapper_v1_0.v
   reg [AW-1:0]     s00_axi_awaddr;// To dut of sha3_wrapper_v1_0.v
   reg [2:0] 			      s00_axi_awprot; // To dut of sha3_wrapper_v1_0.v
   reg 				      s00_axi_awvalid; // To dut of sha3_wrapper_v1_0.v
   reg 				      s00_axi_bready; // To dut of sha3_wrapper_v1_0.v
   reg 				      s00_axi_rready; // To dut of sha3_wrapper_v1_0.v
   reg [DW-1:0]     s00_axi_wdata;// To dut of sha3_wrapper_v1_0.v
   reg [(DW/8)-1:0] s00_axi_wstrb;// To dut of sha3_wrapper_v1_0.v
   reg 				      s00_axi_wvalid;		// To dut of sha3_wrapper_v1_0.v
   // End of automatics
   

   axi4_sha3_v1_0 #(.C_S00_AXI_DATA_WIDTH(DW),
	       .C_S00_AXI_ADDR_WIDTH(AW))
   dut (
			 /*AUTOINST*/
			 // Outputs
			 .s00_axi_awready	(s00_axi_awready),
			 .s00_axi_wready	(s00_axi_wready),
			 .s00_axi_bresp		(s00_axi_bresp[1:0]),
			 .s00_axi_bvalid	(s00_axi_bvalid),
			 .s00_axi_arready	(s00_axi_arready),
			 .s00_axi_rdata		(s00_axi_rdata[DW-1:0]),
			 .s00_axi_rresp		(s00_axi_rresp[1:0]),
			 .s00_axi_rvalid	(s00_axi_rvalid),
			 // Inputs
			 .s00_axi_aclk		(s00_axi_aclk),
			 .s00_axi_aresetn	(s00_axi_aresetn),
			 .s00_axi_awaddr	(s00_axi_awaddr[AW-1:0]),
			 .s00_axi_awprot	(s00_axi_awprot[2:0]),
			 .s00_axi_awvalid	(s00_axi_awvalid),
			 .s00_axi_wdata		(s00_axi_wdata[DW-1:0]),
			 .s00_axi_wstrb		(s00_axi_wstrb[(DW/8)-1:0]),
			 .s00_axi_wvalid	(s00_axi_wvalid),
			 .s00_axi_bready	(s00_axi_bready),
			 .s00_axi_araddr	(s00_axi_araddr[AW-1:0]),
			 .s00_axi_arprot	(s00_axi_arprot[2:0]),
			 .s00_axi_arvalid	(s00_axi_arvalid),
			 .s00_axi_rready	(s00_axi_rready));


   initial begin: bfm
      s00_axi_aresetn = 1'b0;
      #(`clk*4) s00_axi_aresetn = 1'b1;
   end // block: bfm

   always @(negedge s00_axi_aclk) begin
      if (s00_axi_aresetn == 0)
	begin
	   s00_axi_awaddr	<=0;
	   s00_axi_awprot	<=0;
	   s00_axi_awvalid      <=0;
	   s00_axi_wdata	<=0;
	   s00_axi_wstrb	<=0;
	   s00_axi_wvalid	<=0;
	   s00_axi_bready	<=0;
	   s00_axi_araddr	<=0;
	   s00_axi_arprot	<=0;
	   s00_axi_arvalid      <=0;
	   s00_axi_rready	<=0;
	end // if (s00_axi_aresetn == 0)
   end // always @ (negedge clk)

   initial begin: read_bfm
      reg [AW-1:0] raddr;
      reg [DW-1:0] rdata;
      reg [3:0]    rstrb;
      reg [1:0]    rresp;
      @(posedge s00_axi_aclk);
      forever begin
	 while (s00_axi_aresetn != 1'b1) begin
	    @(posedge s00_axi_aclk);
	 end
	 case ($axiread_get_next_item(raddr, rstrb, rdata))
	   0: begin: valid_transaction
	      @(negedge s00_axi_aclk);
	      s00_axi_arvalid = 1'b1;
	      s00_axi_araddr = raddr;
	      @(posedge s00_axi_aclk);
	      while (s00_axi_arready != 1'b1) begin
		 @(posedge s00_axi_aclk);
	      end
	      @(negedge s00_axi_aclk);
	      s00_axi_arvalid = 1'b0;
	      s00_axi_rready = 1'b1;
	      @(posedge s00_axi_aclk);
	      while (s00_axi_rvalid != 1'b1) begin
		 @(posedge s00_axi_aclk);
	      end
	      rdata = s00_axi_rdata;
	      if ($axiread_item_done(0) != 0) $finish;
	      if ($put_axiread_rsp(raddr, rstrb, rdata, rresp) != 0) begin
		 $finish;
	      end
	   end // block: valid_transaction
	   1: begin: idle_transaction
	      @(negedge s00_axi_aclk);
	      s00_axi_arvalid = 1'b0;
	      s00_axi_rready = 1'b0;
	      @(posedge s00_axi_aclk);
	   end
	   default: $finish;
	 endcase
      end
   end // initial begin
   
   
   initial begin: write_bfm
      reg [AW-1:0] waddr;
      reg [DW-1:0] wdata;
      reg [3:0]    wstrb;
      reg [1:0]    wresp;
      @(posedge s00_axi_aclk);
      forever begin
	 while (s00_axi_aresetn != 1'b1) begin
	    @(posedge s00_axi_aclk);
	 end
	 case ($axiwrite_get_next_item(waddr, wstrb, wdata))
	   0: begin: valid_transaction
	      fork
		 begin
		    @(negedge s00_axi_aclk);
		    s00_axi_awvalid = 1'b1;
		    s00_axi_awaddr = waddr;
		    @(posedge s00_axi_aclk);
		    while (s00_axi_awready != 1'b1) begin
		       @(posedge s00_axi_aclk);
		    end
		 end
		 begin
		    s00_axi_wvalid = 1'b1;
		    s00_axi_wdata = wdata;
		    s00_axi_wstrb = wstrb;
		    @(posedge s00_axi_aclk);
		    while (s00_axi_wready != 1'b1) begin
		       @(posedge s00_axi_aclk);
		    end
		    @(negedge s00_axi_aclk);
		    s00_axi_wvalid = 1'b0;
		    s00_axi_bready = 1'b1;
		    @(posedge s00_axi_aclk);
		    while (s00_axi_bvalid != 1'b1) begin
		       @(posedge s00_axi_aclk);
		    end
		    wresp = s00_axi_bresp;
		    if ($axiwrite_item_done(0) != 0) $finish;
		    if ($put_axiwrite_rsp(waddr, wstrb, wdata, wresp) != 0) begin
		       $finish;
		    end
		 end
	      join
	   end // block: valid_tr
	   1: begin: idle_transaction
	      @(negedge s00_axi_aclk);
	      s00_axi_awvalid = 1'b0;
	      s00_axi_wvalid = 1'b0;
	      @(posedge s00_axi_aclk);
	   end
	   default: $finish;
	 endcase
      end // block: write_bfm
   end
      

   initial begin
      $dumpfile("interface.vcd");
      $dumpvars(4, dut);
      $dumpon;
      s00_axi_aclk = 0;
      forever begin
	// $display("inside clk block");
	 #(`clk/2);
	 s00_axi_aclk = ~ s00_axi_aclk;
      end // forever begin
   end // initial begin


endmodule // axi_tb





// Local Variables:
// verilog-library-directories:("." "../rtl")
// End:

// $Id: fw_link_tb.v,v 1.1 2002-03-10 17:17:36 johnsonw10 Exp $
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// FIREWIRE IP Core                                             ////
////                                                              ////
//// This file is part of the firewire project                    ////
//// http://www.opencores.org/cores/firewire/                     ////
////                                                              ////
//// Description                                                  ////
//// Implementation of firewire IP core according to              ////
//// firewire IP core specification document.                     ////
////                                                              ////
//// To Do:                                                       ////
//// -                                                            ////
////                                                              ////
//// Author(s):                                                   ////
//// - johnsonw10@opencores.org                                   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2001 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
//
//

/**********************************************************************
  Design Notes:
  1. Startup sequence:
     * hard reset
     * set all enable signals
     * PHY receives self ID packet
     * PHY status receiving of self ID packet (PHYID write)
     * 
     * 
     * 
***********************************************************************/

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

module fw_link_tb;

reg reset_n;
reg sclk;

wire [0:7] d;
wire [0:1] ctl;

wire [0:3] phy_reg_addr;
wire [0:7] phy_reg_data;

wire [0:31] grxf_data, atxf_data, itxf_data;

reg [0:31] selfid_data;

// host interface
reg [0:7]  host_addr;
wire [0:31] host_data;
reg  [0:31] host_data_out;  // driven by the host

reg        host_cs_n, host_wr_n;
reg [0:31] rcv_buf[0:63];
reg [0:31] send_buf[0:63];

reg [0:7]  phy_d;
reg [0:1]  phy_ctl;
reg        phy_oe;

reg [0:15] status_data;

integer grxf_data_num;

reg [0:31] atxf_din;
reg        atxf_wr;

reg [0:31] itxf_din;
reg        itxf_wr;

reg set_arb_won;
     
initial begin
    reset_n = 1;
    host_cs_n = 1;
    host_wr_n = 1;

    phy_oe = 0;
    phy_ctl = 2'b00;
    phy_d   = 8'h00;
    grxf_data_num = 0;
    atxf_wr = 0;

    #25 reset_n = 0;
    #100 reset_n = 1;
    
    
    // enable link_op (set bits 5, 6, 7, 8 @ 0x08)
    host_write_reg (16'h08, 32'h0780_0000);
    
    #100;

    // phy receive selfid packet #0
    selfid_data[0:1]   = 2'b01;          //selfid packet identifier
    selfid_data[2:7]   = 6'b00_0011;     //sender's phy_ID
    selfid_data[8]     = 1'b0;           //always 0
    selfid_data[9]     = 1'b1;           //link_active = 1
    selfid_data[10:15] = 6'b01_0000;     //gap_count = 10h
    selfid_data[16:17] = 2'b00;          //phy_speed = 100Mbit/s
    selfid_data[18:19] = 2'b00;          //phy_delay <= 144ns
    selfid_data[20]    = 1'b0;           //contender = 0
    selfid_data[21:23] = 3'b000;         //power_class = 0;
    selfid_data[24:25] = 2'b11;          //p0;
    selfid_data[26:27] = 2'b11;          //p1
    selfid_data[28:29] = 2'b11;          //p2
    selfid_data[30]    = 1'b0;           //initiated_reset = 0
    selfid_data[31]    = 1'b0;           //more_packets = 0

    rcv_buf[0] = selfid_data;
    rcv_buf[1] = ~selfid_data;
    
    $display ("PHY is in receive mode...");
    $display ("    data 0 = %h", rcv_buf[0]);
    $display ("    data 1 = %h", rcv_buf[1]);
    phy_rcv_pkt (2'b00, 2); //receive 2 32-bit word at 100Mbit/s

    #100;

    //phy status receviing self-id packet
    status_data[0]    = 1'b1;     // reset_gap = 1
    status_data[1]    = 1'b1;     // sub_gap = 1
    status_data[2]    = 1'b0;     // bus_reset = 0;
    status_data[3]    = 1'b0;     // bus_time_out = 0;
    status_data[4:7]  = 4'h0;     // physical_id addr
    status_data[8:15] = 8'b0010_1000;  // id = a, r = 0, ps = 0
    
    $display ("PHY is in status mode...");
    $display ("    status = %h", status_data);
    phy_status (status_data);

    // read request for data quadlet at 100Mbit/s
    // phy wins arbiration case
    set_arb_won = 1'b1;

    send_buf[0] = {16'h0000, 6'b010101, 2'b01, 4'h4, 4'h0};
    send_buf[1] = {16'haaaa, 16'h5555};
    send_buf[2] = 32'h1234_5678;
    $display ("LINK is sending read request for data for quadlet");
    $display ("    data 0 = %h", send_buf[0]);
    $display ("    data 1 = %h", send_buf[1]);
    $display ("    data 2 = %h", send_buf[2]);

    host_write_atxf (3);

end

initial sclk = 0;
always #10 sclk = ~sclk;   // 50MHz sclk
    
// atx FIFO
fifo_beh atxf (
	       // Outputs
	       .dout			(atxf_data[0:31]),
	       .empty			(atxf_ef),
	       .full			(atxf_ff),
	       // Inputs
	       .reset_n			(reset_n),
	       .clk			(sclk),
	       .wr			(atxf_wr),
	       .din			(atxf_din[0:31]),
	       .rd			(atxf_rd));

// itx FIFO
fifo_beh itxf (
	       // Outputs
	       .dout			(itxf_data[0:31]),
	       .empty			(itxf_ef),
	       .full			(itxf_ff),
	       // Inputs
	       .reset_n			(reset_n),
	       .clk			(sclk),
	       .wr			(itxf_wr),
	       .din			(itxf_din[0:31]),
	       .rd			(itxf_rd));

wire [0:15] src_id;
wire hard_rst = ~reset_n;
assign d = (phy_oe) ? phy_d : 8'hzz;
assign ctl = (phy_oe) ? phy_ctl : 2'bzz;

assign host_data = host_data_out;

fw_link_host_if link_host_if (/*AUTOINST*/
			      // Outputs
			      .src_id	(src_id[0:15]),
			      .tx_asy_en(tx_asy_en),
			      .rx_asy_en(rx_asy_en),
			      .tx_iso_en(tx_iso_en),
			      .rx_iso_en(rx_iso_en),
			      .soft_rst	(soft_rst),
			      // Inouts
			      .host_data(host_data[0:31]),
			      // Inputs
			      .hard_rst	(hard_rst),
			      .sclk	(sclk),
			      .host_cs_n(host_cs_n),
			      .host_wr_n(host_wr_n),
			      .host_addr(host_addr[0:7]));

fw_link_ctrl link_ctrl (/*AUTOINST*/
			// Outputs
			.lreq		(lreq),
			.status_rcvd	(status_rcvd),
			.arb_reset_gap	(arb_reset_gap),
			.sub_gap	(sub_gap),
			.bus_reset	(bus_reset),
			.state_time_out	(state_time_out),
			.phy_reg_addr	(phy_reg_addr[0:3]),
			.phy_reg_data	(phy_reg_data[0:7]),
			.atxf_rd	(atxf_rd),
			.itxf_rd	(itxf_rd),
			.grxf_we	(grxf_we),
			.grxf_data	(grxf_data[0:31]),
			// Inouts
			.d		(d[0:7]),
			.ctl		(ctl[0:1]),
			// Inputs
			.hard_rst	(hard_rst),
			.sclk		(sclk),
			.src_id		(src_id[0:15]),
			.soft_rst	(soft_rst),
			.tx_asy_en	(tx_asy_en),
			.rx_asy_en	(rx_asy_en),
			.tx_iso_en	(tx_iso_en),
			.rx_iso_en	(rx_iso_en),
			.atxf_ef	(atxf_ef),
			.atxf_data	(atxf_data[0:31]),
			.itxf_ef	(itxf_ef),
			.itxf_data	(itxf_data[0:31]),
			.grxf_ff	(grxf_ff));


// simple phy arbitor model
// ctl pin encodings
parameter CTL_IDLE     = 2'b00;
// encodings when PHY has control
parameter CTL_PHY_STATUS   = 2'b01;
parameter CTL_PHY_RECEIVE  = 2'b10;
parameter CTL_PHY_TRANSMIT = 2'b11;
// encodings when link has control
parameter CTL_LINK_HOLD     = 2'b01;
parameter CTL_LINK_TRANSMIT = 2'b10;
parameter CTL_LINK_UNUSED   = 2'b11;

wire lreq_sent;

assign lreq_sent = link_ctrl.link_req.req_sent;

always begin
    wait (lreq_sent);
    repeat (10) @ (posedge sclk); // wait for 10 clock cycles

    if (set_arb_won) begin
	// send arb won sequence on ctl pin
	@ (posedge sclk);
	phy_oe = 1'b1;
	phy_ctl = CTL_PHY_TRANSMIT;
	@ (posedge sclk);
	phy_ctl = CTL_IDLE;
	// release control of ctl and d
	@ (posedge sclk);
	phy_oe = 1'b0;
    end
    else begin
	// send arb lose sequence on ctl pin
	@ (posedge sclk);
	phy_oe = 1'b1;
	phy_ctl = CTL_PHY_RECEIVE;
	@ (posedge sclk);
	phy_ctl = CTL_IDLE;
    end
end
    


// grxf monitor
always @ (posedge sclk) begin : grxf_monitor
    if (grxf_we) begin
	$display ("===>Writing GRXF data[%d] = %h", grxf_data_num, grxf_data);
	grxf_data_num <= grxf_data_num + 1;
    end
end

// status monitor
always @ (posedge sclk) begin : status_monitor
    if (status_rcvd) begin
	$display ("===>Received status = %h", {arb_reset_gap, sub_gap,
					   bus_reset, state_time_out, 
					   phy_reg_addr, phy_reg_data});
	$display ("    arb_reset_gap = %h", arb_reset_gap);
	$display ("    sub_gap = %h", sub_gap);
	$display ("    bus_reset = %h", bus_reset);
	$display ("    state_time_out = %h", state_time_out);
	$display ("    phy_reg_addr = %h", phy_reg_addr);
	$display ("    phy_reg_data = %h", phy_reg_data);
    end
end

`include "fw_phy_tasks.v"
`include "fw_host_tasks.v"

endmodule // fw_link_tb

// Local Variables:
// verilog-library-directories:("." "../../rtl/verilog")
// End:
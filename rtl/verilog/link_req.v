// $Id: link_req.v,v 1.1 2002-03-04 02:56:10 johnsonw10 Exp $
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
  1. serial stream on LReq pin:
     request types:
         000 imm_req
         001 iso_req
         010 pri_req
         011 fair_req
         100 rd_req
         101 wr_req
         110-111: reserved
     bus request (7 bits request stream)
         0: start bit = 1
         1-3: request type
         4-5: request speed
         6: stop bit = 0;
     read request (9 bits request stream)
         0: start bit = 1
         1-3: request type
         4-7: address
         8: stop bit = 0
     write request (17 bits request stream)
         0: start bit = 1
         1-3: request type
         4-7: address
         8-15: data
         16: stop bit = 0         
 
            
         
***********************************************************************/

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

module link_req (
		 // inputs
		 reset_n,
		 sclk,
		 ctl,

		 fair_req,
		 pri_req,
		 imm_req,
		 iso_req,
		 rd_req,
		 wr_req,
		 
		 phy_reg_addr,
		 phy_reg_data,
		 req_spd,
		 // outputs
		 won,
		 lost,
		 lreq
);

// system inputs
input reset_n;
input sclk;

// inputs
input fair_req;
input pri_req;
input imm_req;
input iso_req;
input rd_req;
input wr_req;
input ctl;

input [0:3] phy_reg_addr;
input [0:7] phy_reg_data;
input [0:1] req_spd;
    
// outputs
output won;
output lost;
output lreq;

reg    won, lost;

// ctl pin encodings
// encoding when PHY has control
parameter CTL_IDLE         = 2'b00;
parameter CTL_PHY_STATUS   = 2'b01;
parameter CTL_PHY_RECEIVE  = 2'b10;
parameter CTL_PHY_TRANSMIT = 2'b11;

// link request states encodings
`ifdef ONE_HOT_ENCODING
`else
parameter LINKREQ_IDLE          = 4'b0000;  //R0
parameter LINKREQ_REQ           = 4'b0001;  //R1
parameter LINKREQ_LOST          = 4'b0010;  //R2
parameter LINKREQ_WAIT          = 4'b0011;  //R3
parameter LINKREQ_WON           = 4'b0100;  //R4
parameter LINKREQ_IMMREQBUSY    = 4'b0101;  //R5
parameter LINKREQ_IMMREQIDLE    = 4'b0110;  //R6
parameter LINKREQ_WAITBUSY      = 4'b0111;  //R7
parameter LINKREQ_WAITIMM       = 4'b1000;  //R8
parameter LINKREQ_RWREQ         = 4'b1001;  //R9

reg [3:0] linkreq_cs, linkreq_ns;
`endif

wire       req_sent;
reg [4:0]  shift_len, shift_cntr;  //request stream length and counter
reg [0:16] shift_reg_pin;  //shift register parrellel load data
reg [0:16] shift_reg;      //shift register
reg        shift_load, shift_en;


always @ (fair_req or pri_req or imm_req or 
	  iso_req or rd_req or wr_req) begin
    if (fair_req | pri_req | imm_req | iso_req) begin
	//bus request
	shift_reg_pin[0] = 1'b1; //start bit
	if (fair_req)
	    shift_reg_pin[1:3] = 3'b011;
	else if (pri_req)
	    shift_reg_pin[1:3] = 3'b010;
	else if (imm_req)
	    shift_reg_pin[1:3] = 3'b000;
	else //iso_req
	    shift_reg_pin[1:3] = 3'b001;

	shift_reg_pin[4:5] = req_spd;
	shift_reg_pin[6]   = 1'b0; //stop bit
	
	shift_len = 5'b00111;      //7 bits
    end
    else if (rd_req) begin
	//read request
	shift_reg_pin[0]   = 1'b1;   //start bit
	shift_reg_pin[1:3] = 3'b100; //read request
	shift_reg_pin[4:7] = phy_reg_addr; //PHY register address
	shift_reg_pin[8]   = 1'b0;   //stop bit

	shift_len = 5'b01001;        //9 bits
    end
    else begin
	//write request
	shift_reg_pin[0]    = 1'b1;   //start bit
	shift_reg_pin[1:3]  = 3'b101; //write request
	shift_reg_pin[4:7]  = phy_reg_addr; //PHY register address
	shift_reg_pin[8:15] = phy_reg_data; //PHY register data
	shift_reg_pin[16]   = 1'b0;   //stop bit

	shift_len = 5'b10001;  //17 bits
    end
end

assign req_sent = ~(&shift_cntr);

// combinatorial part of the link request state machine
always @ (linkreq_cs or fair_req or pri_req or imm_req or 
	  iso_req or rd_req or wr_req or req_sent or ctl) begin
    // default assignments
    won = 1'b0;
    lost = 1'b0;
    shift_en = 1'b0;
    shift_load = 1'b0;

    case (linkreq_cs)
      LINKREQ_IDLE: begin //R0
	  // outputs
	  shift_load = 1'b1;

	  // state transitions
          if ((ctl == CTL_IDLE) && (fair_req || pri_req))
	      linkreq_ns = LINKREQ_REQ;
	  else if ((ctl != CTL_IDLE) && (imm_req || iso_req))
	      linkreq_ns = LINKREQ_IMMREQBUSY;
	  else if ((ctl == CTL_IDLE) && (imm_req || iso_req))
	      linkreq_ns = LINKREQ_IMMREQIDLE;
	  else begin
	      linkreq_ns = LINKREQ_IDLE;
	      shift_load = 1'b0;
	  end
      end
      LINKREQ_REQ: begin //R1
	  // outputs
	  shift_en = 1'b1;

	  // state transitions
	  if (ctl == CTL_PHY_RECEIVE)
	      linkreq_ns = LINKREQ_LOST;
	  else if (req_sent)
	      linkreq_ns = LINKREQ_WAIT;
	  else
	      linkreq_ns = LINKREQ_REQ;
      end
      LINKREQ_LOST: begin //R2
	  // outputs
	  lost = 1'b1;

	  // state transitions
	  if (req_sent)
	      linkreq_ns = LINKREQ_IDLE;
	  else
	      linkreq_ns = LINKREQ_LOST;
      end
      LINKREQ_WAIT: begin //R3
	  // default outputs
	  // state transitions
	  if (ctl == CTL_PHY_RECEIVE)
	      linkreq_ns = LINKREQ_LOST;
	  else if (ctl == CTL_PHY_TRANSMIT)
	      linkreq_ns = LINKREQ_WON;
	  else
	      linkreq_ns = LINKREQ_WAIT;
      end
      LINKREQ_WON: begin //R4
	  // outputs
	  won = 1'b1;

	  // state transitions
	  if ((ctl == CTL_IDLE) && (fair_req || pri_req))
	      linkreq_ns = LINKREQ_IDLE;
	  else
	      linkreq_ns = LINKREQ_WON;
      end
      LINKREQ_IMMREQBUSY: begin //R5
	  // outputs
	  shift_en = 1'b1;

	  // state transitions
	  if ((ctl == CTL_IDLE) && req_sent)
	      linkreq_ns = LINKREQ_WAITBUSY;
	  else if (ctl == CTL_IDLE)
	      linkreq_ns = LINKREQ_IMMREQIDLE;
	  else
	      linkreq_ns = LINKREQ_IMMREQBUSY;
      end //LINKREQ_IMMREQIDLE
      
      LINKREQ_IMMREQIDLE: begin //R6
	  // outputs
	  shift_en = 1'b1;

	  // state transitions
	  if (req_sent)
	      linkreq_ns = LINKREQ_WAITIMM;
	  else
	      linkreq_ns = LINKREQ_IMMREQIDLE;

      end //LINKREQ_IMMREQIDLE

      LINKREQ_WAITBUSY: begin //R7
	  // default outputs

	  // state transitions
	  if (ctl == CTL_IDLE)
	      linkreq_ns = LINKREQ_WAITIMM;
	  else
	      linkreq_ns = LINKREQ_WAITBUSY;

      end //LINKREQ_WAITBUSY
      
      LINKREQ_WAITIMM: begin //R7
	  // default outputs

	  // state transitions
	  if (ctl == CTL_PHY_RECEIVE)
	      linkreq_ns = LINKREQ_LOST;
	  else if (ctl == CTL_PHY_TRANSMIT)
	      linkreq_ns = LINKREQ_WON;
	  else
	      linkreq_ns = LINKREQ_WAITIMM;

      end //LINKREQ_WAITIMM
    endcase
end

// flip-flops
always @ (negedge reset_n or posedge sclk) begin
    if (!reset_n) begin
	linkreq_cs <= LINKREQ_IDLE;
	shift_reg  <= {1'b0, 16'h0000};
	shift_cntr <= 5'b00111;  // default to 7 bits
    end
    else begin
	linkreq_cs <= linkreq_ns;

	if (shift_load) begin
	    shift_reg <= shift_reg_pin;
	    shift_cntr <= shift_len;
	end
	else if (shift_en) begin
	    //shift and decrement the counter
	    shift_reg = {shift_reg[1:16], 1'b0};
	    shift_cntr <= shift_cntr - 1'b1;
	end
    end
end

assign lreq = shift_reg[0];

endmodule
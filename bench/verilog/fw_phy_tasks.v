// $Id: fw_phy_tasks.v,v 1.1 2002-03-10 17:16:23 johnsonw10 Exp $
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

task phy_rcv_pkt;
input [1:0]  spd;
input pkt_len;

integer pkt_len;

reg [0:31] temp;
integer i, j, bit_delta;

begin
    @ (posedge sclk);
    //initiate recevie cycle
    phy_oe <= 1'b1;
    phy_ctl <= CTL_PHY_RECEIVE;
    phy_d   <= 8'hff;
    @ (posedge sclk);
    case (spd)
      2'b00: begin
	  phy_d[0:1] <= 2'b00;
	  phy_d[2:7] <= 6'b00_0000;
	  bit_delta <= 2;
      end
      2'b01: begin
	  phy_d[0:3] <= 4'b0100;
	  phy_d[4:7] <= 4'b0000;
	  bit_delta <= 4;	  
      end
      2'b10: begin
	  phy_d[0:7] <= 8'b0101_0000;
	  bit_delta <= 8;
      end
    endcase // case(spd)

    //send data
    for (i = 0; i < pkt_len; i = i + 1) begin
	temp <= rcv_buf[i];
	for (j = 0; j < 32; j = j + bit_delta) begin
	    @ (posedge sclk);
	    case (spd)
	      2'b00: begin
		  phy_d[0:1] <= temp[0:1];
		  phy_d[2:7] <= 6'b00_0000;
		  temp   <= {temp[2:31], 2'b00};
	      end
	      2'b01: begin
		  phy_d[0:3] <= temp[0:3];
		  phy_d[4:7] <= 4'b0000;
		  temp   <= {temp[4:31], 4'h0};
	      end
	      2'b10: begin
		  phy_d[0:7] <= temp[0:7];
		  temp   <= {temp[8:31], 8'h00};
	      end
	    endcase // case(spd)
	end //for (j = 0; j < 32; j = j + bit_delta) 
    end // (i = 0; i < pkt_len; i = i + 1)

    // go back to idle, but still dribing ctl and d bus
    @ (posedge sclk);
    phy_ctl = CTL_IDLE;
    phy_d[0:7] = 8'h00;
end
endtask // phy_rcv_pkt

task phy_status;
input [0:15] status;

reg [0:15] temp;
integer i;

begin
    temp = status;

    for (i = 0; i < 8; i = i + 1) begin
	@ (posedge sclk);
	phy_oe  <= 1'b1;
	phy_ctl <= CTL_PHY_STATUS;
	phy_d[0:1] <= temp[0:1];
	phy_d[2:7] <= 6'b00_0000;
	temp    <= {temp[2:15], 2'b00};
    end

    @ (posedge sclk);
    phy_ctl <= CTL_IDLE;
    phy_d   <= 8'h00;
	
end

endtask // phy_status
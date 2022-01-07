// ---------------------------------------------------------------------------------------------------------------------
// Copyright (c) 1986 - 2020, CAG team, Institute of AI and Robotics, Xi'an Jiaotong University. Proprietary and
// Confidential All Rights Reserved.
// ---------------------------------------------------------------------------------------------------------------------
// NOTICE: All information contained herein is, and remains the property of CAG team, Institute of AI and Robotics,
// Xi'an Jiaotong University. The intellectual and technical concepts contained herein are proprietary to CAG team, and
// may be covered by P.R.C. and Foreign Patents, patents in process, and are protected by trade secret or copyright law.
//
// This work may not be copied, modified, re-published, uploaded, executed, or distributed in any way, in any time, in
// any medium, whether in whole or in part, without prior written permission from CAG team, Institute of AI and
// Robotics, Xi'an Jiaotong University.
//
// The copyright notice above does not evidence any actual or intended publication or disclosure of this source code,
// which includes information that is confidential and/or proprietary, and is a trade secret, of CAG team.
// ---------------------------------------------------------------------------------------------------------------------
// FILE NAME  : hpu_pip_csr.svh
// DEPARTMENT : Architecture
// AUTHOR     : wenzhe
// AUTHOR'S EMAIL : venturezhao@gmail.com
// ---------------------------------------------------------------------------------------------------------------------
// Ver 1.0  2019--07--01 initial version.
// ---------------------------------------------------------------------------------------------------------------------

//`ifndef HPU_PIP_CSR_SVH
`define HPU_PIP_CSR_SVH

// -----
// Global signals
parameter int CSR_WTH = 12;
parameter int CSR_ADDR_WTH = 12;
parameter int CSR_DATA_WTH = 32;

typedef logic[CSR_ADDR_WTH-1 : 0] csr_addr_t;

// Machine Infomation Registers
// addr region: 12'hF11 ~ 12'hF16
//-------------------------
//// csr that can only read
//-------------------------
parameter CSR_ADDR_MIR_VID          = 12'hF11;
parameter CSR_ADDR_MIR_AID          = 12'hF12;
parameter CSR_ADDR_MIR_IID          = 12'hF13;
parameter CSR_ADDR_MIR_HTID         = 12'hF14;
parameter CSR_ADDR_MIR_DMID         = 12'hF15;
parameter CSR_ADDR_MIR_HPUID        = 12'hF16;

// Machine Trap Setup
// addr region: 12'h300 ~ 12'h306
//------------------------
// csr that can read and write  
//------------------------
parameter CSR_ADDR_MTPS_MSTATUS     = 12'h300;
parameter CSR_ADDR_MTPS_MISA        = 12'h301;
parameter CSR_ADDR_MTPS_MEDELEG     = 12'h302;
parameter CSR_ADDR_MTPS_MIDELEG     = 12'h303;
parameter CSR_ADDR_MTPS_MIE         = 12'h304;
parameter CSR_ADDR_MTPS_MTVEC       = 12'h305;
parameter CSR_ADDR_MTPS_MCOUNTEREN  = 12'h306;

//Machine Trap Handing 
//------------------------
//addr region: 12'h340 ~ 12'h344 
// csr that can read and write  
//------------------------
parameter CSR_ADDR_MTPH_MSCRATCH    = 12'h340;
parameter CSR_ADDR_MTPH_MEPC        = 12'h341;
parameter CSR_ADDR_MTPH_MCAUSE      = 12'h342;
parameter CSR_ADDR_MTPH_MTVAL       = 12'h343;
parameter CSR_ADDR_MTPH_MIP         = 12'h344;

//Machine Memory Protection support
//addr region: 12'h3A0 ~ 12'h3BF 
//Attention: not this version
//------------------------
// csr that can read and write  
//------------------------

//Machine Counter/Timers  
//addr region: 12'hB00 ~ 12'hB9F 
//------------------------
// csr that can read and write  
//------------------------
parameter CSR_ADDR_MCT_MCYCLE       = 12'hB00;
parameter CSR_ADDR_MCT_MINSTRET     = 12'hB02;

parameter CSR_ADDR_MCT_MHPMCNT03    = 12'hB03;
parameter CSR_ADDR_MCT_MHPMCNT04    = 12'hB04;
parameter CSR_ADDR_MCT_MHPMCNT05    = 12'hB05;
parameter CSR_ADDR_MCT_MHPMCNT06    = 12'hB06;
parameter CSR_ADDR_MCT_MHPMCNT07    = 12'hB07;
parameter CSR_ADDR_MCT_MHPMCNT08    = 12'hB08;
parameter CSR_ADDR_MCT_MHPMCNT09    = 12'hB09;
parameter CSR_ADDR_MCT_MHPMCNT10    = 12'hB0a;
parameter CSR_ADDR_MCT_MHPMCNT11    = 12'hB0b;
parameter CSR_ADDR_MCT_MHPMCNT12    = 12'hB0c;
parameter CSR_ADDR_MCT_MHPMCNT13    = 12'hB0d;
parameter CSR_ADDR_MCT_MHPMCNT14    = 12'hB0e;
parameter CSR_ADDR_MCT_MHPMCNT15    = 12'hB0f;
parameter CSR_ADDR_MCT_MHPMCNT16    = 12'hB10;
parameter CSR_ADDR_MCT_MHPMCNT17    = 12'hB11;
parameter CSR_ADDR_MCT_MHPMCNT18    = 12'hB12;
parameter CSR_ADDR_MCT_MHPMCNT19    = 12'hB13;
parameter CSR_ADDR_MCT_MHPMCNT20    = 12'hB14;
parameter CSR_ADDR_MCT_MHPMCNT21    = 12'hB15;
parameter CSR_ADDR_MCT_MHPMCNT22    = 12'hB16;
parameter CSR_ADDR_MCT_MHPMCNT23    = 12'hB17;
parameter CSR_ADDR_MCT_MHPMCNT24    = 12'hB18;
parameter CSR_ADDR_MCT_MHPMCNT25    = 12'hB19;
parameter CSR_ADDR_MCT_MHPMCNT26    = 12'hB1a;
parameter CSR_ADDR_MCT_MHPMCNT27    = 12'hB1b;
parameter CSR_ADDR_MCT_MHPMCNT28    = 12'hB1c;
parameter CSR_ADDR_MCT_MHPMCNT29    = 12'hB1d;
parameter CSR_ADDR_MCT_MHPMCNT30    = 12'hB1e;
parameter CSR_ADDR_MCT_MHPMCNT31    = 12'hB1f;

parameter CSR_ADDR_MCT_MCYCLEH      = 12'hB80;
parameter CSR_ADDR_MCT_MINSTRETH    = 12'hB82; 

parameter CSR_ADDR_MCT_MHPMCNT03H   = 12'hB83;
parameter CSR_ADDR_MCT_MHPMCNT04H   = 12'hB84;
parameter CSR_ADDR_MCT_MHPMCNT05H   = 12'hB85;
parameter CSR_ADDR_MCT_MHPMCNT06H   = 12'hB86;
parameter CSR_ADDR_MCT_MHPMCNT07H   = 12'hB87;
parameter CSR_ADDR_MCT_MHPMCNT08H   = 12'hB88;
parameter CSR_ADDR_MCT_MHPMCNT09H   = 12'hB89;
parameter CSR_ADDR_MCT_MHPMCNT10H   = 12'hB8a;
parameter CSR_ADDR_MCT_MHPMCNT11H   = 12'hB8b;
parameter CSR_ADDR_MCT_MHPMCNT12H   = 12'hB8c;
parameter CSR_ADDR_MCT_MHPMCNT13H   = 12'hB8d;
parameter CSR_ADDR_MCT_MHPMCNT14H   = 12'hB8e;
parameter CSR_ADDR_MCT_MHPMCNT15H   = 12'hB8f;
parameter CSR_ADDR_MCT_MHPMCNT16H   = 12'hB90;
parameter CSR_ADDR_MCT_MHPMCNT17H   = 12'hB91;
parameter CSR_ADDR_MCT_MHPMCNT18H   = 12'hB92;
parameter CSR_ADDR_MCT_MHPMCNT19H   = 12'hB93;
parameter CSR_ADDR_MCT_MHPMCNT20H   = 12'hB94;
parameter CSR_ADDR_MCT_MHPMCNT21H   = 12'hB95;
parameter CSR_ADDR_MCT_MHPMCNT22H   = 12'hB96;
parameter CSR_ADDR_MCT_MHPMCNT23H   = 12'hB97;
parameter CSR_ADDR_MCT_MHPMCNT24H   = 12'hB98;
parameter CSR_ADDR_MCT_MHPMCNT25H   = 12'hB99;
parameter CSR_ADDR_MCT_MHPMCNT26H   = 12'hB9a;
parameter CSR_ADDR_MCT_MHPMCNT27H   = 12'hB9b;
parameter CSR_ADDR_MCT_MHPMCNT28H   = 12'hB9c;
parameter CSR_ADDR_MCT_MHPMCNT29H   = 12'hB9d;
parameter CSR_ADDR_MCT_MHPMCNT30H   = 12'hB9e;
parameter CSR_ADDR_MCT_MHPMCNT31H   = 12'hB9f;

//Machine Counter Setup  
//addr region: 12'h320 ~ 12'h33F 
//------------------------
// csr that can read and write  
//------------------------
parameter CSR_ADDR_MCS_MCNTINHIBIT  = 12'h320;
parameter CSR_ADDR_MCS_MHPMEVENT03  = 12'h323;
parameter CSR_ADDR_MCS_MHPMEVENT04  = 12'h324;
parameter CSR_ADDR_MCS_MHPMEVENT05  = 12'h325;
parameter CSR_ADDR_MCS_MHPMEVENT06  = 12'h326;
parameter CSR_ADDR_MCS_MHPMEVENT07  = 12'h327;
parameter CSR_ADDR_MCS_MHPMEVENT08  = 12'h328;
parameter CSR_ADDR_MCS_MHPMEVENT09  = 12'h329;
parameter CSR_ADDR_MCS_MHPMEVENT10  = 12'h32a;
parameter CSR_ADDR_MCS_MHPMEVENT11  = 12'h32b;
parameter CSR_ADDR_MCS_MHPMEVENT12  = 12'h32c;
parameter CSR_ADDR_MCS_MHPMEVENT13  = 12'h32d;
parameter CSR_ADDR_MCS_MHPMEVENT14  = 12'h32e;
parameter CSR_ADDR_MCS_MHPMEVENT15  = 12'h32f;
parameter CSR_ADDR_MCS_MHPMEVENT16  = 12'h330;
parameter CSR_ADDR_MCS_MHPMEVENT17  = 12'h331;
parameter CSR_ADDR_MCS_MHPMEVENT18  = 12'h332;
parameter CSR_ADDR_MCS_MHPMEVENT19  = 12'h333;
parameter CSR_ADDR_MCS_MHPMEVENT20  = 12'h334;
parameter CSR_ADDR_MCS_MHPMEVENT21  = 12'h335;
parameter CSR_ADDR_MCS_MHPMEVENT22  = 12'h336;
parameter CSR_ADDR_MCS_MHPMEVENT23  = 12'h337;
parameter CSR_ADDR_MCS_MHPMEVENT24  = 12'h338;
parameter CSR_ADDR_MCS_MHPMEVENT25  = 12'h339;
parameter CSR_ADDR_MCS_MHPMEVENT26  = 12'h33a;
parameter CSR_ADDR_MCS_MHPMEVENT27  = 12'h33b;
parameter CSR_ADDR_MCS_MHPMEVENT28  = 12'h33c;
parameter CSR_ADDR_MCS_MHPMEVENT29  = 12'h33d;
parameter CSR_ADDR_MCS_MHPMEVENT30  = 12'h33e;
parameter CSR_ADDR_MCS_MHPMEVENT31  = 12'h33f;

//Debug/Trace Register  
//addr region: 12'h7a0 ~ 12'h7b5
//------------------------
// csr that can read and write  
//------------------------
parameter CSR_ADDR_DBG_TSELECT      = 12'h7a0;
parameter CSR_ADDR_DBG_TDATA1       = 12'h7a1;
parameter CSR_ADDR_DBG_TDATA2       = 12'h7a2;
parameter CSR_ADDR_DBG_TDATA3       = 12'h7a3;
parameter CSR_ADDR_DBG_TINFO        = 12'h7a4;
parameter CSR_ADDR_DBG_TCONTROL     = 12'h7a5;
parameter CSR_ADDR_DBG_MCONTEXT     = 12'h7a8;
parameter CSR_ADDR_DBG_SCONTEXT     = 12'h7aa;

parameter CSR_ADDR_DBG_DCSR         = 12'h7B0;
parameter CSR_ADDR_DBG_DPC          = 12'h7B1;
parameter CSR_ADDR_DBG_SCRATCH0     = 12'h7B2;
parameter CSR_ADDR_DBG_SCRATCH1     = 12'h7B3;
parameter CSR_ADDR_DBG_SCRATCH2     = 12'h7B4;
parameter CSR_ADDR_DBG_SCRATCH3     = 12'h7B5;

//Custom Register  
//addr region: 12'h7C0 ~ 12'h7FF 
//addr region: 12'h7c0-12h7cf   NDMA, VMU unit use
//addr region: 12'h7d0-12h7df   I $ unit use 
//addr region: 12'h7e0-12h7ef   D $ unit use
//addr region: 12'h7f0-12h7ff   L2 $ unit use
//------------------------
// csr that can read and write  
//------------------------
parameter CSR_ADDR_NDMA_CTRL        = 12'h7c0;
parameter CSR_ADDR_NDMA_STATUS      = 12'h7c1;
parameter CSR_ADDR_NDMA_LCADDR      = 12'h7c2;
parameter CSR_ADDR_NDMA_RTADDR      = 12'h7c3;
parameter CSR_ADDR_NDMA_SIZE        = 12'h7c4;
parameter CSR_ADDR_NDMA_DESTXY      = 12'h7c5;
parameter CSR_ADDR_NDMA_WR_DONE     = 12'h7c6;
parameter CSR_ADDR_NDMA_RD_DONE     = 12'h7c7;
parameter CSR_ADDR_NDMA_SWAP_DONE   = 12'h7c8;
parameter CSR_ADDR_NDMA_WR_MASK     = 12'h7c9;
parameter CSR_ADDR_NDMA_RD_MASK     = 12'h7ca;
parameter CSR_ADDR_NDMA_SWAP_MASK   = 12'h7cb;
parameter CSR_ADDR_NDMA_WR_CLR      = 12'h7cc;
parameter CSR_ADDR_NDMA_RD_CLR      = 12'h7cd;
parameter CSR_ADDR_NDMA_SWAP_CLR    = 12'h7ce;
// VMU status
parameter CSR_ADDR_VMU_STATUS       = 12'h7cf;

parameter CSR_ADDR_IC_CTRL          = 12'h7d0;
parameter CSR_ADDR_IC_STATUS        = 12'h7d1;
parameter CSR_ADDR_IC_MODEL         = 12'h7d2;
parameter CSR_ADDR_CUSTOM1_I3       = 12'h7d3;
parameter CSR_ADDR_CUSTOM1_I4       = 12'h7d4;
parameter CSR_ADDR_CUSTOM1_I5       = 12'h7d5;
parameter CSR_ADDR_CUSTOM1_I6       = 12'h7d6;
parameter CSR_ADDR_CUSTOM1_I7       = 12'h7d7;
parameter CSR_ADDR_CUSTOM1_I8       = 12'h7d8;
parameter CSR_ADDR_CUSTOM1_I9       = 12'h7d9;
parameter CSR_ADDR_CUSTOM1_Ia       = 12'h7da;
parameter CSR_ADDR_CUSTOM1_Ib       = 12'h7db;
parameter CSR_ADDR_CUSTOM1_Ic       = 12'h7dc;
parameter CSR_ADDR_CUSTOM1_Id       = 12'h7dd;
parameter CSR_ADDR_CUSTOM1_Ie       = 12'h7de;
parameter CSR_ADDR_CUSTOM1_If       = 12'h7df;

parameter CSR_ADDR_DC_START         = 12'h7e0;
parameter CSR_ADDR_DC_FINISH        = 12'h7e1;
parameter CSR_ADDR_DC_ADDR          = 12'h7e2;
parameter CSR_ADDR_DC_MODEL         = 12'h7e3;
parameter CSR_ADDR_CUSTOM2_D4       = 12'h7e4;
parameter CSR_ADDR_CUSTOM2_D5       = 12'h7e5;
parameter CSR_ADDR_CUSTOM2_D6       = 12'h7e6;
parameter CSR_ADDR_CUSTOM2_D7       = 12'h7e7;
parameter CSR_ADDR_CUSTOM2_D8       = 12'h7e8;
parameter CSR_ADDR_CUSTOM2_D9       = 12'h7e9;
parameter CSR_ADDR_CUSTOM2_Da       = 12'h7ea;
parameter CSR_ADDR_CUSTOM2_Db       = 12'h7eb;
parameter CSR_ADDR_CUSTOM2_Dc       = 12'h7ec;
parameter CSR_ADDR_CUSTOM2_Dd       = 12'h7ed;
parameter CSR_ADDR_CUSTOM2_De       = 12'h7ee;
parameter CSR_ADDR_CUSTOM2_Df       = 12'h7ef;

parameter CSR_ADDR_L2C_START        = 12'h7f0;
parameter CSR_ADDR_L2C_FINISH       = 12'h7f1;
parameter CSR_ADDR_L2C_ADDR_SET_WAY = 12'h7f2;
parameter CSR_ADDR_L2C_MODEL        = 12'h7f3;
parameter CSR_ADDR_CUSTOM3_L2D4     = 12'h7f4;
parameter CSR_ADDR_CUSTOM3_L2D5     = 12'h7f5;
parameter CSR_ADDR_CUSTOM3_L2D6     = 12'h7f6;
parameter CSR_ADDR_CUSTOM3_L2D7     = 12'h7f7;
parameter CSR_ADDR_CUSTOM3_L2D8     = 12'h7f8;
parameter CSR_ADDR_CUSTOM3_L2D9     = 12'h7f9;
parameter CSR_ADDR_CUSTOM3_L2Da     = 12'h7fa;
parameter CSR_ADDR_CUSTOM3_L2Db     = 12'h7fb;
parameter CSR_ADDR_CUSTOM3_L2Dc     = 12'h7fc;
parameter CSR_ADDR_CUSTOM3_L2Dd     = 12'h7fd;
parameter CSR_ADDR_CUSTOM3_L2De     = 12'h7fe;
parameter CSR_ADDR_CUSTOM3_L2Df     = 12'h7ff;
//Custom Register
// This region is reserved for VCSR
//addr region: 12'hBC0-12'hBFF 
parameter CSR_ADDR_CUSTOM7_D0       = 12'hbf0;
parameter CSR_ADDR_CUSTOM7_D1       = 12'hbf1;
parameter CSR_ADDR_CUSTOM7_D2       = 12'hbf2;
parameter CSR_ADDR_CUSTOM7_D3       = 12'hbf3;
parameter CSR_ADDR_CUSTOM7_D4       = 12'hbf4;
parameter CSR_ADDR_CUSTOM7_D5       = 12'hbf5;
parameter CSR_ADDR_CUSTOM7_D6       = 12'hbf6;
parameter CSR_ADDR_CUSTOM7_D7       = 12'hbf7;
parameter CSR_ADDR_CUSTOM7_D8       = 12'hbf8;
parameter CSR_ADDR_CUSTOM7_D9       = 12'hbf9;
parameter CSR_ADDR_CUSTOM7_Da       = 12'hbfa;
parameter CSR_ADDR_CUSTOM7_Db       = 12'hbfb;
parameter CSR_ADDR_CUSTOM7_Dc       = 12'hbfc;
parameter CSR_ADDR_CUSTOM7_Dd       = 12'hbfd;
parameter CSR_ADDR_CUSTOM7_De       = 12'hbfe;
parameter CSR_ADDR_CUSTOM7_Df       = 12'hbff;

// USER mode Machine Counter/Timers  
//addr region: 12'hC00 ~ 12'hC9F 
//------------------------
// csr that can read and write  
//------------------------
parameter CSR_ADDR_MCT_CYCLE       = 12'hC00;
parameter CSR_ADDR_MCT_TIME        = 12'hC01;
parameter CSR_ADDR_MCT_INSTRET     = 12'hC02;

parameter CSR_ADDR_MCT_HPMCNT03    = 12'hC03;
parameter CSR_ADDR_MCT_HPMCNT04    = 12'hC04;
parameter CSR_ADDR_MCT_HPMCNT05    = 12'hC05;
parameter CSR_ADDR_MCT_HPMCNT06    = 12'hC06;
parameter CSR_ADDR_MCT_HPMCNT07    = 12'hC07;
parameter CSR_ADDR_MCT_HPMCNT08    = 12'hC08;
parameter CSR_ADDR_MCT_HPMCNT09    = 12'hC09;
parameter CSR_ADDR_MCT_HPMCNT10    = 12'hC0a;
parameter CSR_ADDR_MCT_HPMCNT11    = 12'hC0b;
parameter CSR_ADDR_MCT_HPMCNT12    = 12'hC0c;
parameter CSR_ADDR_MCT_HPMCNT13    = 12'hC0d;
parameter CSR_ADDR_MCT_HPMCNT14    = 12'hC0e;
parameter CSR_ADDR_MCT_HPMCNT15    = 12'hC0f;
parameter CSR_ADDR_MCT_HPMCNT16    = 12'hC10;
parameter CSR_ADDR_MCT_HPMCNT17    = 12'hC11;
parameter CSR_ADDR_MCT_HPMCNT18    = 12'hC12;
parameter CSR_ADDR_MCT_HPMCNT19    = 12'hC13;
parameter CSR_ADDR_MCT_HPMCNT20    = 12'hC14;
parameter CSR_ADDR_MCT_HPMCNT21    = 12'hC15;
parameter CSR_ADDR_MCT_HPMCNT22    = 12'hC16;
parameter CSR_ADDR_MCT_HPMCNT23    = 12'hC17;
parameter CSR_ADDR_MCT_HPMCNT24    = 12'hC18;
parameter CSR_ADDR_MCT_HPMCNT25    = 12'hC19;
parameter CSR_ADDR_MCT_HPMCNT26    = 12'hC1a;
parameter CSR_ADDR_MCT_HPMCNT27    = 12'hC1b;
parameter CSR_ADDR_MCT_HPMCNT28    = 12'hC1c;
parameter CSR_ADDR_MCT_HPMCNT29    = 12'hC1d;
parameter CSR_ADDR_MCT_HPMCNT30    = 12'hC1e;
parameter CSR_ADDR_MCT_HPMCNT31    = 12'hC1f;

parameter CSR_ADDR_MCT_CYCLEH      = 12'hC80;
parameter CSR_ADDR_MCT_TIMEH       = 12'hC81;
parameter CSR_ADDR_MCT_INSTRETH    = 12'hC82; 

parameter CSR_ADDR_MCT_HPMCNT03H   = 12'hC83;
parameter CSR_ADDR_MCT_HPMCNT04H   = 12'hC84;
parameter CSR_ADDR_MCT_HPMCNT05H   = 12'hC85;
parameter CSR_ADDR_MCT_HPMCNT06H   = 12'hC86;
parameter CSR_ADDR_MCT_HPMCNT07H   = 12'hC87;
parameter CSR_ADDR_MCT_HPMCNT08H   = 12'hC88;
parameter CSR_ADDR_MCT_HPMCNT09H   = 12'hC89;
parameter CSR_ADDR_MCT_HPMCNT10H   = 12'hC8a;
parameter CSR_ADDR_MCT_HPMCNT11H   = 12'hC8b;
parameter CSR_ADDR_MCT_HPMCNT12H   = 12'hC8c;
parameter CSR_ADDR_MCT_HPMCNT13H   = 12'hC8d;
parameter CSR_ADDR_MCT_HPMCNT14H   = 12'hC8e;
parameter CSR_ADDR_MCT_HPMCNT15H   = 12'hC8f;
parameter CSR_ADDR_MCT_HPMCNT16H   = 12'hC90;
parameter CSR_ADDR_MCT_HPMCNT17H   = 12'hC91;
parameter CSR_ADDR_MCT_HPMCNT18H   = 12'hC92;
parameter CSR_ADDR_MCT_HPMCNT19H   = 12'hC93;
parameter CSR_ADDR_MCT_HPMCNT20H   = 12'hC94;
parameter CSR_ADDR_MCT_HPMCNT21H   = 12'hC95;
parameter CSR_ADDR_MCT_HPMCNT22H   = 12'hC96;
parameter CSR_ADDR_MCT_HPMCNT23H   = 12'hC97;
parameter CSR_ADDR_MCT_HPMCNT24H   = 12'hC98;
parameter CSR_ADDR_MCT_HPMCNT25H   = 12'hC99;
parameter CSR_ADDR_MCT_HPMCNT26H   = 12'hC9a;
parameter CSR_ADDR_MCT_HPMCNT27H   = 12'hC9b;
parameter CSR_ADDR_MCT_HPMCNT28H   = 12'hC9c;
parameter CSR_ADDR_MCT_HPMCNT29H   = 12'hC9d;
parameter CSR_ADDR_MCT_HPMCNT30H   = 12'hC9e;
parameter CSR_ADDR_MCT_HPMCNT31H   = 12'hC9f;

// Hardware Performance Monitor
// -- Instruction commit events
parameter EXCP_TAKEN = 8;
parameter LD_RETIRED = 9;
parameter ST_RETIRED = 10;
parameter ATM_RETIRED = 11;
parameter SYSC_RETIRED = 12;
parameter ARTH_RETIRED = 13;
parameter BR_RETIRED = 14;
parameter JAL_RETIRED = 15;
parameter JALR_RETIRED = 16;
parameter MUL_RETIRED = 17;
parameter DIV_RETIRED = 18;
parameter VEC_RETIRED = 26;
parameter VCSR_RETIRED = 27;
parameter MTX_RETIRED = 28;
// -- Micro-architectural events
parameter BID_MISP = 13;
parameter JBR_MISP = 14;
parameter CSR_FLUSH = 15;
parameter MISC_FLUSH = 16;

// Memory map
parameter LCM_TIME = 32'h0200_0000;
parameter LCM_TIMEH = 32'h0200_0004;
parameter LCM_TIMECMP = 32'h0200_0008;
parameter LCM_TIMECMPH = 32'h0200_000c;
parameter LCM_CSIP = 32'h0200_0010;

parameter LCM_DEBUG_START = 32'h0000_0338;

typedef enum logic [1 : 0] {
    MODE_DIRECT = 0,
    MODE_VECTORED
} mtvec_mode_e;

typedef enum logic [4 : 0] {
    INST_ADDR_MISALIGNED = 'h0,
    INST_ACCESS_FAULT = 'h1,
    ILLEGAL_INST = 'h2,
    BREAK_POINT = 'h3,
    LD_ADDR_MISALIGNED = 'h4,
    LD_ACCESS_FAULT = 'h5,
    ST_AMO_ADDR_MISALIGNED = 'h6,
    ST_AMO_ACCESS_FAULT = 'h7,
    ENV_CALL_FROM_U_MODE = 'h8,
    ENV_CALL_FROM_S_MODE = 'h9,
    ENV_CALL_FROM_H_MODE = 'ha,
    ENV_CALL_FROM_M_MODE = 'hb,
    INST_PAGE_FAULT = 'hc,
    LD_PAGE_FAULT = 'hd,
    ST_AMO_PAGE_FAULT = 'hf
} excp_e;

typedef enum logic [4 : 0] {
    SOFTWARE_U_MODE = 'h0,
    SOFTWARE_S_MODE = 'h1,
    SOFTWARE_H_MODE = 'h2,
    SOFTWARE_M_MODE = 'h3,
    TIMER_U_MODE = 'h4,
    TIMER_S_MODE = 'h5,
    TIMER_H_MODE = 'h6,
    TIMER_M_MODE = 'h7,
    EXT_U_MODE = 'h8,
    EXT_S_MODE = 'h9,
    EXT_H_MODE = 'ha,
    EXT_M_MODE = 'hb,
    IC_MODE = 'hc,
    DC_MODE = 'hd,
    L2C_MODE = 'he,
    NDMA_MODE = 'hf,
    COP_MODE = 'h10
} intr_e;

// -----
// CSR
typedef struct packed {
    logic                       SD;
    logic[7 : 0]                rsv0;
    logic                       TSR;
    logic                       TW;
    logic                       TVM;
    logic                       MXR;
    logic                       SUM;
    logic                       MPRV;
    logic[1 : 0]                XS;
    logic[1 : 0]                FS;
    logic[1 : 0]                MPP;
    logic[1 : 0]                HPP;
    logic                       SPP;
    logic                       MPIE;
    logic                       HPIE;
    logic                       SPIE;
    logic                       UPIE;
    logic                       MIE;
    logic                       HIE;
    logic                       SIE;
    logic                       UIE;
} csr_mstatus_t;

typedef struct packed {
    logic[29 : 0]               BASE;
    mtvec_mode_e                MODE;
} csr_mtvec_t;

typedef struct packed {
    logic[11 : 0]               rsv0;
    logic                       COPIP;      // bit 19
    logic                       SSWAPIP;    // bit 18
    logic                       SRDIP;      // bit 17
    logic                       SWRIP;      // bit 16
    logic                       NDMAIP;     // bit 15
    logic                       L2CIP;      // bit 14
    logic                       DCIP;       // bit 13
    logic                       ICIP;       // bit 12
    logic                       MEIP;       // bit 11
    logic                       HEIP;       // bit 10
    logic                       SEIP;       // bit 9
    logic                       UEIP;       // bit 8
    logic                       MTIP;       // bit 7
    logic                       HTIP;       // bit 6
    logic                       STIP;       // bit 5
    logic                       UTIP;       // bit 4
    logic                       MSIP;       // bit 3
    logic                       HSIP;       // bit 2
    logic                       SSIP;       // bit 1
    logic                       USIP;       // bit 0
} csr_mip_t;

typedef struct packed {
    logic[11 : 0]               rsv0;
    logic                       COPIE;      // bit 19
    logic                       SSWAPIE;    // bit 18
    logic                       SRDIE;      // bit 17
    logic                       SWRIE;      // bit 16
    logic                       NDMAIE;     // bit 15
    logic                       L2CIE;      // bit 14
    logic                       DCIE;       // bit 13
    logic                       ICIE;       // bit 12
    logic                       MEIE;       // bit 11
    logic                       HEIE;       // bit 10
    logic                       SEIE;       // bit 9
    logic                       UEIE;       // bit 8
    logic                       MTIE;       // bit 7
    logic                       HTIE;       // bit 6
    logic                       STIE;       // bit 5
    logic                       UTIE;       // bit 4
    logic                       MSIE;       // bit 3
    logic                       HSIE;       // bit 2
    logic                       SSIE;       // bit 1
    logic                       USIE;       // bit 0
} csr_mie_t;

typedef union packed {
    intr_e                      intr;
    excp_e                      excp;
} ecode_t;

typedef struct packed {
    logic                       is_intr;
    logic[25 : 0]               rsv0;
    ecode_t                     ecode;
} csr_mcause_t;

typedef struct packed {
    logic[3 : 0]                xdebugver;
    logic[11 : 0]               rsv1;
    logic                       ebreakm;
    logic                       ebreakh;
    logic                       ebreaks;
    logic                       ebreaku;
    logic                       stepie;
    logic                       stopcount;
    logic                       stoptime;
    logic[2 : 0]                cause;
    logic                       rsv0;
    logic                       mprven;
    logic                       nmip;
    logic                       step;
    logic                       prv;
} csr_dcsr_t;

typedef struct packed {
    logic                       wr_en;
    csr_addr_t                  waddr;
    data_t                      wdata;
    data_strobe_t               wstrb;
    logic                       rd_en;
    csr_addr_t                  raddr;
} csr_bus_req_t;

typedef struct packed {
    data_t                      rdata;
} csr_bus_rsp_t;

//`endif

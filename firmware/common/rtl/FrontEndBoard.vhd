-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      FrontEndBoard.vhd -
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Jeff Olsen
--      Created on: 4/20/2017 2:04:46 PM
--      Last change: JO 7/17/2017 4:15:12 PM
--
-------------------------------------------------------------------------------
-- File       : FrontEndBoardvhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-04-27
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
-- 
-- Note: Common-to-Application interface defined in HPS ESD: LCLSII-2.7-ES-0536
-- 
-------------------------------------------------------------------------------
-- This file is part of 'firmware-template'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'firmware-template', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
 
 entity FrontEndBoard is
    generic (
      TPD_G            : TPD_G,
      AXIL_BASE_ADDR_G : AXI_CONFIG_C(BOARD_INDEX_C).baseAddr,
      AXI_ERROR_RESP_G : AXI_ERROR_RESP_G
      );
    port (

-- Slave AXI-Lite Interface
      axiLiteClk         : in sl;
      axiLiteRst         : in sl;
    axiReadMaster  : in  AxiLiteReadMasterType;
    axiReadSlave   : out AxiLiteReadSlaveType;
    axiWriteMaster : in  AxiLiteWriteMasterType;
    axiWriteSlave  : out AxiLiteWriteSlaveType;
	
-- Controller IO
-- Ion Pump Control Board ADC SPI Interfaces
      I_Mon_Din : in sl;            -- Serial in from Current Mon ADC
      V_Mon_Din : in sl;             -- Serial in from Voltage Mon ADC
      P_Mon_Din : in sl;             -- Serial in from Power Mon ADC
      ADC_SClk  : in sl;             -- Clock for Monitor ADCs

-- Ion Pump Control Board ADC SPI Interfaces
      dacDout  : out  sl;              -- Serial out for Setpoint DACs
      dacSclk  : out sl;            -- Clock for the Setpoint DACs
      iProgCsN : out sl;           -- Chip Enable for Current DAC
      vProgCsN : out sl;           -- Chip Enable for Voltage DAC
      pProgCsN : out sl;            -- Chip Enable for Power DAC

-- Ion Pump Control Board Mode bits
      iMode : in sl;                 -- HVPS in Current Limit Mode
      vMode : in sl;                 -- HVPS in Voltage Limit Mode
      pMode : in sl;                  -- HVPS in Power Limit Mode

-- Ion Pump Enable
      Enable : out sl                 -- Enable HVPS
      );
end entity FrontEndBoard;

architecture Behavioral of FrontEndBoard is

  signal readMaster  : AxiLiteReadMasterType;
  signal readSlave   : AxiLiteReadSlaveType;
  signal writeMaster : AxiLiteWriteMasterType;
  signal writeSlave  : AxiLiteWriteSlaveType;
  signal axiRstL     : sl;

  -------------------------------------------------------------------------------------------------
  -- AXI Lite Config and Signals
  -------------------------------------------------------------------------------------------------

  constant NUM_AXI_MASTERS_C : natural := 7;
  constant REG_INDEX_C : natural := 0;

constant DAC_INDEX_C : natural := 1;
constant ADC_INDEX_C : natural := DAC_INDEX_C + 3;

  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    REG_INDEX_C    => (
      baseAddr           => 0 + AXI_BASE_ADDR_G,
      addrBits           => 4,
      connectivity       => X"0001"),
    DAC_INDEX_C+0    => (
      baseAddr           => DAC_INDEX_C+0 + AXI_BASE_ADDR_G,
      addrBits           => 4,
      connectivity       => X"0001"),
    DAC_INDEX_C+1    => (
      baseAddr           => DAC_INDEX_C+1 + AXI_BASE_ADDR_G,
      addrBits           => 4,
      connectivity       => X"0001"),
    DAC_INDEX_C+2   => (
      baseAddr           => DAC_INDEX_C+2 + AXI_BASE_ADDR_G,
      addrBits           => 4,
      connectivity       => X"0001"),
    ADC_INDEX_C+0    => (
      baseAddr           => ADC_INDEX_C + AXI_BASE_ADDR_G,
      addrBits           => 4,
      connectivity       => X"0001"),
    ADC_INDEX_C+1    => (
      baseAddr           => ADC_INDEX_C+1 + AXI_BASE_ADDR_G,
      addrBits           => 4,
      connectivity       => X"0001"),
    ADC_INDEX_C+2    => (
      baseAddr           => ADC_INDEX_C+2 + AXI_BASE_ADDR_G,
      addrBits           => 4,
      connectivity       => X"0001"),

  signal locAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

Begin

  type RegType is record
    aRising : slv(1 downto 0);
    bRising : slv(1 downto 0);
    Count   : slv(31 downto 0);
	 SpeedCntr	: slv(31 downto 0);
	 Speed	: slv(31 downto 0);
	 Dir   : sl;
  end record RegType;

  constant REG_INIT_C : RegType :=
    (
      aRising => (others => '0'),
      bRising => (others => '0'),
      Count   => (others => '0'),
		SpeedCntr		=> (others => '0'),
		Speed => 	 (others => '0'),
		Dir => '0'
      );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

genDacSpi : for I in 0 to 2 generate
uDacSpi : entity work.AxiSpiMaster is
   generic map (
      TPD_G             => 1 ns;
      AXI_ERROR_RESP_G  => AXI_RESP_DECERR_C;
      ADDRESS_SIZE_G    => 15;
      DATA_SIZE_G       => 8;
      MODE_G            => "WO";  -- Or "WO" (write only),  "RO" (read only)
      CPHA_G            => '0';
      CPOL_G            => '0';
      CLK_PERIOD_G      => 6.4E-9;  -- 156Mhz
      SPI_SCLK_PERIOD_G => 100.0E-6
      );
   port map (
      axiClk => axiLiteClk;
      axiRst => axiLiteRst;

      axiReadMaster  => locAxilWriteMasters(DAC_INDEX_C+I);
      axiReadSlave   => locAxilReadSlaves(DAC_INDEX_C+I);
      axiWriteMaster => locAxilWriteMasters(DAC_INDEX_C+I);
      axiWriteSlave  => locAxilWriteSlaves(DAC_INDEX_C+I);

      coreSclk  => dacSclk;
      coreSDin  => '0';
      coreSDout => dacDout
      coreCsb   : out sl
      );
genADCSpi : for I in 0 to 2 generate
uDacSpi : entity work.Max11202 is
   generic map (
      TPD_G             => 1 ns;
      AXI_ERROR_RESP_G  => AXI_RESP_DECERR_C;
      ADDRESS_SIZE_G    => 0;
      DATA_SIZE_G       => 24;
      MODE_G            => "RO";  -- Or "WO" (write only),  "RO" (read only)
      CPHA_G            => '0';
      CPOL_G            => '0';
      CLK_PERIOD_G      => 6.4E-9;  -- 156Mhz
      SCLK_PERIOD_G => 100.0E-6
      );
   port map (
      axiClk => axiLiteClk;
      axiRst => axiLiteRst;

      axiReadMaster  => locAxilWriteMasters(ADC_INDEX_C+I);
      axiReadSlave   => locAxilReadSlaves(ADC_INDEX_C+I);
      axiWriteMaster => locAxilWriteMasters(ADC_INDEX_C+I);
      axiWriteSlave  => locAxilWriteSlaves(ADC_INDEX_C+I);

      coreSclk  => adcSclk;
      coreSDin  => adcSdin

      );



end entity AxiSpiMaster;



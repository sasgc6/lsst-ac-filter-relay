-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      LsstAcFilterRelay.vhd -
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Jeff Olsen
--      Created on: 7/19/2017 1:33:09 PM
--      Last change: JO 2/6/2018 9:25:34 AM
--
-------------------------------------------------------------------------------
-- File       : LsstIonPumpCtrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-20
-- Last update: 2018-02-14
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
-------------------------------------------------------------------------------
-- This file is part of 'LSST Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LSST Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity LsstAcFilterRelay is
   generic (
      TPD_G        : time := 1 ns;
      BUILD_INFO_G : BuildInfoType);
   port (
      -- Relay Okay signal --
      relOK      : out   slv(11 downto 0) := "000000000000"; --
      
      -- SN65HVD1780QDRQ1 interface (RS485 transceiver) --
      rec_Data   : in    sl; --
      rec_En     : in    sl; --
      driver_En  : in    sl; --
      driver_Data : in    sl; --
      
      
      -- Boot Memory Ports
      bootCsL    : out   sl;
      bootMosi   : out   sl;
      bootMiso   : in    sl;

      -- 1GbE Ports
      ethClkP    : in    sl;
      ethClkN    : in    sl;
      ethRxP     : in    sl;
      ethRxN     : in    sl;
      ethTxP     : out   sl;
      ethTxN     : out   sl;
      -- XADC Ports
      vPIn       : in    sl;
      vNIn       : in    sl);
end LsstAcFilterRelay;

architecture top_level of LsstAcFilterRelay is

   constant SYS_CLK_FREQ_C   : real                                         := 156.0E+6;
   constant AXI_CONFIG_C     : AxiLiteCrossbarMasterConfigArray(6 downto 0) := genAxiLiteConfig(7, x"0000_0000", 22, 18);
   constant PDU5V_INDEX_C    : natural                                      := 1;

   signal axilClk          : sl;
   signal axilRst          : sl;
   signal axilWriteMasters : AxiLiteWriteMasterArray(6 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(6 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(6 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(6 downto 0);

begin

   ---------------------
   -- Common Core Module
   ---------------------
   U_Core : entity work.LsstPwrCtrlCore
      generic map (
         TPD_G        => TPD_G,
         BUILD_INFO_G => BUILD_INFO_G)
      port map (
         -- Register Interface
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMasters  => axilReadMasters,
         axilReadSlaves   => axilReadSlaves,
         axilWriteMasters => axilWriteMasters,
         axilWriteSlaves  => axilWriteSlaves,
         -- Misc.
         extRstL          => '1',
         -- XADC Ports
         vPIn             => vPIn,
         vNIn             => vNIn,
         -- Boot Memory Ports
         bootCsL          => bootCsL,
         bootMosi         => bootMosi,
         bootMiso         => bootMiso,
         -- 1GbE Interface
         ethClkP          => ethClkP,
         ethClkN          => ethClkN,
         ethRxP           => ethRxP,
         ethRxN           => ethRxN,
         ethTxP           => ethTxP,
         ethTxN           => ethTxN);

   ----------------------------------
   -- Terminate Unused AXI-Lite buses
   ----------------------------------
   GEN_VEC :
   for i in 6 downto 2 generate

      U_AxiLiteEmpty : entity work.AxiLiteEmpty
         generic map (
            TPD_G => TPD_G)
         port map (
            axiClk         => axilClk,
            axiClkRst      => axilRst,
            axiReadMaster  => axilReadMasters(i),
            axiReadSlave   => axilReadSlaves(i),
            axiWriteMaster => axilWriteMasters(i),
            axiWriteSlave  => axilWriteSlaves(i));

   end generate GEN_VEC;


   ---------------------------------
   -- AXI-Lite: Lsst Ac Filter Relay Application
   ---------------------------------
   U_App : entity work.LsstAcFilterRelayApp
      generic map (
         TPD_G           => TPD_G,
         AXI_CLK_FREQ_C  => SYS_CLK_FREQ_C,
         AXI_BASE_ADDR_G => AXI_CONFIG_C(PDU5V_INDEX_C).baseAddr)
      port map (
         -- AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(PDU5V_INDEX_C),
         axilReadSlave   => axilReadSlaves(PDU5V_INDEX_C),
         axilWriteMaster => axilWriteMasters(PDU5V_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(PDU5V_INDEX_C),

        -- Relay Okay signals
         relOK           => relOK,      --relay Okay signal to 

         -- SN65HVD1780QDRQ1 interface (RS485 transceiver)
         rec_Data        => rec_Data,
         rec_En          => rec_En,
         driver_En       => driver_En,
         driver_Data     => driver_Data

         ); 

end top_level;
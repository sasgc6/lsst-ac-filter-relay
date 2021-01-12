-------------------------------------------------------------------------------
-- File       : LSStACFilterRelay.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-02-28
-- Last update: 2018-06-22
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lsst_pwr_ctrl_core;

library unisim;
use unisim.vcomponents.all;

entity LsstAcFilterRelay is
   generic (
      TPD_G        : time := 1 ns;
      BUILD_INFO_G : BuildInfoType);
   port (
      -- Relay Okay signal
      relOK      : out slv(11 downto 0);
      -- SN65HVD1780QDRQ1 interface (RS485 transceiver)
      recData    : in  sl;
      recEn      : out sl;
      driverData : out sl;
      driverEn   : out sl;
      -- 1GbE Ports
      ethClkP    : in  sl;
      ethClkN    : in  sl;
      ethRxP     : in  sl;
      ethRxN     : in  sl;
      ethTxP     : out sl;
      ethTxN     : out sl;
      -- Boot Memory Ports
      bootCsL    : out sl;
      bootMosi   : out sl;
      bootMiso   : in  sl;
      bootWpL    : out sl;
      bootHdL    : out sl;
      -- XADC Ports
      vPIn       : in  sl;
      vNIn       : in  sl;
      --Reset Chip
      mReset     : in  sl);
end LsstAcFilterRelay;

architecture top_level of LsstAcFilterRelay is

   constant SYS_CLK_FREQ_C : real                                         := 125.0E+6;
   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(6 downto 0) := genAxiLiteConfig(7, x"0000_0000", 22, 18);
   constant RELAY_INDEX_C  : natural                                      := 0;

   signal axilClk          : sl;
   signal axilRst          : sl;
   signal axilWriteMasters : AxiLiteWriteMasterArray(6 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(6 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(6 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(6 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);

   signal mbDataTx      : slv(47 downto 0);
   signal responseData  : slv(255 downto 0);
   signal responseValid : sl;
   signal transmitValid : sl;
   signal transmitReady : sl;
   signal errorCode     : slv(7 downto 0);
   signal mycounter     : slv(31 downto 0);

begin

   ---------------------
   -- Common Core Module
   ---------------------
   U_Core : entity lsst_pwr_ctrl_core.LsstPwrCtrlCore
      generic map (
         TPD_G        => TPD_G,
         BUILD_INFO_G => BUILD_INFO_G)
      port map (
         -- Register Interface
         axilClk          => axilClk,           --[out]
         axilRst          => axilRst,           --[out]
         axilReadMasters  => axilReadMasters,   --[out]
         axilReadSlaves   => axilReadSlaves,    --[in]
         axilWriteMasters => axilWriteMasters,  --[out]
         axilWriteSlaves  => axilWriteSlaves,   --[in]
         -- Misc.
         extRstL          => '1',               --[in]
         -- XADC Ports
         vPIn             => vPIn,              --[in]
         vNIn             => vNIn,              --[in]
         -- Boot Memory Ports
         bootCsL          => bootCsL,
         bootMosi         => bootMosi,
         bootMiso         => bootMiso,
         bootWpL          => bootWpL,
         bootHdL          => bootHdL,
         -- 1GbE Interface
         ethClkP          => ethClkP,           --[in]
         ethClkN          => ethClkN,           --[in]
         ethRxP(0)        => ethRxP,            --[in]
         ethRxN(0)        => ethRxN,            --[in]
         ethTxP(0)        => ethTxP,            --[out]
         ethTxN(0)        => ethTxN);           --[out]

   ---------------------------
   -- Relay register
   ---------------------------  
   U_RelayReg : entity work.RelayReg
      generic map(
         TPD_G => TPD_G)
      port map (
         -- Slave AXI-Lite Interface
         axilClk         => axilClk,              --[in]
         axilRst         => axilRst,              --[in]
         axilReadMaster  => axilReadMasters(1),   --[in]
         axilReadSlave   => axilReadSlaves(1),    --[out]
         axilWriteMaster => axilWriteMasters(1),  --[in]
         axilWriteSlave  => axilWriteSlaves(1),   --[out]
         -- Relay Control    
         relOK           => relOK);               --[out]

   ---------------------------
   -- CurrentSense register
   ---------------------------  
   U_CurrentSenseReg : entity work.CurrentSenseReg
      generic map(
         TPD_G => TPD_G)
      port map (
         mycounter       => mycounter,            --[out]
         -- Slave AXI-Lite Interface
         axilClk         => axilClk,              --[in]
         axilRst         => axilRst,              --[in]
         axilReadMaster  => axilReadMasters(2),   --[in]
         axilReadSlave   => axilReadSlaves(2),    --[out]
         axilWriteMaster => axilWriteMasters(2),  --[in]
         axilWriteSlave  => axilWriteSlaves(2),   --[out]
         -- RX Interface
         rxValid         => responseValid,        --[in]
         rxData          => responseData,         --[in]
         -- TX Interface
         txValid         => transmitValid,        --[out]
         txData          => mbDataTx,             --[out]
         txReady         => transmitReady,        --[in]
         -- error message
         errorCode       => errorCode);           --[in]

   -----------------------------------------------------------
   -- NON-AXI entity
   ----------------------------------------------------------- 
   U_ModbusRTU : entity work.ModbusRTU
      generic map (
         TPD_G => TPD_G)
      port map (
         clk => axilClk,                -- [in]
         rst => axilRst,                -- [in]

         mycounter => mycounter,        -- [out]
         -- SN65HVD1780QDRQ1 interface (RS485 transceiver) --
         rx        => recData,          --[in]
         rx_En     => recEn,            --[out]
         tx        => driverData,       --[out]
         tx_En     => driverEn,         --[out]

         -- Mobus Data --    
         wrData  => mbDataTx,           --[in]
         wrValid => transmitValid,      --[in]
         wrReady => transmitReady,      --[out]

         rdReady => '1',  --[in]    --- still need to work on this

         errorCode => errorCode,        --[out]
         rdData    => responseData,     --[out]
         rdValid   => responseValid);   --[out]

end top_level;

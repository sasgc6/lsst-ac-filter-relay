#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : 
#-----------------------------------------------------------------------------
# File       : TopLevel.py
# Created    : 2017-04-03
#-----------------------------------------------------------------------------
# Description:
# 
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import LsstPwrCtrlCore as base
  
class Fpga(pr.Device):
    def __init__(self, 
                 name        = "Fpga",
                 description = "Device Memory Mapping",
                 **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        coreStride = 0x40000 
        appStride  = 0x1000 
        
        # Add Core device
        self.add(base.Core())            
        
        # Add User devices
        self.add(CtrlReg(
            name    = 'Registers',
            offset  = (1*coreStride)+ (appStride * 0),
            expand  = False,
        ))

        for i in range(20):
            self.add(Monitor(
                name   = ('Monitor[%d]' % i),
                offset = (1*coreStride) + (appStride * (1+i)),
                expand = False,
            ))        
        
class Monitor(pr.Device):
    def __init__(self, 
                 name        = "Monitor",
                 description = "Container for Monitor",
                 **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        self.add(pr.RemoteCommand(   
            name         = 'ADCReadStart',
            description  = '',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            function     = lambda cmd: cmd.post(1)
        ))        
        
        self.add(pr.RemoteVariable(
            name    = 'Control',
            offset  = 0x0,
            mode    = 'RW',
        ))
        self.add(pr.RemoteVariable(
            name    = 'Alert',
            offset  = 0x4,
            mode    = 'RW',
        ))
        self.add(pr.RemoteVariable(
            name    = 'Status',
            offset  = 0x8,
            mode    = 'RW',          
        ))
        self.add(pr.RemoteVariable(
            name    = 'Fault',
            offset  = 0xC,
            mode    = 'RW',            
        ))
        self.add(pr.RemoteVariable(
            name    = 'FaultClr',
            offset  = 0x10,
            mode    = 'RW',            
        ))
        self.add(pr.RemoteVariable(
            name    = 'Power',
            offset  = 0x14,
            mode    = 'RW',            
        ))
        self.add(pr.LinkVariable(
            name = 'PowerReal',
            mode = 'RO',
            units = 'watts',
            variable = self.Power,
            linkedGet = lambda raw = self.Power: (raw.value() * 10.48) / 16777216.0 / 0.02,
            disp = '{:1.3f}',
        ))    
        self.add(pr.RemoteVariable(
            name    = 'MaxPower',
            offset  = 0x18,
            mode    = 'RW',            
        ))          
        self.add(pr.RemoteVariable(
            name    = 'MinPower',
            offset  = 0x1C,
            mode    = 'RW',            
        ))                 
        self.add(pr.RemoteVariable(
            name    = 'MaxPowerThreshold',
            offset  = 0x20,
            mode    = 'RW',            
        ))    
        self.add(pr.RemoteVariable(
            name    = 'MinPowerThreshold',
            offset  = 0x24,
            mode    = 'RW',            
        ))  
        self.add(pr.RemoteVariable(
            name    = 'Sense',
            offset  = 0x28,
            mode    = 'RW',            
        ))
        self.add(pr.LinkVariable(
            name = 'Current',
            mode = 'RO',
            units = 'amps',
            variable = self.Sense,
            linkedGet = lambda raw = self.Sense: (raw.value() * .1024) / 4096.0 / 0.02,
            disp = '{:1.3f}',
        ))      
        self.add(pr.RemoteVariable(
            name    = 'MaxSense',
            offset  = 0x2C,
            mode    = 'RW',            
        ))    
        self.add(pr.RemoteVariable(
            name    = 'MinSense',
            offset  = 0x30,
            mode    = 'RW',            
        ))  
        self.add(pr.RemoteVariable(
            name    = 'MaxSenseThreshold',
            offset  = 0x34,
            mode    = 'RW',            
        ))    
        self.add(pr.RemoteVariable(
            name    = 'MinSenseThreshold',
            offset  = 0x38,
            mode    = 'RW',            
        ))  
        self.add(pr.RemoteVariable(
            name    = 'Vin',
            offset  = 0x3C,
            mode    = 'RW',            
        ))
        self.add(pr.LinkVariable(
            name = 'VinVolt',
            mode = 'RO',
            units = 'volts',
            variable = self.Vin,
            linkedGet = lambda raw = self.Vin: (raw.value() * 102.4) / 4096.0,
            disp = '{:1.3f}',
        ))     
        self.add(pr.RemoteVariable(
            name    = 'MaxVin',
            offset  = 0x40,
            mode    = 'RW',            
        ))  
        self.add(pr.RemoteVariable(
            name    = 'MinVin',
            offset  = 0x44,
            mode    = 'RW',            
        ))    
        self.add(pr.RemoteVariable(
            name    = 'MaxVinThreshold',
            offset  = 0x48,
            mode    = 'RW',            
        ))  
        self.add(pr.RemoteVariable(
            name    = 'MinVinThreshold',
            offset  = 0x4C,
            mode    = 'RW',            
        ))         
        self.add(pr.RemoteVariable(
            name    = 'ADin',
            offset  = 0x50,
            mode    = 'RW',            
        ))  
        self.add(pr.RemoteVariable(
            name    = 'MaxADin',
            offset  = 0x54,
            mode    = 'RW',            
        ))    
        self.add(pr.RemoteVariable(
            name    = 'MinADin',
            offset  = 0x58,
            mode    = 'RW',            
        ))  
        self.add(pr.RemoteVariable(
            name    = 'MaxADinThreshold',
            offset  = 0x5C,
            mode    = 'RW',            
        ))
        self.add(pr.RemoteVariable(
            name    = 'MinADinThreshold',
            offset  = 0x60,
            mode    = 'RW',            
        ))  
        def adcToVolt(self, read):
            raw = self.Vin.get(read)
            volt = raw * (102.4) / 4096.0
            return (volt)

class CtrlReg(pr.Device):
    def __init__(self, 
                 name        = "CtrlReg",
                 description = "Container for CtrlReg",
                 **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        self.add(pr.RemoteVariable(
            name    = 'Switch_Cntl',
            offset  = 0x0,
            mode    = 'RW',
        ))
        self.add(pr.RemoteVariable(
            name    = 'Main_On',
            offset  = 0x04,
            mode    = 'RW',
        ))
        self.add(pr.RemoteVariable(
            name    = 'Main_Status',
            offset  = 0x08,
            mode    = 'RO',
        ))
        self.add(pr.RemoteVariable(
            name    = 'Alerts',
            offset  = 0x0C,
            mode    = 'RO',
        ))
        
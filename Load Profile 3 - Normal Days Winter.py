# -*- coding: utf-8 -*-

#%% Definition of the inputs
'''
Input data definition 
'''


from ramp.core.core import User, np
User_list = []

'''
This example input file represents an whole village-scale community,
adapted from the data used for the Journal publication. It should provide a 
complete guidance to most of the possibilities ensured by RAMP for inputs definition,
including specific modular duty cycles and cooking cycles. 
For examples related to "thermal loads", see the "input_file_2".
'''

School = User("school",1,1)
User_list.append(School)

#School

S_indoor_bulb = School.Appliance(School, 60,20,1,120,0.1,120,occasional_use=0.5)
S_indoor_bulb.windows([520,880],[0,0],0.1)

S_bulb = School.Appliance(School, 30,9,1,120,0.1,120,occasional_use=0.5)
S_bulb.windows([520,880],[0,0],0.1)




S_Phone_charger = School.Appliance(School, 35,25,2,180,0.2,5,occasional_use=0.3)
S_Phone_charger.windows([530,750],[750,880],0.2)



S_Fridge = School.Appliance(School, 1,215,1,380,0.15,30, 'yes',3)
S_Fridge.windows([510,890],[0,0],0.1)
S_Fridge.specific_cycle_1(215,20,5,10)
S_Fridge.specific_cycle_2(215,15,5,15)
S_Fridge.specific_cycle_3(215,10,5,20)
S_Fridge.cycle_behaviour(cw11=[510,570],cw21=[570,630],cw31=[630,730], cw32=[730,890])

S_bathroom_bulb = School.Appliance(School, 15,5,1,60,0.15,60)
S_bathroom_bulb.windows([520,880],[0,0],0.1)

S_Motor= School.Appliance(School, 1,750,1,60,0.2,30)
S_Motor.windows([540,600],[840,900],0.1)

S_CCTV= School.Appliance(School, 4,4,1,360,0.1,360)
S_CCTV.windows([520,880],[0,0],0.1)

S_standfan= School.Appliance(School, 2,60,1,120,0.3,60)
S_standfan.windows([520,750],[750,880],0.1)

S_PC = School.Appliance(School, 1,240,2,240,0.1,90, occasional_use=0.5)
S_PC.windows([520,770],[770,880],0.1)

S_StudentsPC= School.Appliance(School, 10,360,2,80,0.1,40, occasional_use= 0.8)
S_StudentsPC.windows([520,770],[800,880],0.1)

S_Printer1 = School.Appliance(School, 1,650,2,30,0.1,5,occasional_use=0.1)
S_Printer1.windows([520,770],[770,880],0.2)

S_Printer2 = School.Appliance(School, 1,100,2,30,0.1,5,occasional_use=0.1)
S_Printer2.windows([520,770],[770,880],0.2)

S_Printer3 = School.Appliance(School, 1,465,2,30,0.1,5,occasional_use=0.1)
S_Printer3.windows([520,770],[770,880],0.2)

S_TV1 = School.Appliance(School, 1,120,2,120,0.1,60,occasional_use=0.4)
S_TV1.windows([520,770],[770,880],0.1)

S_TV2 = School.Appliance(School, 1,120,1,360,0.1,360)
S_TV2.windows([520,880],[0,0],0.1)

S_Router = School.Appliance(School, 1,20,1,360,0.1,360)
S_Router.windows([520,880],[0,0],0.1)

S_Stereo = School.Appliance(School, 3,300,2,20,0.1,10)
S_Stereo.windows([510,520],[880,890],0.05)

S_Laptopcharger= School.Appliance(School, 5,75,2,180,0.1,90)
S_Laptopcharger.windows([520,770],[770,880],0.2)

S_bell= School.Appliance(School, 1,10,1,15,0.1,15)
S_bell.windows([510,890],[0,0],0.05)

S_Projecter= School.Appliance(School, 2,600,2,160,0.1,80,occasional_use=0.5)
S_Projecter.windows([520,770],[800,880],0.1)

S_Xerox= School.Appliance(School, 1,1386,1,30,0.1,10,occasional_use=0.1)
S_Xerox.windows([520,880],[0,0],0.1)



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

S_indoor_bulb = School.Appliance(School, 5,9,1,120,0.1,120,occasional_use=0.5)
S_indoor_bulb.windows([520,880],[0,0],0.1)


S_ceilingfan= School.Appliance(School,5,35,1,300,0.2,300)
S_ceilingfan.windows([520,880],[0,0],0.1)


S_Phone_charger = School.Appliance(School, 5,25,2,180,0.2,5,occasional_use=0.3)
S_Phone_charger.windows([530,750],[750,880],0.2)



S_Fridge = School.Appliance(School, 1,50,1,380,0.15,30, 'yes',3)
S_Fridge.windows([510,890],[0,0],0.1)
S_Fridge.specific_cycle_1(50,20,5,10)
S_Fridge.specific_cycle_2(50,15,5,15)
S_Fridge.specific_cycle_3(50,10,5,20)
S_Fridge.cycle_behaviour(cw11=[510,570],cw21=[570,630],cw31=[630,730], cw32=[730,890])



S_Motor= School.Appliance(School, 1,750,1,60,0.2,30)
S_Motor.windows([540,600],[840,900],0.1)




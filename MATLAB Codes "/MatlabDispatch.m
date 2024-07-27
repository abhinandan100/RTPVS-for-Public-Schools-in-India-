function [simulation_state, matlab_simulation_variables]=MatlabDispatch(simulation_parameters, simulation_state, matlab_simulation_variables)
%First check whether the primary load available is in AC bus or DC Bus.If the primary load is only connected to AC Bus.
 if simulation_parameters.primary_loads(1).is_AC==true
    simulation_state.dc_bus.load_requested=0;
    simulation_state.dc_bus.load_served=0;
    simulation_state.dc_bus.operating_capacity_requested=(simulation_state.dc_bus.load_requested) * ( 1 + (simulation_parameters.operating_reserve.timestep_requirement/100));
    simulation_state.dc_bus.operating_capacity_served=simulation_state.dc_bus.load_requested;
    %Check if generator is installed. If generator is installed
    if simulation_parameters.has_generator==true
        %The power output coming out of the generator at a particular timestep is given by
        simulation_state.generators(1).power_setpoint= simulation_state.generators(1).power_available;
    else % If generator is not installed. Then power output from the generator at a particular time-step is zero.
        simulation_state.generators(1).power_setpoint=0;
    end 
    %Check if Wind-turbine is installed, If wind turbine is installed. 
    if simulation_parameters.has_wind_turbine==true
    %The power output coming out of the wind turbine at a particular timestep is given by
        simulation_state.wind_turbines(1).power_setpoint=simulation_state.wind_turbines(1).power_available;
    else
      %The power output coming out of the wind turbine at a particular time-step is zero
        simulation_state.wind_turbines(1).power_setpoint=0;
    end 
    % Check if flywheel is intalled. If the flywheel is installed.
    if simulation_parameters.has_flywheel==true;
        % Then the flywheel will also be able to served load
        simulation_state.flywheels(1).load_served=simulation_state.ac_bus.load_requested;
    else
        % The flywheel will not be able to served load
        simulation_state.flywheels(1).load_served=0;
    end
    %Check if there is pv panel is installed.If pv is installed 
    if simulation_parameters.has_pv==true
           % Also check if pv panel is installed in the ac bus or dc bus. If pv panel is connected with ac bus.
           %The power out from the pv panel at a particular time-step is equal to whatever power is available at the pv panel.
           simulation_state.pvs(1).power_setpoint=simulation_state.pvs(1).power_available;
           %Primary load load requested is the ac bus load requested
           pv_derating_factor=0.65;
           simulation_state.primary_loads.load_requested = simulation_state.ac_bus.load_requested-simulation_state.grids(1).grid_sales;
           %Setting AC_Bus_Load_Operating_capacity equal to load * (1 + reserve requirement)
          simulation_state.ac_bus.operating_capacity_requested = (simulation_state.ac_bus.load_requested) * (1 + (simulation_parameters.operating_reserve.timestep_requirement/100)); 
           if simulation_parameters.pvs(1).is_AC==true
                %Then there will be no need for converter.
                simulation_parameters.has_converter=false;
                % Since there is no converter, so there will be no inverter, Hence, inverter power input will be zero.
                simulation_state.converters(1).inverter_power_input=0;
                % The inverter power output will also be zero
                simulation_state.converters(1).inverter_power_output=0; 
           else  % If pv  panel is connected with dc bus which is the current scenario 
               %Then converter must be available to invert the current to ac or vice versa.
               simulation_parameters.has_converter=true;
               %Since converter is available , so it will have its parameters and specifications.We are considering abi-directional converter here which can invert and recitify.
               simulation_state.dc_bus.operating_capacity_requested=(simulation_state.pvs(1).power_setpoint) * ( 1 + (simulation_parameters.operating_reserve.timestep_requirement/100));
               simulation_state.dc_bus.operating_capacity_served=simulation_state.dc_bus.operating_capacity_requested;
               %The inverter capacity is equal to:
               simulation_parameters.converters(1).inverter_capacity=24;
               %The rectifier capacity is equal to:
               simulation_parameters.converters(1).rectifier_capacity=24;
               %The inverter efficiency is equal to:
               simulation_parameters.converters(1).inverter_efficiency= 97;
               %The rectifier capacity is equal to :
               simulation_parameters.converters(1).rectifier_efficiency= 97.5;
               simulation_state.dc_bus.excess_electricity= simulation_state.dc_bus.load_requested-simulation_state.dc_bus.load_served;
               simulation_state.dc_bus.unmet_load= simulation_state.dc_bus.load_requested-simulation_state.dc_bus.load_served;
               %Now this power output from pv can be only provided to the load in grid-connected systems if the grid is not in outage. Hence check if the grid is in outage
               if simulation_state.grids(1).grid_state.grid_is_down==true
                  simulation_state.grids(1).max_grid_purchases=0;
                  %if grid is in outage then there will be no grid purchase
                  simulation_state.grids(1).grid_purchases=0; 	
                  % there will be no grid sales also for safety issues
                  simulation_state.grids(1).grid_sales=0;
                  %Also pv system cannot supply the load via inverter, therefore unmet load will be equal be still equal to the ac bus load as inverter power output is zero.
                  unmet_load=max(simulation_state.primary_loads.load_requested, 0);
                  % Check if the unmet load is greater than zero
                  if unmet_load>=0
                     %Since the grid is in outage, hence no recitifiers will be needed, thus rectifier input will be zero.
                     simulation_state.converters(1).rectifier_power_input=0;
                     % Similarly rectifier output will be zero.
                     simulation_state.converters(1).rectifier_power_output=0;
                     %Now check if batteries are available. If batteries are available.i.e.  
                     if simulation_parameters.has_battery==true
                        %The battery state of charge percentage at a particular time-step is equal to current energy content in the battery at this particular time-step divided
                        %by the maximum energy content of the battery multiplied by 100%.
                        if simulation_state.current_timestep == 0
                           simulation_state.batteries(1).state_of_charge_percent=100;
                        end
                        %The maximum state of charge of the battery is 100%
                        simulation_parameters.batteries(1).maximum_state_of_charge=100;
                        %The minimum state of charge of the battery is 20%
                        simulation_parameters.batteries(1).minimum_state_of_charge=20;
                        simulation_parameters.batteries(1).nominal_capacity=2.4;
                        simulation_parameters.batteries(1).fractional_charge_efficiency=sqrt(0.95);
                        simulation_parameters.batteries(1).fractional_discharge_efficiency=sqrt(0.95);
                        simulation_parameters.batteries(1).battery_bank_maximum_absolute_soc= simulation_parameters.batteries(1).nominal_capacity;
                        simulation_parameters.batteries(1).battery_bank_minimum_absolute_soc=(simulation_parameters.batteries(1).minimum_state_of_charge/100)*simulation_parameters.batteries(1).nominal_capacity;
                        
                        %The batteries can actually supply the unmet load provided its state of charge is above the minimum state of charge i.e. 20% in this case.
                        if unmet_load>min(simulation_state.batteries(1).max_discharge_power*simulation_parameters.batteries(1).fractional_discharge_efficiency*(simulation_parameters.converters(1).inverter_efficiency/100),simulation_parameters.converters(1).inverter_capacity/(simulation_parameters.converters(1).inverter_efficiency/100));
                           simulation_state.converters(1).inverter_power_input= min(simulation_state.batteries(1).max_discharge_power,simulation_parameters.converters(1).inverter_capacity/(simulation_parameters.converters(1).inverter_efficiency/100));
                           simulation_state.converters(1).inverter_power_ouput=simulation_state.converters(1).inverter_power_input*(simulation_parameters.converters(1).inverter_efficiency/100);
                           unmet_load1=unmet_load-simulation_state.converters(1).inverter_power_ouput;
                           simulation_state.batteries(1).power_setpoint = - simulation_state.converters(1).inverter_power_input;
                           simulation_state.batteries(1).state_of_charge_kwh=simulation_state.batteries(1).state_of_charge_kwh+simulation_state.batteries(1).power_setpoint;
                           simulation_state.batteries(1).state_of_charge_percent=100*simulation_state.batteries(1).state_of_charge_kwh/simulation_parameters.batteries(1).nominal_capacity;
                           simulation_state.ac_bus.unmet_load = unmet_load1;
                           simulation_state.ac_bus.excess_electricity=simulation_state.pvs(1).power_setpoint;
                           simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+ simulation_state.converters(1).inverter_power_ouput;
                           %The primary load served would have been given by the following equation
                           simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                           simulation_state.ac_bus.operating_capacity_served=max(simulation_state.grids(1).max_grid_purchases,simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output);
                        else %unmet_load<=min(simulation_state.batteries(1).max_discharge_power*simulation_parameters.batteries(1).fractional_discharge_efficiency*(simulation_parameters.converters(1).inverter_efficiency/100),simulation_parameters.converters(1).inverter_capacity/(simulation_parameters.converters(1).inverter_efficiency/100));% then Battery cannot fully serve full demand though it will supply its entire capacity, there will be still unmet load.
                           %Converter power output extraction from the battery will be given by unmet load times the inverter efficiency:
                           simulation_state.converters(1).inverter_power_input = min(unmet_load/(simulation_parameters.converters(1).inverter_efficiency/100),simulation_parameters.converters(1).inverter_capacity/(simulation_parameters.converters(1).inverter_efficiency/100));
                           simulation_state.converters(1).inverter_power_output=simulation_state.converters(1).inverter_power_input*(simulation_parameters.converters(1).inverter_efficiency/100);
                           simulation_state.batteries(1).power_setpoint = - simulation_state.converters(1).inverter_power_input;
                           simulation_state.batteries(1).state_of_charge_kwh=simulation_state.batteries(1).state_of_charge_kwh+simulation_state.batteries(1).power_setpoint;
                           simulation_state.batteries(1).state_of_charge_percent=100*simulation_state.batteries(1).state_of_charge_kwh/simulation_parameters.batteries(1).nominal_capacity;
                           simulation_state.ac_bus.unmet_load =0;
                           simulation_state.ac_bus.excess_electricity=simulation_state.pvs(1).power_setpoint;
                           simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                           %The primary load served would have been given by the following equation
                           simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                           simulation_state.ac_bus.operating_capacity_served=max(simulation_state.grids(1).max_grid_purchases,simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output);
                        end
                        if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                           %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                           simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                           %In this situation ac bus capacity shortage will be equal to zero.
                           simulation_state.dc_bus.capacity_shortage = 0;
                        else 
                           %The d.c. capacity shortage is given by:
                           simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                        end
                        %The a.c. operating capacity served is given by:
                        simulation_state.ac_bus.operating_capacity_served=max(simulation_state.grids(1).max_grid_purchases,simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output);
                        % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                        if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                           %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                           simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                           %In this situation ac bus capacity shortage will be equal to zero.
                           simulation_state.ac_bus.capacity_shortage = 0;
                        else 
                          %The a.c. capacity shortage is given by:
                          simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                        end
                                   
                     else %Simulation_parameters.has_battery==false i.e. there is no battery
                          %if grid is in outage then there will be no grid purchase
                          simulation_state.grids(1).grid_purchases=0; 	
                          % there will be no grid sales also for safety issues
                          simulation_state.grids(1).grid_sales=0;
                          %Then there will be no charging or discharging of the battery.
                          % Inverter power output is given by:
                          simulation_state.converters(1).inverter_power_output=0;
                          % Inverter power input is given by:
                          simulation_state.converters(1).inverter_power_input= simulation_state.converters(1).inverter_power_output/(simulation_parameters.converters(1).inverter_efficiency/100);
                          %If the load would have been served in this situation which is of course not possible either via pv or battery then it is given by the following equation:
                          simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+ simulation_state.converters(1).inverter_power_output;
                          %The primary load served would have been given by the following equation
                          simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                          % To prevent homer errors this below condition has to be provided.
                          simulation_state.ac_bus.unmet_load = max(unmet_load-simulation_state.converters(1).inverter_power_output,0);
                          %The a.c. operating capacity served is given by:
                          simulation_state.ac_bus.operating_capacity_served=max(simulation_state.grids(1).max_grid_purchases,simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output);
                         % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                         if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                            %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                            simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                            %In this situation ac bus capacity shortage will be equal to zero.
                            simulation_state.ac_bus.capacity_shortage = 0;
                         else 
                            %The a.c. capacity shortage is given by:
                            simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                         end
                         %The excess electricity is given by:
                         simulation_state.ac_bus.excess_electricity=max(simulation_state.pvs(1).power_setpoint-(simulation_state.primary_loads(1).load_served+simulation_state.grids(1).grid_sales),0);
                     end
                  end
               else %Else if grid is not in outage then its maximum capacity is
                    simulation_state.grids(1).max_grid_purchases=999999;
                    % First PV panel will power the demand
                    % Power output from the inverter will be minimum of
                    % either pv panel output or inverter capacity as the pv power input may be limited by inverter size
                    %The inverter capacity is equal to:
                    simulation_parameters.converters(1).inverter_capacity=24;
                    %The rectifier capacity is equal to:
                    simulation_parameters.converters(1).rectifier_capacity=24;
                    %The inverter efficiency is equal to:
                    simulation_parameters.converters(1).inverter_efficiency= 97;
                    %The rectifier capacity is equal to :
                    simulation_parameters.converters(1).rectifier_efficiency= 97.5;
                    % input to the inverter is the pv power
                    simulation_state.converters(1).inverter_power_input = simulation_state.pvs(1).power_setpoint;
                    % Power input to the inverter multiplied by its efficiency is of course the inverter output which may be limited by the maximum inverter capacity which can also be given by the following equation:
                    simulation_state.converters(1).inverter_power_output = min(simulation_state.converters(1).inverter_power_input*(simulation_parameters.converters(1).inverter_efficiency/100),simulation_parameters.converters(1).inverter_capacity);
                    %  if PV power is less than the inverter capacity the  there still will be inverter capacity remaining
                    %Check for unmet load after pv has provided its power output
                    unmet_load=max(simulation_state.primary_loads.load_requested-simulation_state.converters(1).inverter_power_output, 0);
                    %If unmet load is greater than zero, then grid will come into play
                    if unmet_load>0 
                        %then grid will be called which will supply the remaining unmet load and will also charge the battery
                        %Simulation parameters has battery
                        if simulation_parameters.has_battery==true
                            %The battery state of charge percentage at a particular time-step is equal to current energy content in the battery at this particular time-step divided
                            %by the maximum energy content of the battery multiplied by 100%.
                             if simulation_state.current_timestep == 0
                                  simulation_state.batteries(1).state_of_charge_percent=100;
                             end
                                %The maximum state of charge of the battery is 100%
                                simulation_parameters.batteries(1).maximum_state_of_charge=100;
                                %The minimum state of charge of the battery is 20%
                                simulation_parameters.batteries(1).minimum_state_of_charge=20; 
                                % The battery nominal capacity is currently 2.4 for this case
                                simulation_parameters.batteries(1).nominal_capacity=2.4;
                                % Batteries absolute state of charge in kWh is equal to its capacity
                                simulation_parameters.batteries(1).battery_bank_maximum_absolute_soc= simulation_parameters.batteries(1).nominal_capacity;
                                % Batteries absolute state of charge in kWh is equal to its minimum capacity
                                simulation_parameters.batteries(1).battery_bank_minimum_absolute_soc=(simulation_parameters.batteries(1).minimum_state_of_charge/100)*simulation_parameters.batteries(1).nominal_capacity;
                               %If battery state of charge is less than maximum state of charge
                                simulation_state.grids(1).grid_sales=0;
                                simulation_state.converters(1).rectifier_power_input=0;
                                simulation_state.converters(1).rectifier_power_output=simulation_state.converters(1).rectifier_power_input*(simulation_parameters.converters(1).rectifier_efficiency/100);
                                simulation_state.grids(1).grid_purchases=unmet_load+simulation_state.converters(1).rectifier_power_input;  % Battery can serve full demand
                                simulation_state.batteries(1).power_setpoint = simulation_state.converters(1).rectifier_power_output ;
                                simulation_state.batteries(1).state_of_charge_kwh=simulation_state.batteries(1).state_of_charge_kwh+simulation_state.batteries(1).power_setpoint;
                                simulation_state.batteries(1).state_of_charge_percent=100*simulation_state.batteries(1).state_of_charge_kwh/simulation_parameters.batteries(1).nominal_capacity;
                                % Total ac bus load served is given by:
                                simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+ simulation_state.converters(1).inverter_power_output-simulation_state.converters(1).rectifier_power_input;
                                % Total primary load served is given by:
                                simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                                % The a.c bus excess electricity
                                simulation_state.ac_bus.excess_electricity=max(simulation_state.converters(1).inverter_power_output-(simulation_state.primary_loads(1).load_served+simulation_state.grids(1).grid_sales),0); 
                                simulation_state.ac_bus.unmet_load=simulation_state.primary_loads(1).load_requested-(simulation_state.converters(1).inverter_power_output+unmet_load);
                                
                                if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                                   %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                                   simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                                   %In this situation ac bus capacity shortage will be equal to zero.
                                   simulation_state.dc_bus.capacity_shortage = 0;
                                else 
                                    %The d.c. capacity shortage is given by:
                                    simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                                end
                                %The a.c. operating capacity served is given by:
                                simulation_state.ac_bus.operating_capacity_served=max(simulation_state.grids(1).max_grid_purchases,simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output);
                                % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                                if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                                   %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                                   simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                                   %In this situation ac bus capacity shortage will be equal to zero.
                                   simulation_state.ac_bus.capacity_shortage = 0;
                                else 
                                   %The a.c. capacity shortage is given by:
                                   simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                                end
                       else %simulation_parameters.has_battery==false, there is no battery
                            simulation_state.batteries(1).power_setpoint=0;
                            %Since there are no batteries rectifiers will not be needed, therefore rectifier input will be zero.
                            simulation_state.converters(1).rectifier_power_input=0;
                            %Similarly rectifier output will also be zero.
                            simulation_state.converters(1).rectifier_power_output=0; 
                            % The grid sales is given by:
                            simulation_state.grids(1).grid_sales=0;
                            % There shall be no grid purchases in this condition.
                            simulation_state.grids(1).grid_purchases=unmet_load;
                            % Total ac bus load served is given by:
                            simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                            % Total primary load served is given by:
                            simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                            % The a.c bus excess electricity
                            simulation_state.ac_bus.excess_electricity=max(max(simulation_state.converters(1).inverter_power_input*(simulation_parameters.converters(1).inverter_efficiency/100),simulation_state.converters(1).inverter_power_output)-(simulation_state.primary_loads(1).load_served+simulation_state.grids(1).grid_sales),0); 
                            simulation_state.ac_bus.unmet_load=max((simulation_state.primary_loads(1).load_requested-(simulation_state.converters(1).inverter_power_output+simulation_state.grids(1).grid_purchases)),0);
                            if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                                 %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                                 simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                                 %In this situation ac bus capacity shortage will be equal to zero.
                                 simulation_state.dc_bus.capacity_shortage = 0;
                            else 
                                 %The d.c. capacity shortage is given by:
                                 simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                            end
                            %The a.c. operating capacity served is given by:
                            simulation_state.ac_bus.operating_capacity_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                            % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                            if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                               %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                               simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                               %In this situation ac bus capacity shortage will be equal to zero.
                               simulation_state.ac_bus.capacity_shortage = 0;
                            else 
                               %The a.c. capacity shortage is given by:
                               simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested -(simulation_state.ac_bus.operating_capacity_served+simulation_state.grids(1).grid_sales);
                            end        
                        end
                   else %unmet load is==0
                        %Check if batteries are available. If they are available i.e.
                        %Check for excess electricity which is given by:
                        excess_electricity=simulation_state.converters(1).inverter_power_input-simulation_state.primary_loads.load_requested/(simulation_parameters.converters(1).inverter_efficiency/100);
                        %Now if excess electricity is greater than zero
                        if excess_electricity >0
                           %Check if batteries are available. If they are available i.e. 
                           if simulation_parameters.has_battery==true
                              %The battery state of charge percentage at a particular time-step is equal to current energy content in the battery at this particular time-step divided
                              %by the maximum energy content of the battery multiplied by 100%.
                              if simulation_state.current_timestep == 0
                                 simulation_state.batteries(1).state_of_charge_percent=100;
                              end
                              %The maximum state of charge of the battery is 100%
                              %The inverter capacity is equal to:
                              simulation_parameters.converters(1).inverter_capacity=24;
                              %The rectifier capacity is equal to:
                              simulation_parameters.converters(1).rectifier_capacity=24;
                              %The inverter efficiency is equal to:
                              simulation_parameters.converters(1).inverter_efficiency= 97;
                              %The rectifier capacity is equal to :
                              simulation_parameters.converters(1).rectifier_efficiency= 97.5;
                              simulation_parameters.batteries(1).maximum_state_of_charge=100;
                              simulation_parameters.batteries(1).nominal_capacity=2.4;
                              simulation_parameters.batteries(1).battery_bank_maximum_absolute_soc= simulation_parameters.batteries(1).nominal_capacity;
                              simulation_parameters.batteries(1).battery_bank_minimum_absolute_soc=(simulation_parameters.batteries(1).minimum_state_of_charge/100)*simulation_parameters.batteries(1).nominal_capacity;
                              %If battery state of charge is less than maximum state of charge
                                  % If excess electricity is greater than the minimum of maximum battery discharge power and rectifier capacity (Rectifier capacity limits the battery charging capacity).
                                  if  excess_electricity>= simulation_state.batteries(1).max_charge_power %More power remaining than can be used for charging battery
                                      %The rectifier will rectify the extra electricity that has gone to serve the load and feed it the battery.
                                      %The rectifier input is given by minimum of battery charge power and rectifier capacity as the rectifier capacity limits the battery charge power.
                                      simulation_state.converters(1).rectifier_power_input = 0;
                                      % The corresponding rectifier output is obtained by simply multiplying the rectifier input with the rectifier efficiency and given as:
                                      simulation_state.converters(1).rectifier_power_output = 0;
                                      % The battery state of charge after the battery has been charged in the current time-step is given by:
                                      simulation_state.batteries(1).power_setpoint=simulation_state.batteries(1).max_charge_power;
                                      simulation_state.batteries(1).state_of_charge_kwh=simulation_state.batteries(1).state_of_charge_kwh+simulation_state.batteries(1).power_setpoint;
                                      simulation_state.batteries(1).state_of_charge_percent=100*simulation_state.batteries(1).state_of_charge_kwh/simulation_parameters.batteries(1).nominal_capacity;
                                      % The net grid sales of extra electricity available after feeding the battery.
                                      simulation_state.grids(1).grid_sales=excess_electricity*(simulation_parameters.converters(1).inverter_efficiency/100)-simulation_state.batteries(1).max_charge_power;
                                      % No grid purchase is necessary as there is electricity available for grid sales.
                                      simulation_state.grids(1).grid_purchases=0;
                                      % Total ac bus load served is given by:
                                      simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                                      % Total primary load served is given by:
                                      simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                                      % The dc bus operating capacity served is given by:
                                      simulation_state.dc_bus.operating_capacity_served=min(simulation_state.pvs(1).power_setpoint,simulation_state.dc_bus.operating_capacity_requested/pv_derating_factor);
                                      % The dc bus capacity shortage is given by:
                                      simulation_state.dc_bus.capacity_shortage=max(simulation_state.dc_bus.operating_capacity_requested-simulation_state.dc_bus.operating_capacity_served,0);
                                      % Total ac bus operating capacity served is given by:
                                      simulation_state.ac_bus.operating_capacity_served=min(simulation_state.converters(1).inverter_power_output+ simulation_state.grids(1).grid_purchases,simulation_state.ac_bus.operating_capacity_requested);
                                      % The ac bus capacity shortage is given by:
                                      simulation_state.ac_bus.capacity_shortage=max(simulation_state.ac_bus.operating_capacity_requested-simulation_state.ac_bus.operating_capacity_served,0);
                                      % Total unmet load is given by:
                                      simulation_state.ac_bus.unmet_load=max((simulation_state.primary_loads(1).load_requested-(simulation_state.converters(1).inverter_power_output+simulation_state.grids(1).grid_purchases)),0);
                                      % The a.c bus excess electricity
                                      simulation_state.ac_bus.excess_electricity=max(simulation_state.converters(1).inverter_power_output-(simulation_state.primary_loads(1).load_served+simulation_state.grids(1).grid_sales+simulation_state.converters(1).rectifier_power_input),0); 
                                  else %excess_electricity < simulation_state.batteries(1).max_charge_power , %All remaining power to be used to charge the battery
                                      %Converter will rectify the excess electricity with the help of rectifier whose input is given by:
                                      simulation_state.converters(1).rectifier_power_input = 0;
                                      %The rectifier output is given by:
                                      simulation_state.converters(1).rectifier_power_output = simulation_state.converters(1).rectifier_power_input * (simulation_parameters.converters(1).rectifier_efficiency/100);
                                      %Grid purchase needed to fully charge the battery is given by:
                                      simulation_state.grids(1).grid_purchases=0;
                                      % The battery state of charge after the battery has been charged in the current time-step by PV panel  is given by: 
                                      simulation_state.batteries(1).power_setpoint = excess_electricity+simulation_state.grids(1).grid_purchases*(simulation_parameters.converters(1).rectifier_efficiency/100);
                                      simulation_state.batteries(1).state_of_charge_kwh=simulation_state.batteries(1).state_of_charge_kwh+simulation_state.batteries(1).power_setpoint;
                                      simulation_state.batteries(1).state_of_charge_percent=100*simulation_state.batteries(1).state_of_charge_kwh/simulation_parameters.batteries(1).nominal_capacity;
                                      % The extra electricity available after feeding the battery for grid sales is zero for this condition. .
                                      simulation_state.grids(1).grid_sales=0;
                                      %Rectifier capacity remaining is equal to rectifier capacity minus inverter capacity utilized till now which is given by the inverter power output.
                                      %Total ac bus load served is given by:
                                      simulation_state.ac_bus.load_served=simulation_state.converters(1).inverter_power_output+simulation_state.grids(1).grid_purchases-simulation_state.batteries(1).power_setpoint;
                                      % Total primary load served is given by:
                                      simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                                      % The dc bus operating capacity served is given by:
                                      simulation_state.dc_bus.operating_capacity_served=min(simulation_state.pvs(1).power_setpoint,simulation_state.dc_bus.operating_capacity_requested/pv_derating_factor);
                                      % The dc bus capacity shortage is given by:
                                      simulation_state.dc_bus.capacity_shortage=max(simulation_state.dc_bus.operating_capacity_requested-simulation_state.dc_bus.operating_capacity_served,0);
                                      % Total ac bus operating capacity served is given by:
                                      simulation_state.ac_bus.operating_capacity_served=min(simulation_state.converters(1).inverter_power_output+ simulation_state.grids(1).grid_purchases,simulation_state.ac_bus.operating_capacity_requested);
                                      % The ac bus capacity shortage is given by:
                                      simulation_state.ac_bus.capacity_shortage=max(simulation_state.ac_bus.operating_capacity_requested-simulation_state.ac_bus.operating_capacity_served,0);
                                      % Total unmet load is given by:
                                      simulation_state.ac_bus.unmet_load=max((simulation_state.primary_loads(1).load_requested-(simulation_state.converters(1).inverter_power_output+simulation_state.grids(1).grid_purchases)),0);
                                      % The a.c bus excess electricity
                                      simulation_state.ac_bus.excess_electricity=0; 
                                  end  
                              
                                   if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                                      %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                                      simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                                      %In this situation ac bus capacity shortage will be equal to zero.
                                      simulation_state.dc_bus.capacity_shortage = 0;
                                   else 
                                      %The d.c. capacity shortage is given by:
                                      simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                                   end
                                   %The a.c. operating capacity served is given by:
                                   simulation_state.ac_bus.operating_capacity_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                                   % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                                   if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                                      %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                                      simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                                      %In this situation ac bus capacity shortage will be equal to zero.
                                      simulation_state.ac_bus.capacity_shortage = 0;
                                   else 
                                      %The a.c. capacity shortage is given by:
                                      simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                                   end
                           else %simulation_parameters.has_battery==false, there is no battery
                                simulation_state.batteries(1).power_setpoint=0;
                                %Since there are no batteries rectifiers will not be needed, therefore rectifier input will be zero.
                                simulation_state.converters(1).rectifier_power_input=0;
                                %Similarly rectifier output will also be zero.
                                simulation_state.converters(1).rectifier_power_output=0; 
                                % The grid sales is given by:
                                simulation_state.grids(1).grid_sales=simulation_state.converters(1).inverter_power_output-simulation_state.primary_loads.load_requested;
                                % There shall be no grid purchases in this condition.
                                simulation_state.grids(1).grid_purchases=0;
                                % Total ac bus load served is given by:
                                simulation_state.ac_bus.load_served= simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                                % Total primary load served is given by:
                                simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                                % To prevent homer errors this below condition has to be provided.
                                % To prevent homer errors this below condition has to be provided.
                                % The a.c bus excess electricity
                                simulation_state.ac_bus.unmet_load = max((simulation_state.primary_loads(1).load_requested-(simulation_state.converters(1).inverter_power_output+simulation_state.grids(1).grid_purchases)),0);
                                simulation_state.ac_bus.excess_electricity=max(max(simulation_state.pvs(1).power_setpoint,simulation_state.converters(1).inverter_power_output)-(simulation_state.primary_loads(1).load_served+simulation_state.grids(1).grid_sales)/(simulation_parameters.converters(1).inverter_efficiency/100),0);         
                                if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                                   %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                                   simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                                   %In this situation ac bus capacity shortage will be equal to zero.
                                   simulation_state.dc_bus.capacity_shortage = 0;
                                else 
                                   %The d.c. capacity shortage is given by:
                                   simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                                end
                                %The a.c. operating capacity served is given by:
                                simulation_state.ac_bus.operating_capacity_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                                % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                                if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                                   %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                                   simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                                   %In this situation ac bus capacity shortage will be equal to zero.
                                   simulation_state.ac_bus.capacity_shortage = 0;
                                else 
                                   %The a.c. capacity shortage is given by:
                                   simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                                end
                           end
                        else %excess_electricity=0 
                          %Check if batteries are available. If they are available i.e. 
                          if simulation_parameters.has_battery==true
                             %The battery state of charge percentage at a particular time-step is equal to current energy content in the battery at this particular time-step divided
                             %by the maximum energy content of the battery multiplied by 100%.
                             if simulation_state.current_timestep == 0
                                  simulation_state.batteries(1).state_of_charge_percent=100;
                             end
                             %The maximum state of charge of the battery is 100%
                             simulation_parameters.batteries(1).maximum_state_of_charge=100;
                             %The minimum state of charge of the battery is 20%
                             simulation_parameters.batteries(1).minimum_state_of_charge=20; 
                             simulation_parameters.batteries(1).nominal_capacity=2.4;
                             simulation_parameters.batteries(1).battery_bank_maximum_absolute_soc= simulation_parameters.batteries(1).nominal_capacity;
                             simulation_parameters.batteries(1).battery_bank_minimum_absolute_soc=(simulation_parameters.batteries(1).minimum_state_of_charge/100)*simulation_parameters.batteries(1).nominal_capacity;
                             %If battery state of charge is less than maximum state of charge
                            %The inverter capacity is equal to:
                             simulation_parameters.converters(1).inverter_capacity=24;
                             %The rectifier capacity is equal to:
                             simulation_parameters.converters(1).rectifier_capacity=24;
                             %The inverter efficiency is equal to:
                             simulation_parameters.converters(1).inverter_efficiency= 97;
                             %The rectifier capacity is equal to :
                             simulation_parameters.converters(1).rectifier_efficiency= 97.5;
                          
                                 % Converter will rectify the excess electricity with the help of rectifier whose input is given by:
                                 simulation_state.converters(1).rectifier_power_input = 0;
                                 % The rectifier output is given by:
                                 simulation_state.converters(1).rectifier_power_output = 0;
                                 %Grid purchase needed to fully charge the battery is given by:
                                 simulation_state.grids(1).grid_purchases=0;
                                 % The battery state of charge after the battery has been charged in the current time-step is given by: 
                                 simulation_state.batteries(1).power_setpoint =  0;
                                 simulation_state.batteries(1).state_of_charge_kwh=simulation_state.batteries(1).state_of_charge_kwh+simulation_state.batteries(1).power_setpoint;
                                 simulation_state.batteries(1).state_of_charge_percent=100*simulation_state.batteries(1).state_of_charge_kwh/simulation_parameters.batteries(1).nominal_capacity;
                                 %The extra electricity available after feeding the battery for grid sales is zero for this condition. .
                                 simulation_state.grids(1).grid_sales=0;
                                 simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+ simulation_state.converters(1).inverter_power_output-simulation_state.batteries(1).power_setpoint;
                                 % Total primary load served is given by:
                                 simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                                 % To prevent homer errors this below condition has to be provided.
                                 simulation_state.ac_bus.unmet_load =max((simulation_state.primary_loads(1).load_requested-(simulation_state.converters(1).inverter_power_output+simulation_state.grids(1).grid_purchases)),0);
                                 % The a.c bus excess electricity
                                 simulation_state.ac_bus.excess_electricity=max(simulation_state.converters(1).inverter_power_output-(simulation_state.primary_loads(1).load_served+simulation_state.grids(1).grid_sales),0); 
                                 if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                                    %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                                    simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                                    %In this situation ac bus capacity shortage will be equal to zero.
                                    simulation_state.dc_bus.capacity_shortage = 0;
                                 else 
                                    %The d.c. capacity shortage is given by:
                                    simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                                 end
                                 %The a.c. operating capacity served is given by:
                                 simulation_state.ac_bus.operating_capacity_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                                 % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                                 if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                                    %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                                    simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                                    %In this situation ac bus capacity shortage will be equal to zero.
                                    simulation_state.ac_bus.capacity_shortage = 0;
                                 else 
                                    %The a.c. capacity shortage is given by:
                                    simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                                 end
                          
                                if simulation_state.ac_bus.load_served >= simulation_state.ac_bus.load_requested
                                   %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                                   simulation_state.ac_bus.load_served = simulation_state.ac_bus.load_requested;
                                   %In this situation ac bus capacity shortage will be equal to zero.
                                   simulation_state.ac_bus.unmet_load = 0;
                                else 
                                   %The a.c. capacity shortage is given by:
                                   simulation_state.ac_bus.unmet_load = simulation_state.ac_bus.load_requested-simulation_state.ac_bus.load_served;
                                end
                                     
                                     if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                                        %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                                        simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                                        %In this situation ac bus capacity shortage will be equal to zero.
                                        simulation_state.dc_bus.capacity_shortage = 0;
                                     else 
                                        %The d.c. capacity shortage is given by:
                                        simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                                     end
                                       %The a.c. operating capacity served is given by:
                                       simulation_state.ac_bus.operating_capacity_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                                       % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                                    if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                                       %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                                       simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                                       %In this situation ac bus capacity shortage will be equal to zero.
                                       simulation_state.ac_bus.capacity_shortage = 0;
                                    else 
                                       %The a.c. capacity shortage is given by:
                                       simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                                    end  
                          
                       else %simulation_parameters.has_battery==false, there is no battery
                            simulation_state.batteries(1).power_setpoint=0;
                            %Since there are no batteries rectifiers will not be needed, therefore rectifier input will be zero.
                            simulation_state.converters(1).rectifier_power_input=0;
                            %Similarly rectifier output will also be zero.
                            simulation_state.converters(1).rectifier_power_output=0; 
                            % The grid sales is given by:
                            simulation_state.grids(1).grid_sales=simulation_state.converters(1).inverter_power_output-simulation_state.primary_loads.load_requested;
                            % There shall be no grid purchases in this condition.
                            simulation_state.grids(1).grid_purchases=0;
                            simulation_state.ac_bus.load_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                            % Total primary load served is given by:
                            simulation_state.primary_loads(1).load_served=simulation_state.ac_bus.load_served-simulation_state.grids(1).grid_sales;
                            %The a.c. capacity shortage is given by:
                            simulation_state.ac_bus.unmet_load =max((simulation_state.primary_loads(1).load_requested-(simulation_state.converters(1).inverter_power_output+simulation_state.grids(1).grid_purchases)),0);
                            % The a.c bus excess electricity
                            simulation_state.ac_bus.excess_electricity=max(max(simulation_state.pvs(1).power_setpoint,simulation_state.converters(1).inverter_power_output)-(simulation_state.primary_loads(1).load_served+simulation_state.grids(1).grid_sales)/(simulation_parameters.converters(1).inverter_efficiency/100),0);   
                            if simulation_state.dc_bus.operating_capacity_served >= simulation_state.dc_bus.operating_capacity_requested
                               %d.c. operating bus capacity served should be equated equal to dc operating requested to prevent homer pro errors.
                               simulation_state.dc_bus.operating_capacity_served = simulation_state.dc_bus.operating_capacity_requested;
                               %In this situation ac bus capacity shortage will be equal to zero.
                               simulation_state.dc_bus.capacity_shortage = 0;
                            else 
                               %The d.c. capacity shortage is given by:
                               simulation_state.dc_bus.capacity_shortage = simulation_state.dc_bus.operating_capacity_requested - simulation_state.dc_bus.operating_capacity_served;
                            end
                               %The a.c. operating capacity served is given by:
                               simulation_state.ac_bus.operating_capacity_served=simulation_state.grids(1).grid_purchases+simulation_state.converters(1).inverter_power_output;
                               % Checking if enough capacity is available or not If ac bus capacity served is greater than ac capacity bus requested then,
                               if simulation_state.ac_bus.operating_capacity_served >= simulation_state.ac_bus.operating_capacity_requested
                                  %A.c. operating bus capacity served should be equated equal to ac operating requested to prevent homer pro errors.
                                  simulation_state.ac_bus.operating_capacity_served = simulation_state.ac_bus.operating_capacity_requested;
                                  %In this situation ac bus capacity shortage will be equal to zero.
                                  simulation_state.ac_bus.capacity_shortage = 0;
                               else 
                                  %The a.c. capacity shortage is given by:
                                  simulation_state.ac_bus.capacity_shortage = simulation_state.ac_bus.operating_capacity_requested - simulation_state.ac_bus.operating_capacity_served;
                               end     
                          end 
                        end
                   end
               end
           end
    else %simulation_parameters.has_pv==false i.e there are no pv panels
         % Then pv power output at a particular time-step is equal to zero
         simulation_state.pvs(1).power_setpoint=0;
         % The inverter input will be zero
         simulation_state.converters(1).inverter_power_input=0;
         % The inverter output will be zero
         simulation_state.converters(1).inverter_power_output=0;       
    end   
end       
           

  
   
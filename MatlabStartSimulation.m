function [myErr, matlab_simulation_variables]=MatlabStartSimulation(simulation_parameters)
myErr.error_description='';
myErr.severity_code='';

%Initialize user-defined simulation variables. We can use these throughout
%the simulation for dispatch decisions or to generate errors at the end of simulation.
matlab_simulation_variables.total_energy_test=0;
matlab_simulation_variables.gen1_CO=0;
end

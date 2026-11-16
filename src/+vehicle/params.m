function veh = params()
%VEHICLE.PARAMS Simple Indian e-scooter (2W) parameters.
%
% Representative of a ~2.5 kWh, 90 km/h class Indian e-scooter (Ather /
% TVS iQube / Ola segment). Not a specific model; each value is commented.
veh.m_kerb    = 115;     % kerb mass [kg] (incl. battery)
veh.m_rider   = 75;      % one rider [kg] (type-approval test load)
veh.m         = veh.m_kerb + veh.m_rider;
veh.k_rot     = 1.03;    % rotating-inertia factor (wheels, motor rotor) [-]
veh.g         = 9.81;    % [m/s^2]
veh.Crr       = 0.013;   % rolling resistance, scooter tyres on asphalt [-]
veh.CdA       = 0.50;    % drag area: Cd ~0.75 x frontal area ~0.67 m^2 (scooter + rider) [m^2]
veh.rho_air   = 1.165;   % air density at ~30 degC [kg/m^3]
veh.grade     = 0;       % road gradient [rad] (flat for type-approval cycles)

% Drivetrain: battery -> inverter -> hub/mid motor -> wheel
veh.eta_trac  = 0.85;    % battery-to-wheel efficiency when driving (inverter 0.96 x motor 0.90 x belt 0.98)
veh.eta_regen = 0.80;    % wheel-to-battery efficiency when regenerating
veh.regen_frac = 0.5;    % share of braking done by the motor (rest is mechanical front brake)
veh.P_trac_max  = 7000;  % peak motor power [W]
veh.P_regen_max = 2000;  % regen power limit [W]
veh.P_aux     = 40;      % 12 V loads: lights, dashboard, BMS, controller [W]
end

function d = powerDemand(cyc, veh)
%VEHICLE.POWERDEMAND Battery power needed to follow a speed profile.
%
%   d = vehicle.powerDemand(cyc, veh)
%   cyc : struct with fields t, v [m/s], a [m/s^2]  (e.g. profiles.midc())
%   veh : vehicle.params()
%
% Longitudinal dynamics ("backward-facing" model: speed is given, find power):
%   F_wheel = k_rot*m*a  +  m*g*Crr  +  0.5*rho*CdA*v^2  +  m*g*sin(grade)
%   P_wheel = F_wheel * v
% Battery side:
%   driving  (P_wheel > 0): P_batt = min(P_wheel, P_trac_max) / eta_trac + P_aux
%   braking  (P_wheel < 0): P_batt = max(regen_frac*eta_regen*P_wheel, -P_regen_max) + P_aux
% P_batt > 0 means the battery is discharging.
v = cyc.v(:);  a = cyc.a(:);
moving = v > 0.01;

d.F_inertia = veh.k_rot * veh.m * a;
d.F_roll    = veh.m * veh.g * veh.Crr * cos(veh.grade) .* moving;
d.F_aero    = 0.5 * veh.rho_air * veh.CdA * v.^2;
d.F_grade   = veh.m * veh.g * sin(veh.grade) .* moving;
d.F_wheel   = d.F_inertia + d.F_roll + d.F_aero + d.F_grade;
d.P_wheel   = d.F_wheel .* v;

drive = d.P_wheel >= 0;
d.P_batt = zeros(size(v));
d.P_batt(drive)  = min(d.P_wheel(drive), veh.P_trac_max) / veh.eta_trac;
d.P_batt(~drive) = max(veh.regen_frac * veh.eta_regen * d.P_wheel(~drive), -veh.P_regen_max);
d.P_batt = d.P_batt + veh.P_aux;

d.power_limited_s = sum(d.P_wheel > veh.P_trac_max) * (cyc.t(2) - cyc.t(1));
end

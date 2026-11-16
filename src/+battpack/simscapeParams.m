function M = simscapeParams(cfg, T_amb_C, var)
%BATTPACK.SIMSCAPEPARAMS Map lfp.cellParams onto the Simscape Battery module mask.
%
%   Module1 = battpack.simscapeParams(cfg, T_amb_C, var)
%   cfg     : battpack.config()
%   T_amb_C : ambient temperature [degC] (sets the capacity used by the plant)
%   var     : battpack.variation(...) or [] for an ideal (identical) pack
%
% The Simscape cell ("Battery Equivalent Circuit", 2 RC pairs, one-state
% hysteresis, lumped thermal mass) uses the SAME tables as our MATLAB model,
% so the plant and the estimator start from the same physics. Differences
% then come only from what we deliberately add: temperature rise, cell
% variation, sensor errors.
%
% Hysteresis equivalence (checked in Simscape source):
%   Simscape: dh/dt = rate*|i|/Q * (sign(i) - h),  V_hyst = h*M,  h in [-1, 1]
%   ours    : same with gamma_hyst = rate, M_hyst = M   (Simscape: + current = charge)
p   = cfg.cell;
nS  = numel(p.SOC_bp);
nT  = numel(p.T_bp);
T_K = p.T_bp + 273.15;
Ns  = cfg.Ns;

% Capacity: the Simscape block has no capacity-vs-temperature table, so we
% give the plant the capacity that matches the ambient temperature of the run.
Qfac = interp1(p.T_bp, p.Qfactor, min(max(T_amb_C, p.T_bp(1)), p.T_bp(end)));

% OCV: Simscape interpolates tables linearly, so we hand it the same dense
% (0.5 % SOC step) pchip-sampled curve the MATLAB model uses. With only the
% 14 coarse breakpoints, linear vs pchip differ by up to ~4 mV near full
% charge - an artificial model mismatch worth several % SOC on LFP.
socO = p.ocvTab_soc(1:5:end);                                           % 201 points
nO   = numel(socO);
M.BatteryCapacityCell                    = p.Q_Ah * Qfac;               % A*hr
M.SOCBreakpointsCell                     = socO;
M.TemperatureBreakpointsCell             = T_K;                         % K
M.OpenCircuitVoltageThermalCell          = repmat(lfp.ocv(socO, p)', 1, nT);  % V, no T dependence (LFP OCV varies < 1 mV/K)
M.VoltageRangeCell                       = [0, inf];
M.MaximumHysteresisVoltageThermalCell    = p.M_hyst * ones(nO, nT);     % V
M.InstantaneousHysteresisVoltageThermalCell = zeros(nO, nT);
M.HysteresisRateThermalCell              = p.gamma_hyst;
M.ResistanceSOCBreakpointsCell           = p.SOC_bp;
M.ResistanceTemperatureBreakpointsCell   = T_K;
M.R0ThermalCell                          = p.R0;                        % Ohm, nSOC x nT
M.R1ThermalCell                          = p.R1;
M.Tau1ThermalCell                        = p.tau1 * ones(nS, nT);       % s
M.R2ThermalCell                          = p.R2;
M.Tau2ThermalCell                        = p.tau2 * ones(nS, nT);

% Thermal (per cell; the builder scales for the 8 lumped cells)
% 32700 LFP: ~140 g, cp ~1050-1100 J/kg/K (published LFP range 800-1115)  ->  ~150 J/K
M.BatteryThermalMassCell = 150;                                         % J/K
% Cell-to-air thermal resistance inside a closed scooter pack (natural convection).
% Middle groups are cooled worse than the edge groups -> realistic temperature spread.
k = (1:Ns);
M.AmbientResistance = 20 * (1 + 0.4 * sin(pi * (k - 0.5) / Ns));       % K/W, 1 x Ns: 20 (edge) .. 28 (centre)
M.InterParallelAssemblyThermalResistance = 5;                           % K/W, busbar/holder conduction between groups

% Passive balancing hardware (used in week 4): bleed resistor across each group
M.CellBalancingClosedResistance = 0.01;                                 % Ohm, MOSFET on-resistance
M.CellBalancingOpenConductance  = 1e-8;                                 % 1/Ohm
M.CellBalancingThreshold        = 0.5;                                  % switch closes when command > 0.5
% A real BMS has ONE 33 Ohm bleed resistor per series tap (~100 mA at 3.3 V,
% Daly 16S LFP BMS spec 100 +/- 30 mA). Simscape applies this parameter to
% every cell of the parallel group (measured: 33/8 = 4.1 Ohm effective), so we
% enter 33 * Np to get the real per-group bleed resistance.
M.CellBalancingResistance       = 33 * cfg.Np;                          % Ohm per cell -> 33 Ohm per group

% Cell-to-cell variation (percent deviation per group, Ns x 1)
z = zeros(Ns, 1);
if isempty(var), dQ = z; dR = z; else, dQ = var.dQ(:); dR = var.dR(:); end
M.BatteryCapacityCellPercentDeviation   = dQ;
M.R0ThermalCellPercentDeviation         = dR;
M.R1ThermalCellPercentDeviation         = dR;
M.R2ThermalCellPercentDeviation         = dR;
for f = ["SOCBreakpointsCell", "TemperatureBreakpointsCell", "OpenCircuitVoltageThermalCell", ...
         "VoltageRangeCell", "MaximumHysteresisVoltageThermalCell", ...
         "InstantaneousHysteresisVoltageThermalCell", "HysteresisRateThermalCell", ...
         "ResistanceSOCBreakpointsCell", "ResistanceTemperatureBreakpointsCell", ...
         "Tau1ThermalCell", "Tau2ThermalCell", "BatteryThermalMassCell"]
    M.(f + "PercentDeviation") = z;
end
end

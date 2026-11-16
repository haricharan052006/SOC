function p = cellParams()
%LFP.CELLPARAMS Parameters of one LFP cell (6 Ah, 32700 format) for a 2RC + hysteresis model.
%
%   p = lfp.cellParams() returns a struct with lookup tables indexed by
%   SOC (rows) and temperature (columns). Values are representative of
%   commercial 32700 LFP datasheets and LFP literature; they are NOT fitted
%   to one specific cell. Every number below has a comment on where it comes from.
%
%   Sign convention used everywhere in this project:
%       current i > 0  -> DISCHARGE,   i < 0 -> CHARGE

%% Nominal ratings
p.Q_Ah    = 6.0;      % nominal capacity at 25 degC [Ah]  (typical 32700 LFP: 6 Ah)
p.V_nom   = 3.2;      % nominal voltage [V]
p.V_min   = 2.5;      % discharge cut-off [V]
p.V_max   = 3.65;     % charge cut-off [V]
p.eta_chg = 1.0;      % coulombic efficiency on charge (LFP ~0.999, taken as 1)

%% Breakpoints
p.SOC_bp = [0 0.05 0.10 0.15 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 0.95 1.00];
p.T_bp   = [5 15 25 35 45];                         % [degC]  covers Indian winter -> summer

%% Open-circuit voltage (average of charge and discharge branches) [V]
% Shape follows the well-known LFP curve: steep below ~15 % and above ~95 %,
% and a very flat plateau (~1 mV per % SOC) in between. That flat plateau is
% exactly why voltage-based SOC estimation is hard for LFP.
% Checked against vendor rest-voltage tables (~3.26-3.30 V at 50 %, 3.30-3.40 V
% at 100 % rest) - see docs/literature_review.md.
p.OCV = [2.900 3.120 3.200 3.235 3.255 3.272 3.287 3.295 3.300 3.312 3.328 3.335 3.345 3.400];

% Dense OCV lookup (pchip through the breakpoints, sampled every 0.1 % SOC).
% lfp.ocv interpolates this table linearly: same curve, ~20x faster than
% calling pchip every step, and Simulink-code-generation friendly.
p.ocvTab_soc  = linspace(0, 1, 1001);
p.ocvTab_v    = interp1(p.SOC_bp, p.OCV, p.ocvTab_soc, 'pchip');
p.ocvTab_dvds = gradient(p.ocvTab_v, p.ocvTab_soc);       % dOCV/dSOC [V per unit SOC]

%% Hysteresis (one-state model, Plett 2004)
% Published LFP charge/discharge OCV gaps: 5-25 mV typical, up to 38 mV
% (Barai et al., Warwick 2015); roughly unchanged between 25 and 45 degC.
% We model it as h in [-M, +M] that moves towards -M on discharge and +M on charge.
p.M_hyst     = 0.010;   % half of the charge/discharge OCV gap [V]  (total gap 20 mV, mid-range)
p.gamma_hyst = 50;      % how fast h converges per unit of SOC moved [-] (settles in ~5 % SOC)

%% Resistances and time constants at 25 degC
% R0  : ohmic resistance (electrolyte + contacts). Datasheet AC-IR ~8 mOhm, DC ~12 mOhm.
% R1  : fast RC (charge transfer, double layer), tau1 ~ 10 s
% R2  : slow RC (solid-state diffusion),          tau2 ~ 200 s
% Resistances rise at low SOC (and slightly at high SOC), as measured in HPPC tests.
shapeR0  = [1.60 1.35 1.20 1.10 1.05 1.00 1.00 1.00 1.00 1.00 1.02 1.05 1.08 1.12];
shapeRC  = [2.00 1.60 1.30 1.15 1.05 1.00 1.00 1.00 1.00 1.00 1.03 1.07 1.12 1.20];
R0_25 = 0.012 * shapeR0;    % [Ohm]
R1_25 = 0.004 * shapeRC;    % [Ohm]
R2_25 = 0.006 * shapeRC;    % [Ohm]
p.tau1 = 10;                % [s]
p.tau2 = 200;               % [s]

%% Temperature dependence (Arrhenius)
%   R(T) = R(25 degC) * exp( Ea/R * (1/T - 1/T_ref) )
% Ea/R values give ~30 % lower R0 and ~40 % lower RC resistances at 45 degC
% vs 25 degC, in line with published LFP HPPC data.
p.EaR_R0 = 1800;            % [K]
p.EaR_RC = 2500;            % [K]
Tref  = 298.15;
TK    = p.T_bp + 273.15;
fR0   = exp(p.EaR_R0 * (1./TK - 1/Tref));    % 1 x nT
fRC   = exp(p.EaR_RC * (1./TK - 1/Tref));

p.R0 = R0_25(:) * fR0;      % nSOC x nT  [Ohm]
p.R1 = R1_25(:) * fRC;
p.R2 = R2_25(:) * fRC;

% Usable capacity grows slightly with temperature (less polarisation, better kinetics).
% 32700 datasheets guarantee only >=75-80 % at 0-10 degC and >=95-98 % at 60 degC,
% so the cold end is set conservatively.
p.Qfactor = [0.90 0.96 1.00 1.01 1.015];     % 1 x nT, multiplies Q_Ah

% Datasheet limits (Sunmoon / FBTech IFR32700 6 Ah): 3C continuous, 6C 10 s pulse,
% discharge -20..60 degC, mass 140-145 g.
p.I_cont_max = 3 * p.Q_Ah;   % [A]
p.T_max      = 60;           % [degC]
end

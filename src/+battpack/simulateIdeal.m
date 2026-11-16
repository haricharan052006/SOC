function r = simulateIdeal(P_batt, T_C, dt, cfg, socStop, x0)
%BATTPACK.SIMULATEIDEAL Pack of identical cells driven by a power profile.
%
%   r = battpack.simulateIdeal(P_batt, T_C, dt, cfg, socStop)
%   P_batt  : N x 1 battery power [W] (+ = discharge), e.g. repeated MIDC
%   T_C     : cell temperature [degC] (constant)
%   socStop : stop when SOC drops to this value (e.g. 0.10)
%   x0      : optional initial cell state (default full and relaxed)
%
% Every cell carries P/(Ns*Np), so one cell model represents the whole pack.
% Used as the MATLAB reference for the Simscape pack and for quick studies.
if nargin < 6, x0 = [1; 0; 0; 0]; end
p   = cfg.cell;
N   = numel(P_batt);
Pc  = P_batt(:) / (cfg.Ns * cfg.Np);
I   = nan(N, 1);  V = nan(N, 1);  S = nan(N, 1);
x   = x0(:);
kEnd = N;
for k = 1:N
    S(k) = x(1);
    if x(1) <= socStop
        kEnd = k;
        break
    end
    i_c = lfp.currentFromPower(Pc(k), x, T_C, p);
    [x, v_c] = lfp.cellStep(x, i_c, T_C, dt, p);
    I(k) = i_c * cfg.Np;
    V(k) = v_c * cfg.Ns;
end
r.t = (0:kEnd-1)' * dt;
r.I = I(1:kEnd);  r.V = V(1:kEnd);  r.SOC = S(1:kEnd);
r.kEnd = kEnd;
end

function q = paramsAt(soc, T_C, p)
%LFP.PARAMSAT Look up the 2RC parameters at one operating point.
%
%   q = lfp.paramsAt(soc, T_C, p) returns R0, R1, R2 [Ohm], C1, C2 [F],
%   tau1, tau2 [s] and capacity Q_As [A*s] at the given SOC (0..1) and
%   cell temperature T_C [degC]. Inputs outside the tables are clamped.
%
% Bilinear interpolation written out by hand (instead of interp2) because
% this function runs millions of times inside the EKF; the result is
% identical to interp2(...,'linear').
soc = min(max(soc, p.SOC_bp(1)), p.SOC_bp(end));
T_C = min(max(T_C, p.T_bp(1)),   p.T_bp(end));

is = min(sum(soc >= p.SOC_bp), numel(p.SOC_bp) - 1);   % interval index (1-based)
it = min(sum(T_C >= p.T_bp),   numel(p.T_bp) - 1);
ws = (soc - p.SOC_bp(is)) / (p.SOC_bp(is + 1) - p.SOC_bp(is));
wt = (T_C - p.T_bp(it))   / (p.T_bp(it + 1)   - p.T_bp(it));

R0 = bilin(p.R0, is, it, ws, wt);
R1 = bilin(p.R1, is, it, ws, wt);
R2 = bilin(p.R2, is, it, ws, wt);
Q  = p.Q_Ah * 3600 * ((1 - wt) * p.Qfactor(it) + wt * p.Qfactor(it + 1));

% Build the struct in one statement: Simulink/MATLAB Coder does not allow
% adding fields to a struct after it has been read.
q = struct('R0', R0, 'R1', R1, 'R2', R2, ...
           'tau1', p.tau1, 'tau2', p.tau2, ...
           'C1', p.tau1 / R1, 'C2', p.tau2 / R2, ...
           'Q_As', Q);
end

function y = bilin(M, is, it, ws, wt)
y = (1 - ws) * ((1 - wt) * M(is, it)     + wt * M(is, it + 1)) + ...
         ws  * ((1 - wt) * M(is + 1, it) + wt * M(is + 1, it + 1));
end

function [V, X, kEnd] = simulate(iProf, T_C, dt, x0, p, vCutoff)
%LFP.SIMULATE Run the 2RC + hysteresis cell model over a current profile.
%
%   [V, X, kEnd] = lfp.simulate(iProf, T_C, dt, x0, p)
%   [V, X, kEnd] = lfp.simulate(iProf, T_C, dt, x0, p, vCutoff)
%
%   iProf   : N x 1 current [A], positive = discharge
%   T_C     : scalar or N x 1 cell temperature [degC]
%   dt      : time step [s]
%   x0      : 4 x 1 initial state [soc; v1; v2; h]
%   vCutoff : optional, stop early if terminal voltage drops below this [V]
%
%   V    : N x 1 terminal voltage (NaN after an early stop)
%   X    : N x 4 state at each step (row k = state used to compute V(k))
%   kEnd : last simulated step
%
%   This is the MATLAB reference ("golden") model. The Simulink block in
%   models/lfp_cell_2rc.slx calls the same lfp.cellStep, and
%   scripts/week1_simulink_cell_check.m checks that both give the same answer.
if nargin < 6, vCutoff = -Inf; end
N = numel(iProf);
if isscalar(T_C), T_C = T_C * ones(N, 1); end
V = nan(N, 1);  X = nan(N, 4);
x = x0(:);
kEnd = N;
for k = 1:N
    X(k, :) = x';
    [x, V(k)] = lfp.cellStep(x, iProf(k), T_C(k), dt, p);
    if V(k) < vCutoff
        kEnd = k;
        break
    end
end
end

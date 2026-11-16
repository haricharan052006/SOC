function [F, H] = jacobians(x, i, T_C, dt, p)
%LFP.JACOBIANS Linearisation of lfp.cellStep for the Extended Kalman Filter.
%
%   [F, H] = lfp.jacobians(x, i, T_C, dt, p)
%   F = d(xNext)/dx  (4x4)   - how the state propagates
%   H = d(v)/dx      (1x4)   - how the terminal voltage reacts to each state
%
% With x = [soc; v1; v2; h]:
%   F = diag(1, a1, a2, ah)            (parameter changes with soc ignored - standard)
%   H = [dOCV/dsoc - i*dR0/dsoc,  -1,  -1,  +1]
%
% H(1) is the key number of this project: it is how many volts the terminal
% voltage changes per unit SOC. On LFP's plateau it is ~0.1 V per unit SOC
% (1 mV per %), so the measurement barely "sees" SOC there.
soc = x(1);
q   = lfp.paramsAt(soc, T_C, p);
[~, dOCV] = lfp.ocv(soc, p);

d   = 1e-3;                                         % finite difference for dR0/dsoc
dR0 = (lfp.paramsAt(min(soc + d, 1), T_C, p).R0 - lfp.paramsAt(max(soc - d, 0), T_C, p).R0) ...
      / (min(soc + d, 1) - max(soc - d, 0));

a1 = exp(-dt / q.tau1);
a2 = exp(-dt / q.tau2);
ah = exp(-abs(i * p.gamma_hyst * dt / q.Q_As));

F = diag([1, a1, a2, ah]);
H = [dOCV - i * dR0, -1, -1, 1];
end

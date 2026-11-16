function [xNext, v] = cellStep(x, i, T_C, dt, p)
%LFP.CELLSTEP One time step of the 2RC + hysteresis LFP cell model.
%
%   [xNext, v] = lfp.cellStep(x, i, T_C, dt, p)
%
%   State vector x (4x1):
%       x(1) soc : state of charge [0..1]
%       x(2) v1  : voltage across fast RC pair [V]
%       x(3) v2  : voltage across slow RC pair [V]
%       x(4) h   : hysteresis voltage [V], bounded in [-M, +M]
%   Inputs:
%       i   : cell current [A], positive = discharge
%       T_C : cell temperature [degC]
%       dt  : time step [s]
%   Outputs:
%       v     : terminal voltage at THIS step (uses x and i)
%       xNext : state at the next step
%
%   Equations (exact discretisation for a constant current over dt):
%       soc' = soc - eta*i*dt/Q
%       vk'  = a_k*vk + R_k*(1-a_k)*i,          a_k = exp(-dt/tau_k)
%       h'   = a_h*h - (1-a_h)*M*sign(i),       a_h = exp(-|eta*i*gamma*dt/Q|)
%       v    = OCV(soc) + h - R0*i - v1 - v2
%
%   This same function is reused later as the EKF's process/measurement model,
%   so the "truth" model and the estimator stay consistent and easy to swap.
soc = x(1);  v1 = x(2);  v2 = x(3);  h = x(4);
q   = lfp.paramsAt(soc, T_C, p);

% Output equation
v = lfp.ocv(soc, p) + h - q.R0 * i - v1 - v2;

% Coulombic efficiency applies to charging only
eta = 1;
if i < 0
    eta = p.eta_chg;
end

% State update
a1 = exp(-dt / q.tau1);
a2 = exp(-dt / q.tau2);
ah = exp(-abs(eta * i * p.gamma_hyst * dt / q.Q_As));

xNext = [ soc - eta * i * dt / q.Q_As;
          a1 * v1 + q.R1 * (1 - a1) * i;
          a2 * v2 + q.R2 * (1 - a2) * i;
          ah * h  - (1 - ah) * p.M_hyst * sign(i) ];
end

function [v, dvdsoc] = ocv(soc, p)
%LFP.OCV Average open-circuit voltage and its slope dOCV/dSOC.
%
%   [v, dvdsoc] = lfp.ocv(soc, p)
%     soc    : state of charge, 0..1; scalar or vector
%     v      : OCV [V]
%     dvdsoc : slope [V per unit SOC]. Multiply by 0.01 for V per %.
%              The EKF needs this slope: where it is ~0, voltage tells the
%              filter almost nothing about SOC (poor observability).
%
% Uses the dense uniform table built in lfp.cellParams (pchip curve sampled
% every 0.1 % SOC) with direct-index linear interpolation: fast enough to call
% millions of times, and Simulink-code-generation friendly.
%
% Outside 0..1 the curve is extended LINEARLY with the end slope (not clamped).
% Reason: an EKF needs the function and its slope to agree. If OCV were flat
% above 100 % while the slope said 15 mV/%, the filter would keep pushing SOC
% up without any voltage change and diverge (we hit exactly this bug).
n    = numel(p.ocvTab_soc) - 1;                 % number of intervals (1000)
sc   = min(max(soc, 0), 1);
s    = sc * n;
k    = min(floor(s), n - 1);                    % 0-based interval index
w    = s - k;
v      = (1 - w) .* p.ocvTab_v(k + 1)    + w .* p.ocvTab_v(k + 2);
dvdsoc = (1 - w) .* p.ocvTab_dvds(k + 1) + w .* p.ocvTab_dvds(k + 2);
v      = v + dvdsoc .* (soc - sc);              % linear extension outside 0..1
v = reshape(v, size(soc));  dvdsoc = reshape(dvdsoc, size(soc));
end

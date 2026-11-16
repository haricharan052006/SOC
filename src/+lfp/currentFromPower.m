function i = currentFromPower(P, x, T_C, p)
%LFP.CURRENTFROMPOWER Cell current that delivers power P at the terminals.
%
%   i = lfp.currentFromPower(P, x, T_C, p)
%   P : cell power [W], + = discharge;  x : cell state [soc; v1; v2; h]
%
% Why: the motor controller asks for POWER, not current. As the voltage sags
% (low SOC, cold, high load) the same power needs MORE current.
% Terminal voltage is  V = Voc - R0*i  with  Voc = OCV(soc) + h - v1 - v2, so
%   P = V*i = Voc*i - R0*i^2   ->   i = (Voc - sqrt(Voc^2 - 4*R0*P)) / (2*R0)
% (the smaller root is the physical one). Works for charging too (P < 0).
q   = lfp.paramsAt(x(1), T_C, p);
Voc = lfp.ocv(x(1), p) + x(4) - x(2) - x(3);
disc = Voc^2 - 4 * q.R0 * P;
if disc < 0
    error('lfp:powerLimit', ...
          'Requested %.1f W exceeds the cell''s maximum power %.1f W.', P, Voc^2 / (4*q.R0));
end
i = (Voc - sqrt(disc)) / (2 * q.R0);
end

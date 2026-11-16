function [iProf, t, info] = pulseDischarge(I, dt)
%PROFILES.PULSEDISCHARGE Simplified HPPC/GITT-style pulse-discharge current profile.
%
%   [iProf, t, info] = profiles.pulseDischarge(I, dt)
%   10 min rest, then 10 x (6 min discharge at current I + 30 min rest).
%   At I = 1C each pulse removes 10 % SOC.
%
%   iProf : N x 1 current [A] (positive = discharge)
%   t     : N x 1 time [s]
%   info  : struct with tLead, tPulse, tRest, nPulses [s / count]
info.tLead   = 10*60;
info.tPulse  = 6*60;
info.tRest   = 30*60;
info.nPulses = 10;

nLead  = round(info.tLead  / dt);
nPulse = round(info.tPulse / dt);
nRest  = round(info.tRest  / dt);
block  = [I * ones(nPulse, 1); zeros(nRest, 1)];
iProf  = [zeros(nLead, 1); repmat(block, info.nPulses, 1)];
t      = (0:numel(iProf)-1)' * dt;
end

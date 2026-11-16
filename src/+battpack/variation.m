function var = variation(Ns, seed, sigmaQ_pct, sigmaR_pct)
%BATTPACK.VARIATION Random group-to-group manufacturing variation.
%
%   var = battpack.variation(Ns)                    % defaults below
%   var = battpack.variation(Ns, seed, sigmaQ_pct, sigmaR_pct)
%
% Each of the Ns series groups (8 cells in parallel) gets its own capacity and
% resistance deviation, in percent, drawn from a normal distribution.
% Defaults (nominal pack): sigma 0.5 % capacity, 1.5 % resistance. Measured
% fresh LFP cells show ~0.3-0.5 % capacity and ~0.7-1.8 % resistance spread
% (TUM study of 1100 cells and follow-ups), so this is a realistic new pack.
% Use (1.0, 3.0) as a "mixed lots / aged" stress case for the imbalance test.
% A fixed seed keeps the "random" pack identical on every run, so results are
% reproducible.
if nargin < 2 || isempty(seed),       seed = 42;  end
if nargin < 3 || isempty(sigmaQ_pct), sigmaQ_pct = 0.5; end
if nargin < 4 || isempty(sigmaR_pct), sigmaR_pct = 1.5; end
s = RandStream('mt19937ar', 'Seed', seed);
var.seed  = seed;
var.dQ    = sigmaQ_pct * randn(s, Ns, 1);       % capacity deviation [%]
var.dR    = sigmaR_pct * randn(s, Ns, 1);       % R0, R1, R2 deviation [%] (same per group)
var.sigmaQ_pct = sigmaQ_pct;
var.sigmaR_pct = sigmaR_pct;
end

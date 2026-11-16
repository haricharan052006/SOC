function m = measure(r, opts)
%SENSORS.MEASURE What the BMS actually sees: true plant signals + sensor errors.
%
%   m = sensors.measure(r)            % default BMS sensors
%   m = sensors.measure(r, opts)      % override any field below
%   r : plant output (battpack.unpackSim): r.I, r.v (N x Ns), r.T_C (N x Ns)
%
% Default sensor model (typical 16S 2W BMS):
%   current  : Hall/shunt, noise sigma 0.2 A, offset opts.I_offset (default 0 A),
%              10 mA resolution
%   voltage  : one tap per series group (AFE chip), noise sigma 2 mV, 1 mV resolution
%   temp     : 4 NTC thermistors (groups 2, 6, 11, 15), noise sigma 0.5 K,
%              each group uses its nearest NTC
% A fixed random seed keeps every test comparable.
if nargin < 2, opts = struct(); end
d = struct('I_sigma', 0.2, 'I_offset', 0, 'I_lsb', 0.01, ...
           'V_sigma', 0.002, 'V_lsb', 0.001, ...
           'T_sigma', 0.5, 'ntcGroups', [2 6 11 15], 'seed', 7);
fn = fieldnames(opts);
for k = 1:numel(fn), d.(fn{k}) = opts.(fn{k}); end

s  = RandStream('mt19937ar', 'Seed', d.seed);
[N, Ns] = size(r.v);
q  = @(x, lsb) lsb * round(x / lsb);

m.t = r.t;
m.I = q(r.I + d.I_offset + d.I_sigma * randn(s, N, 1), d.I_lsb);
m.v = q(r.v + d.V_sigma * randn(s, N, Ns), d.V_lsb);

ntc = r.T_C(:, d.ntcGroups) + d.T_sigma * randn(s, N, numel(d.ntcGroups));
[~, nearest] = min(abs((1:Ns)' - d.ntcGroups), [], 2);    % nearest NTC for each group
m.T_C = ntc(:, nearest);
m.cfg = d;
end

function m = socErrors(socEst, socTrue, t, thr)
%METRICS.SOCERRORS Accuracy numbers for an SOC estimate.
%
%   m = metrics.socErrors(socEst, socTrue, t)        % thr = 0.02 (2 % SOC)
%   socEst, socTrue : N x G (fraction 0..1). All groups are pooled.
%
%   m.rmse, m.mae, m.max   [% SOC]
%   m.final               mean |error| over the last 60 s [% SOC]
%   m.recovery_s          time until |error| first stays below thr for 60 s
%                         in a row (worst group). Inf if it never settles.
%   m.binEdges / m.binRMSE  RMSE in 10 %-wide bands of true SOC - shows where
%                         along the OCV curve the estimator struggles.
if nargin < 4, thr = 0.02; end
e   = 100 * (socEst - socTrue);                 % % SOC
m.rmse = sqrt(mean(e(:).^2));
m.mae  = mean(abs(e(:)));
m.max  = max(abs(e(:)));
nEnd   = max(1, size(e, 1) - 59);
m.final = mean(abs(e(nEnd:end, :)), 'all');

hold = 60;                                      % samples (1 s each)
rec  = zeros(1, size(e, 2));
for g = 1:size(e, 2)
    ok  = abs(e(:, g)) < 100 * thr;
    run = conv(double(ok), ones(hold, 1), 'valid');   % run(k) = # ok samples in k..k+hold-1
    k   = find(run == hold, 1);
    if isempty(k), rec(g) = Inf; else, rec(g) = t(k) - t(1); end
end
m.recovery_s = max(rec);

m.binEdges = 0:10:100;
st = 100 * socTrue(:);
m.binRMSE = nan(1, numel(m.binEdges) - 1);
for b = 1:numel(m.binEdges) - 1
    in = st >= m.binEdges(b) & st < m.binEdges(b + 1);
    if any(in), m.binRMSE(b) = sqrt(mean(e(in).^2)); end
end
end

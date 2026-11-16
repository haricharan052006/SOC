function est = runPack(meas, cfg, method, opts)
%ESTIMATORS.RUNPACK Run one SOC estimator on every series group of the pack.
%
%   est = estimators.runPack(meas, cfg, method, opts)
%   meas   : sensors.measure(...) output (pack current, group voltages, temps)
%   method : 'CC' | 'EKF' | 'EKF-noH' (EKF whose model ignores hysteresis)
%   opts   : soc0 (scalar or Ns x 1, what the BMS assumes at start),
%            h0   hysteresis start, -1..+1 x M (default 0 = unknown;
%                 +1 = just charged, the BMS saw the charge),
%            plus any estimators.ekf options (P0, Q, R, correction)
%
% est.soc  (N x Ns) per-group SOC estimate
% est.pack (N x 1)  displayed pack SOC = weakest group (the BMS must stop
%                   when the first group is empty, so this is what the rider sees)
% est.diag          EKF diagnostics of one group (H_soc, K_soc, P_soc, innov)
[N, Ns] = size(meas.v);
dt   = meas.t(2) - meas.t(1);
p    = cfg.cell;                                % the BMS's belief about the cell
i_c  = meas.I / cfg.Np;                         % assume equal split inside a group
soc0 = opts.soc0(:) .* ones(Ns, 1);
est.soc = zeros(N, Ns);

switch method
    case 'CC'
        for g = 1:Ns
            est.soc(:, g) = estimators.coulombCount(i_c, dt, p.Q_Ah, soc0(g));
        end
    case {'EKF', 'EKF-noH'}
        if strcmp(method, 'EKF-noH'), p.M_hyst = 0; end
        if ~isfield(opts, 'h0'), opts.h0 = 0; end
        for g = 1:Ns
            o = rmfield(opts, intersect(fieldnames(opts), {'soc0', 'h0'}));
            o.x0 = [soc0(g); 0; 0; opts.h0 * p.M_hyst];
            r = estimators.ekf(i_c, meas.v(:, g), meas.T_C(:, g), dt, p, o);
            est.soc(:, g) = r.soc;
            if g == 1, est.diag = rmfield(r, {'x', 'soc'}); end
        end
    otherwise
        error('Unknown method %s', method);
end
est.pack   = min(est.soc, [], 2);
est.method = method;
end

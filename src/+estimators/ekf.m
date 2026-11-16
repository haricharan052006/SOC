function out = ekf(i_cell, v_meas, T_meas, dt, p, opts)
%ESTIMATORS.EKF Extended Kalman Filter SOC estimator on the 2RC + hysteresis model.
%
%   out = estimators.ekf(i_cell, v_meas, T_meas, dt, p, opts)
%   i_cell : N x 1 measured cell current [A] (+ = discharge)
%   v_meas : N x 1 measured cell (group) voltage [V]
%   T_meas : N x 1 measured temperature [degC]
%   p      : model parameters the BMS believes (lfp.cellParams)
%   opts   : struct with fields (defaults in brackets)
%     x0   initial state [soc0; 0; 0; 0]          (soc0 required)
%     P0   initial covariance diag([0.05 0.01 0.01 M]^2)
%     Q    process noise   diag([1e-5 2e-4 2e-4 1e-4]^2)
%     R    voltage noise variance (3 mV)^2  (2 mV sensor + model error)
%     correction  optional function handle  dx = f(x, P, innov, H, i, T)
%                 added after the Kalman update - hook for the future
%                 "learned correction" (capstone). Default: none.
%
% Each step k:  1) UPDATE with the voltage measured at k (Kalman gain K)
%               2) PREDICT to k+1 with the measured current (model lfp.cellStep)
%
% Output: soc, x (N x 4), P_soc (variance), K_soc (Kalman gain on SOC),
%         H_soc (dV/dSOC), innov (measured - predicted voltage).
N = numel(i_cell);
M = p.M_hyst;
if ~isfield(opts, 'P0'), opts.P0 = diag([0.05 0.01 0.01 max(M, 1e-3)].^2); end
if ~isfield(opts, 'Q'),  opts.Q  = diag([1e-5 2e-4 2e-4 1e-4].^2); end
if ~isfield(opts, 'R'),  opts.R  = 0.003^2; end
if ~isfield(opts, 'correction'), opts.correction = []; end

x = opts.x0(:);  P = opts.P0;  Q = opts.Q;  R = opts.R;  I4 = eye(4);
out.x     = zeros(N, 4);
out.P_soc = zeros(N, 1);  out.K_soc = zeros(N, 1);
out.H_soc = zeros(N, 1);  out.innov = zeros(N, 1);

for k = 1:N
    i = i_cell(k);  T = T_meas(k);
    % ---- 1) measurement update ----
    [~, vPred] = lfp.cellStep(x, i, T, dt, p);
    [~, H]     = lfp.jacobians(x, i, T, dt, p);
    S     = H * P * H' + R;                    % innovation variance
    K     = P * H' / S;                        % Kalman gain (4 x 1)
    innov = v_meas(k) - vPred;
    x     = x + K * innov;
    P     = (I4 - K * H) * P * (I4 - K * H)' + K * R * K';   % Joseph form (stays positive)
    if ~isempty(opts.correction)
        x = x + opts.correction(x, P, innov, H, i, T);
    end
    % Soft limits only: the filter's internal SOC may go slightly past 0/100 %
    % (OCV is extended linearly there), the displayed SOC is clipped later.
    x(1) = min(max(x(1), -0.05), 1.05);
    x(4) = min(max(x(4), -M), M);

    out.x(k, :) = x';  out.P_soc(k) = P(1, 1);  out.K_soc(k) = K(1);
    out.H_soc(k) = H(1);  out.innov(k) = innov;

    % ---- 2) time update (predict) ----
    [F, ~] = lfp.jacobians(x, i, T, dt, p);
    x = lfp.cellStep(x, i, T, dt, p);
    P = F * P * F' + Q;
end
out.soc = min(max(out.x(:, 1), 0), 1);         % displayed SOC
end

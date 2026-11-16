function soc = coulombCount(i_cell, dt, Q_Ah, soc0)
%ESTIMATORS.COULOMBCOUNT Baseline SOC estimator: integrate the measured current.
%
%   soc = estimators.coulombCount(i_cell, dt, Q_Ah, soc0)
%   i_cell : N x 1 measured cell current [A] (+ = discharge)
%   Q_Ah   : capacity the BMS believes the cell has [Ah] (nameplate)
%   soc0   : SOC the BMS starts from
%
%   soc(k+1) = soc(k) - i(k)*dt / (3600*Q)
%
% Strength : exact if current and capacity are exact, no model needed.
% Weakness : open loop - any current offset, wrong start or capacity error
%            is never corrected; the error grows with time.
soc = soc0 - [0; cumsum(i_cell(1:end-1))] * dt / (3600 * Q_Ah);
end

function r = unpackSim(out)
%BATTPACK.UNPACKSIM Convert lfp_pack_plant simulation output to plain arrays.
%
%   r = battpack.unpackSim(out)
%   r.t [s], r.I [A] (+ = discharge), r.V [V]           - what the BMS measures
%   r.soc, r.T_C, r.v  (N x Ns)                          - true per-group SOC,
%                                                          temperature [degC], voltage [V]
% Probe signals arrive as Ns x 1 x N arrays; this reshapes them to N x Ns.
g = @(x) permute(squeeze(x), [2 1]);
r.I   = out.I_pack(:);
r.V   = out.V_pack(:);
r.soc = g(out.soc_g);
r.T_C = g(out.temp_g) - 273.15;
r.v   = g(out.v_g);
N = min([numel(r.I), numel(r.V), size(r.soc, 1)]);
r.I = r.I(1:N);  r.V = r.V(1:N);
r.soc = r.soc(1:N, :);  r.T_C = r.T_C(1:N, :);  r.v = r.v(1:N, :);
r.t = (0:N-1)' + 0.5;           % samples are logged mid-interval (see build_pack_model)
end

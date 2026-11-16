function r = runPlant(cfg, var, T_amb, P, opts)
%BATTPACK.RUNPLANT Simulate the Simscape 16S8P plant (models/lfp_pack_plant.slx).
%
%   r = battpack.runPlant(cfg, var, T_amb, P, opts)
%   cfg   : battpack.config() (its cell params define the PLANT cell)
%   var   : battpack.variation(...) or [] for identical groups
%   T_amb : ambient temperature [degC]
%   P     : N x 1 battery power demand [W] at 1 s steps (+ = discharge)
%   opts  : optional fields
%     SOC0      initial group SOC (scalar or Ns x 1)            [1]
%     h0        initial hysteresis state -1..+1 (scalar/vector)  [+1, just charged]
%     SOC_stop  stop when the weakest group reaches this SOC     [cfg.SOC_min_usable]
%     bal_enable, bal_dV, bal_Ts  passive balancing (on/off, threshold V, BMS period s) [0, 0.005, 1]
%     MaxStep   solver max step [s]                              [1]
%     logDt     logging interval [s]                             [1]
%
% Returns battpack.unpackSim output (t, I, V, soc, T_C, v).
if nargin < 5, opts = struct(); end
d = struct('SOC0', 1, 'h0', 1, 'SOC_stop', cfg.SOC_min_usable, ...
           'bal_enable', 0, 'bal_dV', 0.005, 'bal_Ts', 1, 'MaxStep', 1, 'logDt', 1);
fn = fieldnames(opts);
for k = 1:numel(fn), d.(fn{k}) = opts.(fn{k}); end

mdl = 'lfp_pack_plant';
load_system(mdl);
Ns = cfg.Ns;
t  = (0:numel(P)-1)';
in = Simulink.SimulationInput(mdl);
in = in.setVariable('Pack16S',    battpack.simscapeParams(cfg, T_amb, var));
in = in.setVariable('P_profile',  [t, P(:)]);
in = in.setVariable('T_amb_K',    T_amb + 273.15);
in = in.setVariable('SOC0_vec',   d.SOC0(:) .* ones(Ns, 1));
in = in.setVariable('h0_vec',     d.h0(:)   .* ones(Ns, 1));
in = in.setVariable('T0_vec_K',   (T_amb + 273.15) * ones(Ns, 1));
in = in.setVariable('SOC_stop',   d.SOC_stop);
in = in.setVariable('t_stop',     t(end));
in = in.setVariable('bal_enable', d.bal_enable);
in = in.setVariable('bal_dV',     d.bal_dV);
in = in.setVariable('bal_Ts',     d.bal_Ts);
in = in.setVariable('cb_cmd',     zeros(Ns, 1));        % legacy variable, unused
in = in.setModelParameter('MaxStep', num2str(d.MaxStep));
for b = {'I_pack', 'V_pack', 'SOC_groups', 'T_groups', 'V_groups'}
    in = in.setBlockParameter([mdl '/' b{1}], 'SampleTime', sprintf('[%g %g]', d.logDt, d.logDt / 2));
end
out = sim(in);
r = battpack.unpackSim(out);
r.t = (0:numel(r.I)-1)' * d.logDt + d.logDt / 2;
end

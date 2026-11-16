%% Week 2 - 16S8P Simscape pack on repeated MIDC at 25 degC and 45 degC
% What : drive the Simscape Battery pack (thermal model + group-to-group
%        variation) with the MIDC power demand until the weakest group hits
%        10 % SOC, at 25 degC and 45 degC ambient.
% Why  : this is the "truth" the BMS will try to estimate in week 3. Here we
%        check it is physically sensible (vs. the ideal MATLAB pack) and
%        measure range, temperature rise and temperature/SOC spread.
%
% Run from repo root:  setup_paths; week2_pack_midc
% (first run builds the pack: ~1 min; each drive simulation: ~1-3 min)

clear; close all;
root   = fileparts(fileparts(mfilename('fullpath')));
figDir = fullfile(root, 'results', 'figures');
tabDir = fullfile(root, 'results', 'tables');
mdl    = 'lfp_pack_plant';
if ~isfile(fullfile(root, 'models', [mdl '.slx'])) || ~isfile(fullfile(root, 'models', 'lfp_pack16s_lib.slx'))
    build_pack_model();
end
load_system(mdl);

cfg  = battpack.config();
var  = battpack.variation(cfg.Ns);           % seed 42: same "random" pack every run
cyc  = profiles.midc(1);
d    = vehicle.powerDemand(cyc, vehicle.params());
nCyc = 8;                                    % more than enough to reach 10 % SOC
P    = repmat(d.P_batt, nCyc, 1);
t    = (0:numel(P)-1)';
temps = [25 45];

fprintf('\nGroup variation (seed %d): capacity %s %%\n', var.seed, mat2str(round(var.dQ', 1)));
fprintf('                          resistance %s %%\n', mat2str(round(var.dR', 1)));

res = struct();
for n = 1:numel(temps)
    T  = temps(n);
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('Pack16S',  battpack.simscapeParams(cfg, T, var));
    in = in.setVariable('P_profile', [t, P]);
    in = in.setVariable('T_amb_K',  T + 273.15);
    in = in.setVariable('cb_cmd',   zeros(cfg.Ns, 1));
    in = in.setVariable('SOC0_vec', ones(cfg.Ns, 1));
    in = in.setVariable('T0_vec_K', (T + 273.15) * ones(cfg.Ns, 1));
    in = in.setVariable('h0_vec',   ones(cfg.Ns, 1));      % just charged: on the charge branch
    in = in.setVariable('bal_enable', 0);  in = in.setVariable('bal_dV', 0.005);  in = in.setVariable('bal_Ts', 1);
    in = in.setVariable('SOC_stop', cfg.SOC_min_usable);
    in = in.setVariable('t_stop',   t(end));
    tic;  out = sim(in);  tSim = toc;
    r  = battpack.unpackSim(out);
    k  = numel(r.t);

    dist = cumsum(repmat(cyc.v, nCyc, 1)) / 1000;
    spreadT = max(r.T_C, [], 2) - min(r.T_C, [], 2);
    spreadS = max(r.soc, [], 2) - min(r.soc, [], 2);
    [~, gHot]  = max(r.T_C(end, :));
    [~, gWeak] = min(r.soc(end, :));

    % ideal MATLAB pack (identical cells, constant temperature) for comparison
    ri = battpack.simulateIdeal(P, T, 1, cfg, cfg.SOC_min_usable);
    nn = min(k, ri.kEnd - 1);

    res(n).T = T;  res(n).r = r;  res(n).ri = ri;  res(n).dist = dist(1:k);
    res(n).range_km   = dist(k);
    res(n).range_ideal_km = dist(ri.kEnd);
    res(n).Tmax       = max(r.T_C(:));
    res(n).dTrise     = max(r.T_C(:)) - T;
    res(n).spreadT_max = max(spreadT);
    res(n).spreadT_end = spreadT(end);
    res(n).spreadSOC_end = 100 * spreadS(end);
    res(n).gHot = gHot;  res(n).gWeak = gWeak;
    res(n).Vrms_vs_ideal = rms(r.V(1:nn) - ri.V(1:nn));
    res(n).tSim = tSim;

    fprintf(['\n%d C ambient (sim %.0f s): range %.1f km (ideal pack %.1f km), ', ...
             'T max %.1f C (+%.1f K), spread max %.1f K (end %.1f K, hottest group %d)\n', ...
             '      SOC spread at stop %.2f %% (weakest group %d), pack V vs ideal rms %.2f V\n'], ...
            T, tSim, res(n).range_km, res(n).range_ideal_km, res(n).Tmax, res(n).dTrise, ...
            res(n).spreadT_max, res(n).spreadT_end, gHot, res(n).spreadSOC_end, gWeak, res(n).Vrms_vs_ideal);
end

%% Summary table
Tab = table([res.T]', [res.range_km]', [res.range_ideal_km]', [res.Tmax]', [res.dTrise]', ...
            [res.spreadT_max]', [res.spreadSOC_end]', [res.Vrms_vs_ideal]', ...
    'VariableNames', {'Ambient_C', 'Range_km', 'RangeIdealPack_km', 'Tmax_C', 'TempRise_K', ...
                      'TempSpreadMax_K', 'SOCSpreadAtStop_pct', 'PackV_RMSvsIdeal_V'});
disp(Tab);
writetable(Tab, fullfile(tabDir, 'w2_pack_midc_summary.csv'));

%% Figure 1: group temperatures
f1 = figure('Position', [100 100 1000 600]); theme(f1, 'light');
tl = tiledlayout(2, 2, 'TileSpacing', 'compact');
cmap = parula(cfg.Ns + 2);
for n = 1:2
    nexttile(n); hold on; grid on;
    for g = 1:cfg.Ns
        plot(res(n).dist, res(n).r.T_C(:, g), 'Color', cmap(g, :), 'LineWidth', 0.9);
    end
    yline(60, 'r--', 'LFP max 60 °C', 'LabelHorizontalAlignment', 'left');
    ylabel('Group temperature [°C]'); title(sprintf('%d °C ambient', res(n).T));
    nexttile(n + 2); hold on; grid on;
    plot(res(n).dist, max(res(n).r.T_C, [], 2) - min(res(n).r.T_C, [], 2), 'k', 'LineWidth', 1.2);
    ylabel('Spread max-min [K]'); xlabel('Distance [km]');
end
cb = colorbar(nexttile(2)); cb.Label.String = 'Group number (1 = pack edge)'; colormap(cmap); clim([1 cfg.Ns]);
title(tl, '16S8P pack on repeated MIDC: temperature of each series group');
exportgraphics(f1, fullfile(figDir, 'w2_pack_temperatures.png'), 'Resolution', 150);

%% Figure 2: SOC drift between groups + voltage check vs ideal pack
f2 = figure('Position', [100 100 1000 600]); theme(f2, 'light');
tl2 = tiledlayout(2, 2, 'TileSpacing', 'compact');
for n = 1:2
    nexttile(n); hold on; grid on;
    r = res(n).r;
    plot(res(n).dist, 100 * (r.soc - mean(r.soc, 2)), 'LineWidth', 0.8);
    ylabel('Group SOC - pack mean [%]'); xlabel('Distance [km]');
    title(sprintf('%d °C: groups drift apart (capacity variation)', res(n).T));
end
nexttile(3, [1 2]); hold on; grid on;
r = res(1).r;  ri = res(1).ri;  w = 1:min(1180, numel(r.V));
plot(r.t(w), r.V(w), 'LineWidth', 1.3);
plot(ri.t(w) + 0.5, ri.V(w), '--', 'LineWidth', 1.0);
ylabel('Pack voltage [V]'); xlabel('Time [s]');
legend('Simscape pack (variation + thermal)', 'MATLAB ideal pack', 'Location', 'southwest');
title('First MIDC at 25 °C: Simscape pack vs MATLAB reference');
title(tl2, 'Pack behaviour on MIDC');
exportgraphics(f2, fullfile(figDir, 'w2_pack_soc_voltage.png'), 'Resolution', 150);

save(fullfile(root, 'results', 'w2_pack_runs.mat'), 'res', 'var', 'cfg', '-v7.3');
fprintf('Saved figures, results/tables/w2_pack_midc_summary.csv and results/w2_pack_runs.mat\n');

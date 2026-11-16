%% Week 4 - Stress tests, passive balancing and the final comparison table
% What : four new Simscape plant runs and the remaining estimator stress tests:
%   A1  cell imbalance   : groups start 0-5 % apart + "mixed lot" variation
%                          (1 % capacity, 3 % resistance); BMS thinks all are full
%   A2  hysteresis error : real cells have a 34 mV gap, BMS model assumes 20 mV
%   A3  Indian city ride : IDC at 45 degC until 10 % SOC
%   A4  passive balancing: imbalanced pack at rest near full, 100 mA bleed per group
%   + 45 degC with a +1 A current-sensor offset (re-uses the week-2 45 degC run)
% Then merges Week 3 + Week 4 into results/tables/final_comparison.csv/.md
%
% Plant runs are cached in results/w4_plant_runs.mat (delete it to re-run).
% Run from repo root:  setup_paths; week4_stress_balancing   (~20 min first time)

clear; close all;
root   = fileparts(fileparts(mfilename('fullpath')));
figDir = fullfile(root, 'results', 'figures');
tabDir = fullfile(root, 'results', 'tables');
cache  = fullfile(root, 'results', 'w4_plant_runs.mat');
cfg    = battpack.config();
Ns     = cfg.Ns;  M = cfg.cell.M_hyst;
veh    = vehicle.params();

% Imbalance pattern (seeded): highest group full, others up to 5 % lower
rs     = RandStream('mt19937ar', 'Seed', 11);
imb    = 0.05 * rand(rs, Ns, 1);  imb = imb - min(imb);
SOC0i  = 1 - imb;
varNom = battpack.variation(Ns);                 % nominal new pack
varMix = battpack.variation(Ns, 42, 1.0, 3.0);   % mixed lots / aged: stress case

%% Plant runs (cached)
if isfile(cache)
    load(cache, 'P');
    fprintf('Loaded cached plant runs from %s\n', cache);
else
    midc = profiles.midc(1);
    Pm   = repmat(vehicle.powerDemand(midc, veh).P_batt, 8, 1);
    idc  = profiles.idc(1, 200);
    Pi   = vehicle.powerDemand(idc, veh).P_batt;

    fprintf('A1 imbalance (MIDC, 25 C)...\n');  tic;
    P.A1 = battpack.runPlant(cfg, varMix, 25, Pm, struct('SOC0', SOC0i));  toc
    fprintf('A2 hysteresis 34 mV (MIDC, 25 C)...\n');  tic;
    cfgH = cfg;  cfgH.cell.M_hyst = 0.017;
    P.A2 = battpack.runPlant(cfgH, varNom, 25, Pm, struct());  toc
    fprintf('A3 IDC city ride (45 C)...\n');  tic;
    P.A3 = battpack.runPlant(cfg, varNom, 45, Pi, struct());  toc
    P.A3.dist_km = cumsum(idc.v(1:numel(P.A3.t))) / 1000;
    fprintf('A4 passive balancing at rest (36 h)...\n');  tic;
    P.A4 = battpack.runPlant(cfg, varMix, 25, zeros(36*3600, 1), ...
        struct('SOC0', SOC0i, 'bal_enable', 1, 'bal_dV', 0.005, 'bal_Ts', 10, ...
               'MaxStep', 60, 'logDt', 60, 'SOC_stop', 0));  toc
    save(cache, 'P', '-v7.3');
end

%% Estimator runs
S3   = load(fullfile(root, 'results', 'w2_pack_runs.mat'));
known  = struct('soc0', 1.0, 'h0', 1, 'P0', diag([0.02 0.01 0.01 0.3*M].^2));
knownI = known;  knownI.P0(1, 1) = 0.05^2;      % after charge, but groups may not all be full
methods = {'CC', 'EKF-noH', 'EKF'};
sc = struct('name', {}, 'r', {}, 'sens', {}, 'opts', {});
sc(end+1) = struct('name', 'Cell imbalance 0-5% (mixed lot)', 'r', P.A1,          'sens', struct(),                'opts', knownI);
sc(end+1) = struct('name', 'Hysteresis 34 mV (model 20 mV)',  'r', P.A2,          'sens', struct(),                'opts', known);
sc(end+1) = struct('name', 'IDC city ride, 45C',               'r', P.A3,          'sens', struct(),                'opts', known);
sc(end+1) = struct('name', '45C + current offset +1 A',        'r', S3.res(2).r,   'sens', struct('I_offset', 1.0), 'opts', known);

rows = {};  keep = struct();
for s = 1:numel(sc)
    r = sc(s).r;  meas = sensors.measure(r, sc(s).sens);
    for mth = methods
        e  = estimators.runPack(meas, cfg, mth{1}, sc(s).opts);
        mg = metrics.socErrors(e.soc,  r.soc, r.t);
        mp = metrics.socErrors(e.pack, min(r.soc, [], 2), r.t);
        rows(end+1, :) = {sc(s).name, mth{1}, mg.rmse, mg.mae, mg.max, mp.rmse, mp.max, mg.recovery_s, mg.final}; %#ok<SAGROW>
        keep(s).(strrep(mth{1}, '-', '_')) = struct('e', e, 'mg', mg);
        fprintf('%-32s %-8s RMSE %5.2f  MAE %5.2f  max %5.2f | pack RMSE %5.2f max %5.2f | final %4.2f %%\n', ...
                sc(s).name, mth{1}, mg.rmse, mg.mae, mg.max, mp.rmse, mp.max, mg.final);
    end
end
T4 = cell2table(rows, 'VariableNames', {'Scenario', 'Method', 'RMSE_pct', 'MAE_pct', 'MaxErr_pct', ...
                 'PackRMSE_pct', 'PackMaxErr_pct', 'Recovery_s', 'FinalErr_pct'});

%% Thermal numbers for the IDC ride and the MIDC runs
A3 = P.A3;
spreadA3 = max(A3.T_C, [], 2) - min(A3.T_C, [], 2);
fprintf('\nIDC 45 C: range %.1f km to %.0f %% SOC, T max %.1f C (+%.1f K), max group spread %.2f K\n', ...
        A3.dist_km(end), 100 * cfg.SOC_min_usable, max(A3.T_C(:)), max(A3.T_C(:)) - 45, max(spreadA3));

%% Balancing analysis
A4 = P.A4;  th = A4.t / 3600;
spr  = 100 * (max(A4.soc, [], 2) - min(A4.soc, [], 2));
vspr = 1e3 * (max(A4.v, [], 2) - min(A4.v, [], 2));
k1   = find(spr < 1.0, 1);  if isempty(k1), t1 = Inf; else, t1 = th(k1); end
Ib   = mean(A4.v(1, :)) / 33;
tTheory = 100 * max(imb) / 100 * cfg.Q_Ah / Ib;  % h to bleed the worst group's excess at Ib
fprintf('Balancing: SOC spread %.2f %% -> %.2f %% after %.0f h (time to <1 %%: %.1f h); voltage spread %.1f -> %.1f mV\n', ...
        spr(1), spr(end), th(end), t1, vspr(1), vspr(end));
fprintf('           bleed %.0f mA per group; ideal time for %.1f %% x %.0f Ah = %.1f h\n', ...
        1e3 * Ib, 100 * max(imb), cfg.Q_Ah, tTheory);
balance = struct('spread0', spr(1), 'spreadEnd', spr(end), 't_below1pct_h', t1, ...
                 'vspread0_mV', vspr(1), 'vspreadEnd_mV', vspr(end), 'bleed_mA', 1e3 * Ib, 't_ideal_h', tTheory);

%% Final comparison table (Week 3 + Week 4)
T3 = readtable(fullfile(tabDir, 'w3_estimator_results.csv'), 'TextType', 'char');
T  = [T3; T4];
writetable(T, fullfile(tabDir, 'final_comparison.csv'));
fid = fopen(fullfile(tabDir, 'final_comparison.md'), 'w');
fprintf(fid, '| Scenario | CC RMSE / max | EKF-noH RMSE / max | EKF RMSE / max | EKF recovery |\n|---|---|---|---|---|\n');
scen = unique(T.Scenario, 'stable');
for k = 1:numel(scen)
    g = T(strcmp(T.Scenario, scen{k}), :);
    f = @(m) g(strcmp(g.Method, m), :);
    rec = f('EKF').Recovery_s;  if rec == 0, recS = '-'; elseif isinf(rec), recS = 'never'; else, recS = sprintf('%.0f s', rec); end
    fprintf(fid, '| %s | %.2f / %.2f %% | %.2f / %.2f %% | **%.2f / %.2f %%** | %s |\n', scen{k}, ...
            f('CC').RMSE_pct, f('CC').MaxErr_pct, f('EKF-noH').RMSE_pct, f('EKF-noH').MaxErr_pct, ...
            f('EKF').RMSE_pct, f('EKF').MaxErr_pct, recS);
end
fclose(fid);
disp(fileread(fullfile(tabDir, 'final_comparison.md')));

%% Figure 1: imbalance - per-group error at the end of the ride
K = keep(1);  r = P.A1;
f1 = figure('Position', [100 100 1000 420]); theme(f1, 'light');
tl = tiledlayout(1, 2, 'TileSpacing', 'compact');
nexttile; hold on; grid on;
bar(1:Ns, 100 * [imb, K.CC.e.soc(end, :)' - r.soc(end, :)', K.EKF.e.soc(end, :)' - r.soc(end, :)']);
xlabel('Series group'); ylabel('[% SOC]');
legend('Initial imbalance (true)', 'CC error at end', 'EKF error at end', 'Location', 'northwest');
title('BMS assumed every group was full');
nexttile; hold on; grid on;
tm = r.t / 60;
plot(tm, 100 * min(r.soc, [], 2), 'k', 'LineWidth', 1.6);
plot(tm, 100 * K.CC.e.pack, '--', 'LineWidth', 1.2);
plot(tm, 100 * K.EKF.e.pack, 'LineWidth', 1.2);
xlabel('Time [min]'); ylabel('Displayed SOC [%]');
legend('True (weakest group)', 'CC', 'EKF', 'Location', 'northeast');
title('Displayed pack SOC');
title(tl, 'Cell imbalance: CC cannot see it, the EKF finds each group''s SOC');
exportgraphics(f1, fullfile(figDir, 'w4_imbalance.png'), 'Resolution', 150);

%% Figure 2: passive balancing
f2 = figure('Position', [100 100 1000 600]); theme(f2, 'light');
tl2 = tiledlayout(2, 1, 'TileSpacing', 'compact');
nexttile; plot(th, 100 * A4.soc, 'LineWidth', 1.0); grid on;
ylabel('Group SOC [%]');
title(sprintf('Passive balancing at rest, %.0f mA bleed per group, voltage threshold %.0f mV', 1e3 * Ib, 5));
nexttile; hold on; grid on;
yyaxis left;  plot(th, spr, 'LineWidth', 1.4);  ylabel('SOC spread max-min [%]');
yyaxis right; plot(th, vspr, 'LineWidth', 1.2); ylabel('Voltage spread [mV]');
xlabel('Time [h]');
title('Spread shrinks while groups sit on the steep top of the OCV curve, then stalls on the plateau');
exportgraphics(f2, fullfile(figDir, 'w4_balancing.png'), 'Resolution', 150);

%% Figure 3: summary of RMSE by scenario
f3 = figure('Position', [100 100 1100 480]); theme(f3, 'light');
Y = zeros(numel(scen), 3);
for k = 1:numel(scen)
    for m = 1:3
        Y(k, m) = T.RMSE_pct(strcmp(T.Scenario, scen{k}) & strcmp(T.Method, methods{m}));
    end
end
b = bar(categorical(scen, scen), Y);  grid on;  set(gca, 'YScale', 'log');
ylabel('SOC RMSE [%] (log scale)'); legend('Coulomb counting', 'EKF without hysteresis', 'EKF (2RC + hysteresis)', 'Location', 'northwest');
title('SOC estimation error under Indian stress conditions (16S8P LFP e-scooter pack)');
exportgraphics(f3, fullfile(figDir, 'w4_final_rmse.png'), 'Resolution', 150);

save(fullfile(root, 'results', 'w4_results.mat'), 'T', 'balance', 'imb', '-v7.3');
fprintf('Saved final_comparison.csv/.md and Week 4 figures.\n');

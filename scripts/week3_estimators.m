%% Week 3 - SOC estimators on the Simscape pack: coulomb counting vs EKF
% What : the BMS sees only pack current, 16 group voltages and 4 NTCs (with
%        realistic sensor errors). Three estimators run on each group:
%          CC      coulomb counting (baseline)
%          EKF-noH EKF on the 2RC model WITHOUT hysteresis
%          EKF     EKF on the 2RC + hysteresis model
%        and are scored against the true group SOC from the Simscape plant.
% Why  : to measure how accurate each method stays under Indian conditions and
%        to show WHERE the EKF struggles - LFP's flat OCV region.
%
% Needs results/w2_pack_runs.mat (run week2_pack_midc first).
% Run from repo root:  setup_paths; week3_estimators

clear; close all;
root   = fileparts(fileparts(mfilename('fullpath')));
figDir = fullfile(root, 'results', 'figures');
tabDir = fullfile(root, 'results', 'tables');
S   = load(fullfile(root, 'results', 'w2_pack_runs.mat'));
cfg = battpack.config();
M   = cfg.cell.M_hyst;
methods = {'CC', 'EKF-noH', 'EKF'};

% BMS knowledge at key-on after a full charge: SOC = 100 %, on the charge
% branch (h = +M), small uncertainty. After an unknown history: h unknown.
known   = struct('soc0', 1.0, 'h0', 1, 'P0', diag([0.02 0.01 0.01 0.3*M].^2));
unknown = @(s0) struct('soc0', s0, 'h0', 0, 'P0', diag([0.30 0.01 0.01 M].^2));

%% Scenario definitions
r25 = S.res(1).r;  r45 = S.res(2).r;
k65 = find(mean(r25.soc, 2) <= 0.65, 1);        % mid-plateau restart point
sc = struct('name', {}, 'r', {}, 'sens', {}, 'opts', {}, 'k0', {});
sc(end+1) = struct('name', '25C baseline',              'r', r25, 'sens', struct(),                 'opts', known,          'k0', 1);
sc(end+1) = struct('name', '45C ambient',               'r', r45, 'sens', struct(),                 'opts', known,          'k0', 1);
sc(end+1) = struct('name', '25C current offset +1 A',   'r', r25, 'sens', struct('I_offset', 1.0),  'opts', known,          'k0', 1);
sc(end+1) = struct('name', '25C init -30% (at 100%)',   'r', r25, 'sens', struct(),                 'opts', unknown(0.70),  'k0', 1);
sc(end+1) = struct('name', '25C init -30% (flat, 65%)', 'r', r25, 'sens', struct(),                 'opts', unknown(0.35),  'k0', k65);

%% Run
rows = {};  keep = struct();
for s = 1:numel(sc)
    r    = sc(s).r;
    idx  = sc(s).k0:numel(r.t);
    rr   = struct('t', r.t(idx), 'I', r.I(idx), 'v', r.v(idx, :), 'T_C', r.T_C(idx, :), 'soc', r.soc(idx, :));
    meas = sensors.measure(rr, sc(s).sens);
    trueG = rr.soc;  trueP = min(rr.soc, [], 2);
    for mth = methods
        e  = estimators.runPack(meas, cfg, mth{1}, sc(s).opts);
        mg = metrics.socErrors(e.soc,  trueG, rr.t);
        mp = metrics.socErrors(e.pack, trueP, rr.t);
        rows(end+1, :) = {sc(s).name, mth{1}, mg.rmse, mg.mae, mg.max, mp.rmse, mp.max, ...
                          mg.recovery_s, mg.final}; %#ok<SAGROW>
        keep(s).(strrep(mth{1}, '-', '_')) = struct('e', e, 'mg', mg);
        fprintf('%-27s %-8s RMSE %5.2f  MAE %5.2f  max %5.2f | pack RMSE %5.2f max %5.2f | recovery %6.0f s | final %4.2f %%\n', ...
                sc(s).name, mth{1}, mg.rmse, mg.mae, mg.max, mp.rmse, mp.max, mg.recovery_s, mg.final);
    end
    keep(s).t = rr.t;  keep(s).trueG = trueG;  keep(s).trueP = trueP;
end
Tab = cell2table(rows, 'VariableNames', {'Scenario', 'Method', 'RMSE_pct', 'MAE_pct', 'MaxErr_pct', ...
                 'PackRMSE_pct', 'PackMaxErr_pct', 'Recovery_s', 'FinalErr_pct'});
writetable(Tab, fullfile(tabDir, 'w3_estimator_results.csv'));

%% Figure 1: baseline and offset - displayed (pack) SOC over the drive
f1 = figure('Position', [100 100 1000 650]); theme(f1, 'light');
tl = tiledlayout(2, 2, 'TileSpacing', 'compact');
for c = 1:2
    s  = [1 3];  s = s(c);  K = keep(s);  th = K.t / 60;
    nexttile(c); hold on; grid on;
    plot(th, 100 * K.trueP, 'k', 'LineWidth', 1.6);
    plot(th, 100 * K.CC.e.pack, '--', 'LineWidth', 1.2);
    plot(th, 100 * K.EKF.e.pack, 'LineWidth', 1.2);
    ylabel('Displayed SOC [%]'); title(sc(s).name);
    legend('True (weakest group)', 'Coulomb counting', 'EKF', 'Location', 'northeast');
    nexttile(c + 2); hold on; grid on;
    plot(th, 100 * (K.CC.e.pack  - K.trueP), '--', 'LineWidth', 1.2);
    plot(th, 100 * (K.EKF_noH.e.pack - K.trueP), ':', 'LineWidth', 1.4);
    plot(th, 100 * (K.EKF.e.pack - K.trueP), 'LineWidth', 1.2);
    yline(0, 'k'); ylabel('Error [% SOC]'); xlabel('Time [min]');
    legend('CC', 'EKF without hysteresis', 'EKF', 'Location', 'northwest');
end
title(tl, 'Displayed pack SOC on repeated MIDC (16S8P LFP, Simscape plant)');
exportgraphics(f1, fullfile(figDir, 'w3_baseline_offset.png'), 'Resolution', 150);

%% Figure 2: wrong initial SOC - steep end vs flat region
f2 = figure('Position', [100 100 1000 420]); theme(f2, 'light');
tl2 = tiledlayout(1, 2, 'TileSpacing', 'compact');
for c = 1:2
    s = 3 + c;  K = keep(s);  th = (K.t - K.t(1)) / 60;
    nexttile; hold on; grid on;
    plot(th, 100 * (K.CC.e.soc(:, 1)  - K.trueG(:, 1)), '--', 'LineWidth', 1.2);
    plot(th, 100 * (K.EKF_noH.e.soc(:, 1) - K.trueG(:, 1)), ':', 'LineWidth', 1.4);
    plot(th, 100 * (K.EKF.e.soc(:, 1) - K.trueG(:, 1)), 'LineWidth', 1.3);
    yline([-2 2], 'k:'); ylim([-35 10]);
    xlabel('Time since start [min]'); ylabel('Error, group 1 [% SOC]');
    title(sprintf('%s: EKF recovers in %.0f s', sc(s).name, K.EKF.mg.recovery_s));
    legend('CC (never recovers)', 'EKF without hysteresis', 'EKF', 'Location', 'southeast');
end
title(tl2, 'Recovery from a 30 % wrong initial SOC');
exportgraphics(f2, fullfile(figDir, 'w3_recovery.png'), 'Resolution', 150);

%% Figure 3: WHY - observability along the OCV curve
K  = keep(5);                                     % flat-region restart run (group 1)
st = 100 * K.trueG(:, 1);
f3 = figure('Position', [100 100 1000 650]); theme(f3, 'light');
tl3 = tiledlayout(3, 1, 'TileSpacing', 'compact');
nexttile; hold on; grid on;
s = linspace(0, 1, 501);  [~, dv] = lfp.ocv(s, cfg.cell);
plot(100 * s, 10 * dv, 'k', 'LineWidth', 1.4);
xregion(20, 90, 'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.12);
ylabel({'dOCV/dSOC', '[mV per %]'}); ylim([0 20]); set(gca, 'XDir', 'reverse');
title('How much the voltage "sees" SOC (observability)');
nexttile; hold on; grid on;
plot(st, abs(K.EKF.e.diag.K_soc) * 1e3 / 100, '.', 'MarkerSize', 4);
xregion(20, 90, 'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.12);
ylabel({'|Kalman gain on SOC|', '[% SOC per mV]'}); set(gca, 'XDir', 'reverse'); ylim([0 15]);
title('How strongly the EKF corrects SOC from each mV of voltage error');
nexttile; hold on; grid on;
plot(st, 100 * (K.EKF.e.soc(:, 1) - K.trueG(:, 1)), 'LineWidth', 1.3);
plot(st, 100 * sqrt(K.EKF.e.diag.P_soc), 'k--');  plot(st, -100 * sqrt(K.EKF.e.diag.P_soc), 'k--');
xregion(20, 90, 'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.12);
ylabel({'EKF error [% SOC]', '(dashed: ±1σ)'}); xlabel('True SOC [%]  (time runs left to right)');
set(gca, 'XDir', 'reverse');
title(sprintf('EKF started 30 %% low at 65 %% SOC: slow correction across the plateau (%.0f min to reach ±2 %%)', ...
      K.EKF.mg.recovery_s / 60));
title(tl3, 'Why the EKF degrades in LFP''s flat region');
exportgraphics(f3, fullfile(figDir, 'w3_flat_region_observability.png'), 'Resolution', 150);

save(fullfile(root, 'results', 'w3_estimator_runs.mat'), 'keep', 'sc', '-v7.3');
fprintf('\nSaved results/tables/w3_estimator_results.csv and 3 figures.\n');

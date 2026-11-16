%% Week 1 - LFP cell model: pulse-discharge test at 25 degC and 45 degC
% What : discharge one cell in 10 % SOC steps at 1C, resting 30 min after each step.
% Why  : this is a simplified HPPC / GITT-style test. It shows the three things the
%        model must capture: (1) the instant IR drop (R0), (2) the slow relaxation
%        (two RC pairs), and (3) the flat LFP OCV plateau that later hurts the EKF.
%
% Run from repo root:  setup_paths; week1_cell_pulse_test

clear; close all;
p    = lfp.cellParams();
dt   = 1;                       % [s]
I1C  = p.Q_Ah;                  % 1C current [A]
temps = [25 45];                % [degC] isothermal for now (thermal model in week 2)
figDir = fullfile(fileparts(mfilename('fullpath')), '..', 'results', 'figures');
if ~isfolder(figDir), mkdir(figDir); end

%% Build current profile: 10 min rest, then 10 x (6 min @1C + 30 min rest)
[iProf, t, info] = profiles.pulseDischarge(I1C, dt);
tPulse = info.tPulse;  tRest = info.tRest;

%% Simulate
res = struct();
for n = 1:numel(temps)
    x0 = [1; 0; 0; 0];          % full, relaxed, no hysteresis
    [V, X, kEnd] = lfp.simulate(iProf, temps(n), dt, x0, p, p.V_min);   % stop at cut-off
    res(n).T = temps(n);  res(n).V = V;  res(n).X = X;  res(n).kEnd = kEnd;
end

%% Figure 1: full test
f1 = figure('Position', [100 100 900 600]);
theme(f1, 'light');             % light plots even if MATLAB itself is in dark mode
tl = tiledlayout(3,1, 'TileSpacing', 'compact');
nexttile; hold on; grid on;
for n = 1:numel(res), plot(t/3600, res(n).V, 'LineWidth', 1.2); end
ylabel('Terminal voltage [V]'); legend(compose('%d °C', temps), 'Location', 'southwest');
nexttile; plot(t/3600, iProf, 'k', 'LineWidth', 1.2); grid on; ylabel('Current [A]');
nexttile; hold on; grid on;
for n = 1:numel(res), plot(t/3600, 100*res(n).X(:,1), 'LineWidth', 1.2); end
ylabel('SOC [%]'); xlabel('Time [h]');
title(tl, 'LFP cell (6 Ah) pulse-discharge test, 1C pulses');
exportgraphics(f1, fullfile(figDir, 'w1_pulse_test.png'), 'Resolution', 150);

%% Figure 2: one pulse zoom (pulse at ~50 % SOC) - shows R0 drop and RC relaxation
kStart = 10*60 + 5*(tPulse + tRest);         % start of 6th pulse (SOC 50 % -> 40 %)
idx    = (kStart - 60):(kStart + tPulse + tRest);
f2 = figure('Position', [100 100 900 400]); theme(f2, 'light'); hold on; grid on;
for n = 1:numel(res)
    plot((idx - kStart)*dt/60, res(n).V(idx), 'LineWidth', 1.4);
end
xline(0, '--'); xline(tPulse/60, '--');
xlabel('Time from pulse start [min]'); ylabel('Terminal voltage [V]');
legend(compose('%d °C', temps), 'Location', 'southeast');
title('Pulse at 50 % SOC: instant IR drop (R0), then slow RC relaxation');
exportgraphics(f2, fullfile(figDir, 'w1_pulse_zoom.png'), 'Resolution', 150);

%% Figure 3: OCV curve, hysteresis branches and slope (the "flat region" problem)
s = linspace(0, 1, 501);
[ocvAvg, dv] = lfp.ocv(s, p);
f3 = figure('Position', [100 100 900 450]); theme(f3, 'light');
yyaxis left; hold on; grid on;
plot(100*s, ocvAvg + p.M_hyst, '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2);
plot(100*s, ocvAvg,            '-',  'Color', [0.00 0.45 0.74], 'LineWidth', 1.8);
plot(100*s, ocvAvg - p.M_hyst, ':',  'Color', [0.47 0.67 0.19], 'LineWidth', 1.6);
ylabel('OCV [V]'); ylim([3.0 3.5]);
yyaxis right;
semilogy(100*s, 1000*dv/100, 'k-', 'LineWidth', 1.2);
set(gca, 'YColor', 'k');
ylabel('dOCV/dSOC [mV per %SOC]');
xregion(20, 90, 'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.12);
xlabel('SOC [%]');
legend({'Charge branch (+M)', 'Average OCV', 'Discharge branch (-M)', 'Slope', ...
        'Flat region 20-90 %'}, 'Location', 'northwest');
title('LFP OCV: in the flat region 1 % SOC moves the voltage by only ~1 mV');
exportgraphics(f3, fullfile(figDir, 'w1_ocv_flat_region.png'), 'Resolution', 150);

%% Numbers to quote
fprintf('\n===== Week 1 cell-model check =====\n');
q25 = lfp.paramsAt(0.5, 25, p);  q45 = lfp.paramsAt(0.5, 45, p);
fprintf('R0 @50%% SOC: 25 C = %.2f mOhm, 45 C = %.2f mOhm (%.0f %% lower)\n', ...
        1e3*q25.R0, 1e3*q45.R0, 100*(1 - q45.R0/q25.R0));
fprintf('Instant IR drop at 1C, 50%% SOC: 25 C = %.1f mV, 45 C = %.1f mV\n', ...
        1e3*q25.R0*I1C, 1e3*q45.R0*I1C);
inFlat = s >= 0.2 & s <= 0.9;
fprintf('OCV slope in 20-90%% SOC: min %.2f, mean %.2f, max %.2f mV per %%SOC\n', ...
        10*min(dv(inFlat)), 10*mean(dv(inFlat)), 10*max(dv(inFlat)));
fprintf('Hysteresis gap (charge - discharge OCV): %.0f mV = %.0f %%SOC of "voltage error" in the flat region\n', ...
        2e3*p.M_hyst, 2*p.M_hyst / mean(dv(inFlat)) * 100);
for n = 1:numel(res)
    kE = res(n).kEnd;
    % after the 6th rest the cell is ~relaxed: compare with OCV - M (discharge branch)
    kR = 10*60 + 6*(tPulse + tRest);
    vRelax = res(n).V(kR);  socR = res(n).X(kR,1);
    fprintf('%d C: delivered %.2f Ah, end SOC %.1f %%, V after 30 min rest at %.0f %% SOC = %.4f V (OCV-M = %.4f V)\n', ...
        res(n).T, sum(iProf(1:kE))*dt/3600, 100*res(n).X(kE,1), 100*socR, vRelax, lfp.ocv(socR,p) - p.M_hyst);
end
fprintf('Figures saved to results/figures/\n');

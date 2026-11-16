%% Week 2 - MIDC drive cycle -> battery power -> pack current (with range check)
% What : take the MIDC speed trace, compute the power the scooter needs at the
%        wheel and at the battery, then run the battery (16S8P, ideal identical
%        cells for now) through repeated MIDC cycles until 10 % SOC.
% Why  : this is the realistic load for every SOC test in weeks 3-4. The range
%        and Wh/km numbers let us sanity-check the vehicle model against real
%        Indian e-scooters before trusting it.
%
% Run from repo root:  setup_paths; week2_midc_load_profile

clear; close all;
root   = fileparts(fileparts(mfilename('fullpath')));
figDir = fullfile(root, 'results', 'figures');

cyc = profiles.midc(1);
veh = vehicle.params();
cfg = battpack.config();
p   = cfg.cell;
d   = vehicle.powerDemand(cyc, veh);
dt  = cyc.dt;

%% Energy of one MIDC at the battery
E_drive = sum(max(d.P_batt, 0)) * dt / 3600;          % Wh taken from battery
E_regen = -sum(min(d.P_batt, 0)) * dt / 3600;         % Wh put back by regen
E_net   = E_drive - E_regen;
fprintf('\n===== MIDC load profile (%s) =====\n', cyc.name);
fprintf('Cycle: %.0f s, %.2f km, vmax %.0f km/h, vavg %.1f km/h\n', cyc.dur_s, cyc.dist_km, cyc.vmax_kmh, cyc.vavg_kmh);
fprintf('Pack : %dS%dP, %.0f Ah, %.1f V nominal, %.2f kWh\n', cfg.Ns, cfg.Np, cfg.Q_Ah, cfg.V_nom, cfg.E_kWh);
fprintf('Battery energy per MIDC: %.1f Wh out, %.1f Wh regen (%.0f %% recovered), net %.1f Wh -> %.1f Wh/km\n', ...
        E_drive, E_regen, 100*E_regen/E_drive, E_net, E_net/cyc.dist_km);
fprintf('Peak battery power %.2f kW, peak regen %.2f kW, time power-limited %.0f s\n', ...
        max(d.P_batt)/1e3, -min(d.P_batt)/1e3, d.power_limited_s);

%% Range test: repeat MIDC until pack SOC reaches 10 %
temps = [25 45];
nMax  = 40;                                  % safety cap on cycles
Pcell = d.P_batt / (cfg.Ns * cfg.Np);        % identical cells: each carries 1/(Ns*Np) of the power
res   = struct();
for n = 1:numel(temps)
    T  = temps(n);
    x  = [1; 0; 0; 0];
    N  = nMax * numel(Pcell);
    I  = nan(N,1);  V = nan(N,1);  S = nan(N,1);
    k  = 0;
    for c = 1:nMax
        for j = 1:numel(Pcell)
            k = k + 1;
            S(k) = x(1);
            i_c  = lfp.currentFromPower(Pcell(j), x, T, p);
            [x, v_c] = lfp.cellStep(x, i_c, T, dt, p);
            I(k) = i_c * cfg.Np;             % pack current [A]
            V(k) = v_c * cfg.Ns;             % pack voltage [V]
        end
        if x(1) <= cfg.SOC_min_usable, break; end
    end
    kEnd = find(S <= cfg.SOC_min_usable, 1);
    if isempty(kEnd), kEnd = k; end
    dist = cumsum(repmat(cyc.v, c, 1)) * dt / 1000;     % [km]
    res(n).T = T;  res(n).I = I(1:kEnd);  res(n).V = V(1:kEnd);  res(n).S = S(1:kEnd);
    res(n).dist = dist(1:kEnd);  res(n).range_km = dist(kEnd);
    res(n).t = (0:kEnd-1)' * dt;
    fprintf('%d C: range to %.0f %% SOC = %.1f km (%.1f MIDC cycles), I peak %.0f A (%.1fC), I rms %.1f A, Vmin %.1f V\n', ...
        T, 100*cfg.SOC_min_usable, res(n).range_km, kEnd/numel(Pcell), max(res(n).I), max(res(n).I)/cfg.Q_Ah, ...
        rms(res(n).I), min(res(n).V));
end

%% Figure 1: one MIDC cycle - speed, power, current
nC = numel(cyc.t);
f1 = figure('Position', [100 100 950 700]); theme(f1, 'light');
tl = tiledlayout(3, 1, 'TileSpacing', 'compact');
nexttile; plot(cyc.t, cyc.v_kmh, 'k', 'LineWidth', 1.3); grid on;
ylabel('Speed [km/h]'); xline(cyc.part1_end_s, '--', 'Part 2 (EUDC-LP)', 'LabelVerticalAlignment', 'bottom');
title('Speed');
nexttile; hold on; grid on;
plot(cyc.t, d.P_wheel/1e3, 'Color', [0.6 0.6 0.6], 'LineWidth', 1.0);
plot(cyc.t, d.P_batt/1e3, 'Color', [0 0.45 0.74], 'LineWidth', 1.3);
yline(0, 'k:');
ylabel('Power [kW]'); legend('At wheel', 'At battery', 'Location', 'northwest');
title('Power (negative = regenerative braking)');
nexttile; hold on; grid on;
plot(cyc.t, res(1).I(1:nC), 'LineWidth', 1.3);
plot(cyc.t, res(2).I(1:nC), '--', 'LineWidth', 1.1);
ylabel('Pack current [A]'); xlabel('Time [s]');
yl = ylim;                                   % left-axis limits in A
yyaxis right; ylim(yl / cfg.Q_Ah); ylabel('C-rate'); set(gca, 'YColor', [0.3 0.3 0.3]);
legend('25 °C', '45 °C', 'Location', 'northwest');
title(sprintf('Pack current, %dS%dP (%.0f Ah)', cfg.Ns, cfg.Np, cfg.Q_Ah));
title(tl, 'MIDC drive cycle converted to battery load (190 kg e-scooter + rider)');
exportgraphics(f1, fullfile(figDir, 'w2_midc_load.png'), 'Resolution', 150);

%% Figure 2: full range run
f2 = figure('Position', [100 100 950 500]); theme(f2, 'light');
tl2 = tiledlayout(2, 1, 'TileSpacing', 'compact');
nexttile; hold on; grid on;
for n = 1:2, plot(res(n).dist, 100*res(n).S, 'LineWidth', 1.4); end
ylabel('SOC [%]'); legend(compose('%d °C', temps));
nexttile; hold on; grid on;
for n = 1:2, plot(res(n).dist, res(n).V, 'LineWidth', 0.8); end
ylabel('Pack voltage [V]'); xlabel('Distance [km]');
title(tl2, sprintf('Range test: repeated MIDC until %.0f %% SOC', 100*cfg.SOC_min_usable));
exportgraphics(f2, fullfile(figDir, 'w2_midc_range.png'), 'Resolution', 150);

%% IDC check: the cycle Indian e-scooter ranges are certified on
% Validation target: Ather Rizta, 2.7 kWh LFP pack, claimed 123 km IDC range
% (autocarindia.com) -> ~45.6 km per kWh. Similar mass (~119 kg) and class.
idc1 = profiles.idc(1, 1);
fprintf('\n===== IDC check =====\n');
fprintf('IDC (reconstructed): %.0f s, %.3f km (published 0.658), vavg %.2f km/h (published 21.93), amax %.2f m/s2 (0.65)\n', ...
        idc1.dur_s, idc1.dist_km, idc1.vavg_kmh, idc1.amax);
idcN = profiles.idc(1, 400);                               % long enough to empty the pack
dI   = vehicle.powerDemand(idcN, veh);
rI   = battpack.simulateIdeal(dI.P_batt, 25, 1, cfg, 0.0); % run to 0 % like a brochure figure
distI = cumsum(idcN.v) / 1000;
k10   = find(rI.SOC <= cfg.SOC_min_usable, 1);
E1    = sum(vehicle.powerDemand(idc1, veh).P_batt) / 3600;
fprintf('IDC energy: %.1f Wh/km at battery\n', E1 / idc1.dist_km);
fprintf('IDC range 100 -> 0 %% SOC: %.0f km (%.1f km/kWh);  100 -> 10 %%: %.0f km\n', ...
        distI(rI.kEnd), distI(rI.kEnd) / cfg.E_kWh, distI(k10));
fprintf('Ather Rizta (2.7 kWh LFP, claimed 123 km IDC): %.1f km/kWh  -> model is %+.0f %%\n', ...
        123 / 2.7, 100 * (distI(rI.kEnd) / cfg.E_kWh / (123 / 2.7) - 1));
fprintf('Figures saved to results/figures/\n');

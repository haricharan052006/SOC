%% Week 1 - Verify the Simulink cell block against the MATLAB reference model
% What : run the same pulse-discharge profile through (a) the Simulink block in
%        models/lfp_cell_2rc.slx and (b) the MATLAB function lfp.simulate,
%        at 25 degC and 45 degC, and compare the terminal voltages.
% Why  : "verification" - before we trust the block inside bigger models
%        (pack, EKF), we prove it computes exactly what the equations say.
%        Both call lfp.cellStep, so the difference should be ~1e-12 V
%        (floating-point rounding only).
%
% Run from repo root:  setup_paths; week1_simulink_cell_check

clear; close all;
root    = fileparts(fileparts(mfilename('fullpath')));
mdl     = 'lfp_cell_2rc';
mdlFile = fullfile(root, 'models', [mdl '.slx']);
figDir  = fullfile(root, 'results', 'figures');
build_lfp_cell_model();                 % always rebuild so the .slx matches the code
load_system(mdlFile);

p   = lfp.cellParams();
dt  = 1;
[iProf, t] = profiles.pulseDischarge(p.Q_Ah, dt);   % 1C pulses
x0  = [1; 0; 0; 0];
temps = [25 45];

f = figure('Position', [100 100 900 550]); theme(f, 'light');
tl = tiledlayout(2, 1, 'TileSpacing', 'compact');
ax1 = nexttile; hold on; grid on;
ax2 = nexttile; hold on; grid on;

fprintf('\n===== Simulink block vs MATLAB reference =====\n');
for T = temps
    % (a) Simulink
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('p', p);
    in = in.setVariable('dt', dt);
    in = in.setVariable('T_amb', T);
    in = in.setVariable('iProfile', [t iProf]);
    in = in.setModelParameter('StopTime', num2str(t(end)));
    in = in.setBlockParameter([mdl '/LFP Cell 2RC+H'], 'SOC0', num2str(x0(1)));
    tic;  out = sim(in);  tSim = toc;
    Vsl   = out.V_sim(:);
    SOCsl = out.SOC_sim(:);

    % (b) MATLAB reference
    [Vref, Xref] = lfp.simulate(iProf, T, dt, x0, p);

    n    = min(numel(Vsl), numel(Vref));
    errV = Vsl(1:n) - Vref(1:n);
    errS = SOCsl(1:n) - Xref(1:n, 1);
    fprintf('%d C: %d samples, max|dV| = %.2e V, max|dSOC| = %.2e, Simulink run time %.1f s\n', ...
            T, n, max(abs(errV)), max(abs(errS)), tSim);

    plot(ax1, t(1:n)/3600, Vsl(1:n), 'LineWidth', 1.4, 'DisplayName', sprintf('Simulink %d °C', T));
    plot(ax1, t(1:n)/3600, Vref(1:n), '--', 'LineWidth', 1.0, 'DisplayName', sprintf('MATLAB %d °C', T));
    plot(ax2, t(1:n)/3600, 1e3*errV, 'LineWidth', 1.2, 'DisplayName', sprintf('%d °C', T));
end
ylabel(ax1, 'Terminal voltage [V]');  legend(ax1, 'Location', 'southwest');
ylabel(ax2, 'Simulink - MATLAB [mV]'); xlabel(ax2, 'Time [h]'); legend(ax2);
title(tl, 'Verification: Simulink LFP cell block vs MATLAB reference model');
exportgraphics(f, fullfile(figDir, 'w1_simulink_vs_matlab.png'), 'Resolution', 150);
close_system(mdl, 0);
fprintf('Figure saved to results/figures/w1_simulink_vs_matlab.png\n');

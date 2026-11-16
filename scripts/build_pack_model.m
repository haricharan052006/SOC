function build_pack_model()
%BUILD_PACK_MODEL Generate the Simscape Battery 16S8P pack and the plant model.
%
% What : (1) Battery Builder -> a 16S8P module block (Simscape Battery) with
%            2RC + hysteresis cells, lumped thermal mass per group, air cooling,
%            group-to-group heat conduction, passive balancing switches and
%            per-group parameter variation.
%        (2) models/lfp_pack_plant.slx : that pack driven by the MIDC power
%            demand, with ambient temperature, sensors and logging.
% Why  : this is the "real vehicle battery" (plant). In week 3 the estimators
%        only see what a BMS sees (current, voltages, temperatures) and must
%        guess the SOC that this plant really has.
%
% Modelling choice: each parallel group of 8 cells is ONE lumped model
% (ModelResolution "Grouped"), so the pack has 16 cell models instead of 128.
% Cells in parallel share one voltage, so they behave almost identically; the
% interesting differences (imbalance, temperature spread) are between groups.
% This keeps the model fast on a laptop.

root   = fileparts(fileparts(mfilename('fullpath')));
mdlDir = fullfile(root, 'models');
libName = 'lfp_pack16s';
modName = 'Pack16S';
mdl     = 'lfp_pack_plant';
cfg     = battpack.config();

%% (1) Battery Builder
cellModel = sprintf('batt_lib/Cells/Battery Equivalent\nCircuit');
c = batteryCell(batteryCylindricalGeometry());
c.CellModelOptions.CellModelBlockPath = cellModel;
c.CellModelOptions.BlockParameters.RCPairs         = "rc2";
c.CellModelOptions.BlockParameters.ThermalModel    = "LumpedThermalMass";
c.CellModelOptions.BlockParameters.HysteresisModel = "oneStateModel";
c.Mass = simscape.Value(0.14, "kg");

pa = batteryParallelAssembly(c, cfg.Np);
mo = batteryModule(pa, cfg.Ns, ModelResolution = "Grouped", ...
                   SeriesGrouping = ones(1, cfg.Ns), ParallelGrouping = ones(1, cfg.Ns));
mo.Name                   = modName;
mo.AmbientThermalPath     = "CellBasedThermalResistance";
mo.InterCellThermalPath   = "on";
mo.BalancingStrategy      = "Passive";
mo.CellParameterVariation = "PercentDeviation";

for b = {mdl, [libName '_lib']}
    if bdIsLoaded(b{1}), close_system(b{1}, 0); end
end
% Remove previous builder output (the builder refuses to overwrite)
old = [dir(fullfile(mdlDir, ['+' libName '*'])); dir(fullfile(mdlDir, [libName '_lib.slx']))];
for k = 1:numel(old)
    f = fullfile(old(k).folder, old(k).name);
    if old(k).isdir, rmdir(f, 's'); else, delete(f); end
end
buildBattery(mo, LibraryName = libName, Directory = mdlDir, MaskParameters = "VariableNamesByType");
% The builder also writes a default-parameter script; we use battpack.simscapeParams instead.
defaultParam = fullfile(mdlDir, [libName '_param.m']);
if isfile(defaultParam), delete(defaultParam); end
addpath(mdlDir);

%% (2) Plant model
mdlFile = fullfile(mdlDir, [mdl '.slx']);
if isfile(mdlFile), delete(mdlFile); end
new_system(mdl);
load_system([libName '_lib']);
load_system('fl_lib');  load_system('nesl_utility');

set_param(mdl, 'Solver', 'daessc', 'MaxStep', '1', 'StopTime', 't_stop', ...
               'ReturnWorkspaceOutputs', 'on', 'SaveOutput', 'off', 'SaveTime', 'off');

B = @(path, name, pos) add_block(path, [mdl '/' name], 'Position', pos);
pk  = B([libName '_lib/' modName], 'Battery pack 16S8P', [420 160 520 300]);
ccs = B('fl_lib/Electrical/Electrical Sources/Controlled Current Source', 'Load (motor drive)', [700 200 740 260]);
cs  = B('fl_lib/Electrical/Electrical Sensors/Current Sensor', 'Pack current sensor', [580 120 620 160]);
vs  = B('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', 'Pack voltage sensor', [600 280 640 330]);
er  = B('fl_lib/Electrical/Electrical Elements/Electrical Reference', 'Electrical ref', [560 420 590 450]);
sc  = B('nesl_utility/Solver Configuration', 'Solver configuration', [460 420 520 450]);
ts  = B('fl_lib/Thermal/Thermal Sources/Controlled Temperature Source', 'Ambient air', [260 330 300 380]);
tr  = B('fl_lib/Thermal/Thermal Elements/Thermal Reference', 'Thermal ref', [265 440 295 470]);
dv  = B('fl_lib/Physical Signals/Functions/PS Divide', 'I = P over V', [800 300 840 340]);

% Inputs: battery power demand, ambient temperature, balancing commands
fw  = B('simulink/Sources/From Workspace', 'Battery power demand [W]', [860 380 980 410]);
set_param(fw, 'VariableName', 'P_profile', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
sP  = B('nesl_utility/Simulink-PS Converter', 'S-PS P', [1010 385 1030 405]);  set_param(sP, 'Unit', 'W');
% 0.1 s first-order filter: the power demand steps every second; a real motor
% controller ramps current in milliseconds, and the filter spares the solver
% from hitting a discontinuity at every step.
set_param(sP, 'FilteringAndDerivatives', 'filter', 'InputFilterTimeConstant', '0.1');
cT  = B('simulink/Sources/Constant', 'Ambient [K]', [100 340 170 370]);       set_param(cT, 'Value', 'T_amb_K');
sT  = B('nesl_utility/Simulink-PS Converter', 'S-PS T', [200 345 220 365]);  set_param(sT, 'Unit', 'K');
% Passive balancing controller (BMS): bleed every group whose voltage is more
% than bal_dV above the lowest group. Uses the group voltages from one sample
% earlier (Unit Delay = BMS sampling, also breaks the algebraic loop).
cB  = B('simulink/User-Defined Functions/MATLAB Function', 'Balancing controller', [100 160 200 220]);
ch  = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', [mdl '/Balancing controller']);
ch.Script = strjoin({
    'function cmd = balancing(v, bal_enable, bal_dV)'
    '% Voltage-based passive balancing, as in typical 2W BMS chips.'
    '% v: group voltages [V]; bal_enable: 1 = balancing allowed; bal_dV: threshold [V]'
    'cmd = zeros(size(v));'
    'if bal_enable > 0.5'
    '    cmd = double(v > min(v) + bal_dV);'
    'end'}, newline);
for nm = {'bal_enable', 'bal_dV'}
    d = ch.find('-isa', 'Stateflow.Data', 'Name', nm{1});  d.Scope = 'Parameter';
end
dv_ = ch.find('-isa', 'Stateflow.Data', 'Name', 'v');    dv_.Props.Array.Size = sprintf('[%d 1]', cfg.Ns);
dc_ = ch.find('-isa', 'Stateflow.Data', 'Name', 'cmd');  dc_.Props.Array.Size = sprintf('[%d 1]', cfg.Ns);
ud  = B('simulink/Discrete/Unit Delay', 'BMS sample', [40 175 70 205]);
set_param(ud, 'InitialCondition', sprintf('3.3*ones(%d,1)', cfg.Ns), 'SampleTime', 'bal_Ts');
sB  = B('nesl_utility/Simulink-PS Converter', 'S-PS CB', [240 175 260 195]); set_param(sB, 'Unit', '1');

% Outputs (BMS-visible signals + "true" internal states for scoring)
psI = B('nesl_utility/PS-Simulink Converter', 'PS-S I', [680 60 700 80]);   set_param(psI, 'Unit', 'A');
psV = B('nesl_utility/PS-Simulink Converter', 'PS-S V', [700 360 720 380]); set_param(psV, 'Unit', 'V');
pr  = B('nesl_utility/Probe', 'Probe (true states)', [560 520 640 600]);
% Log at t = k + 0.5 s (mid-interval): the power demand switches at whole
% seconds, so mid-interval samples see the current that actually flowed in
% step k - exactly what a BMS sampling between load changes would report.
tw  = @(name, var, pos) set_param(B('simulink/Sinks/To Workspace', name, pos), ...
          'VariableName', var, 'SaveFormat', 'Array', 'SampleTime', '[1 0.5]');
tw('I_pack', 'I_pack', [760 55 840 85]);
tw('V_pack', 'V_pack', [780 355 860 385]);
tw('SOC_groups',  'soc_g',  [760 510 840 540]);
tw('T_groups',    'temp_g', [760 560 840 590]);
tw('V_groups',    'v_g',    [760 610 840 640]);

% Stop when the weakest group reaches SOC_stop (the BMS would cut off)
mm  = B('simulink/Math Operations/MinMax', 'min SOC', [680 660 720 690]);  set_param(mm, 'Function', 'min', 'Inputs', '1');
ctc = B('simulink/Logic and Bit Operations/Compare To Constant', 'SOC <= stop', [750 660 810 690]);
set_param(ctc, 'relop', '<=', 'const', 'SOC_stop');
st  = B('simulink/Sinks/Stop Simulation', 'Stop', [840 660 870 690]);

% Pack initial conditions (per group)
set_param(pk, 'socCell_specify', 'on', 'socCell_priority', 'High', 'socCell', 'SOC0_vec', ...
              'batteryTemperature_specify', 'on', 'batteryTemperature_priority', 'High', ...
              'batteryTemperature', 'T0_vec_K', 'batteryTemperature_unit', 'K', ...
              'hysteresisState_specify', 'on', 'hysteresisState_priority', 'High', ...
              'hysteresisState', 'h0_vec');   % -1..+1; +1 = on the charge branch (just charged)

% Probe: expose true per-group SOC, temperature and voltage
simscape.probe.setBoundBlock(pr, pk);
simscape.probe.setVariables(pr, ["batteryTemperature", "socCell", "vParallelAssembly"]);  % must be alphabetical

%% Wiring (port order taken from the Simscape source files)
P = @(h) get_param(h, 'PortHandles');
L = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
pkP = P(pk); ccsP = P(ccs); csP = P(cs); vsP = P(vs); tsP = P(ts); dvP = P(dv);
% pack ports (found by trial connection): LConn1 = balancing cmd (PS),
% LConn2 = AmbH (thermal), LConn3 = + ; RConn1 = -
L(pkP.LConn(3), csP.LConn(1));           % pack +  -> current sensor +
L(csP.RConn(2), ccsP.RConn(2));          % sensor - -> load tail   (positive command = current
L(ccsP.LConn(1), pkP.RConn(1));          % load head -> pack -       out of pack +, i.e. discharge)
L(vsP.LConn(1), pkP.LConn(3));           % voltage sensor across pack
L(vsP.RConn(2), pkP.RConn(1));
L(P(er).LConn(1), pkP.RConn(1));         % ground
scP = P(sc);
if ~isempty(scP.RConn), L(scP.RConn(1), pkP.RConn(1)); else, L(scP.LConn(1), pkP.RConn(1)); end
L(tsP.LConn(1), pkP.LConn(2));           % ambient air -> pack thermal port
L(tsP.RConn(2), P(tr).LConn(1));
% I = P / V  -> controlled current source
L(P(fw).Outport(1), P(sP).Inport(1));
L(P(sP).RConn(1), dvP.LConn(1));
L(vsP.RConn(1), dvP.LConn(2));
L(dvP.RConn(1), ccsP.RConn(1));
% ambient temperature and balancing commands
L(P(cT).Outport(1), P(sT).Inport(1));   L(P(sT).RConn(1), tsP.RConn(1));
L(P(cB).Outport(1), P(sB).Inport(1));   L(P(sB).RConn(1), pkP.LConn(1));
% measurements
L(csP.RConn(1), P(psI).LConn(1));       L(P(psI).Outport(1), P([mdl '/I_pack']).Inport(1));
L(vsP.RConn(1), P(psV).LConn(1));       L(P(psV).Outport(1), P([mdl '/V_pack']).Inport(1));
prP = P(pr);
L(prP.Outport(2), P([mdl '/SOC_groups']).Inport(1));
L(prP.Outport(2), P(mm).Inport(1));
L(prP.Outport(1), P([mdl '/T_groups']).Inport(1));
L(prP.Outport(3), P([mdl '/V_groups']).Inport(1));
L(prP.Outport(3), P(ud).Inport(1));                 % group voltages -> BMS sample -> balancing
L(P(ud).Outport(1), P(cB).Inport(1));
L(P(mm).Outport(1), P(ctc).Inport(1));
L(P(ctc).Outport(1), P(st).Inport(1));

save_system(mdl, mdlFile);
close_system(mdl, 0);
fprintf('Built %s and library %s_lib\n', mdlFile, libName);
end

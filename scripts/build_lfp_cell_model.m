function mdlFile = build_lfp_cell_model()
%BUILD_LFP_CELL_MODEL Create models/lfp_cell_2rc.slx from code.
%
% What : a Simulink model containing a masked "LFP Cell 2RC+H" block plus a
%        small test harness (current profile in, voltage/SOC/state out).
% Why  : building the .slx from a script makes the model reproducible and
%        reviewable in Git (an .slx is a binary zip, a script is readable text).
%
% Block structure (inside "LFP Cell 2RC+H"):
%
%     i_A ─┐
%          ├─► [MATLAB Function: lfp.cellStep] ─► V, SOC, x
%     T_C ─┘            ▲             │ xNext
%                       └─[Unit Delay]┘   (holds the 4 states: soc, v1, v2, h)
%
% The block calls exactly the same lfp.cellStep as the MATLAB scripts, so
% there is one source of truth for the cell equations.

mdl     = 'lfp_cell_2rc';
root    = fileparts(fileparts(mfilename('fullpath')));
mdlDir  = fullfile(root, 'models');
mdlFile = fullfile(mdlDir, [mdl '.slx']);
if ~isfolder(mdlDir), mkdir(mdlDir); end
if bdIsLoaded(mdl), close_system(mdl, 0); end
if isfile(mdlFile), delete(mdlFile); end

new_system(mdl);

%% Solver: fixed-step discrete (the cell model is already a discrete-time model)
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
               'FixedStep', 'dt', 'StopTime', '3600', ...
               'SaveOutput', 'off', 'SaveTime', 'off', 'ReturnWorkspaceOutputs', 'on');

% Default workspace values so the model also runs when opened by hand.
% Scripts override these with Simulink.SimulationInput.setVariable.
set_param(mdl, 'InitFcn', strjoin({ ...
    'if ~exist(''p'',''var''), p = lfp.cellParams(); end', ...
    'if ~exist(''dt'',''var''), dt = 1; end', ...
    'if ~exist(''T_amb'',''var''), T_amb = 25; end', ...
    'if ~exist(''iProfile'',''var''), iProfile = [0 6; 3600 6]; end'}, newline));

%% ---------------- Cell subsystem ----------------
sub = [mdl '/LFP Cell 2RC+H'];
add_block('simulink/Ports & Subsystems/Subsystem', sub, 'Position', [330 95 500 215]);
delete_line(sub, 'In1/1', 'Out1/1');
delete_block([sub '/In1']);  delete_block([sub '/Out1']);

add_block('simulink/Sources/In1',  [sub '/i_A'], 'Position', [40 63 70 77]);
add_block('simulink/Sources/In1',  [sub '/T_C'], 'Position', [40 113 70 127], 'Port', '2');
add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/cellStep'], ...
          'Position', [200 50 340 190]);
add_block('simulink/Discrete/Unit Delay', [sub '/x_state'], ...
          'Position', [250 240 290 280], 'Orientation', 'left', ...
          'InitialCondition', '[SOC0; 0; 0; 0]', 'SampleTime', 'dt');
add_block('simulink/Sinks/Out1', [sub '/V'],   'Position', [430 63 460 77]);
add_block('simulink/Sinks/Out1', [sub '/SOC'], 'Position', [430 113 460 127], 'Port', '2');
add_block('simulink/Sinks/Out1', [sub '/x'],   'Position', [430 163 460 177], 'Port', '3');

code = strjoin({
    'function [V, SOC, x, xNext] = cellStep(i_A, T_C, x_k, p, dt)'
    '%#codegen'
    '% One step of the LFP 2RC + hysteresis model (same code as the MATLAB scripts).'
    '%   i_A : cell current [A], + = discharge     T_C : cell temperature [degC]'
    '%   x_k : state [soc; v1; v2; h] from the Unit Delay'
    '[xNext, V] = lfp.cellStep(x_k, i_A, T_C, dt, p);'
    'SOC = x_k(1);'
    'x   = x_k;'
    }, newline);
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', [sub '/cellStep']);
ch.Script = code;
% p (parameter struct) and dt come from the workspace, not from signal ports
for nm = {'p', 'dt'}
    d = ch.find('-isa', 'Stateflow.Data', 'Name', nm{1});
    d.Scope = 'Parameter';
end
% Declare signal sizes explicitly: Simulink cannot infer them around the
% Unit Delay feedback loop on its own.
sizes = {'i_A', '1'; 'T_C', '1'; 'x_k', '[4 1]'; ...
         'V', '1'; 'SOC', '1'; 'x', '[4 1]'; 'xNext', '[4 1]'};
for k = 1:size(sizes, 1)
    d = ch.find('-isa', 'Stateflow.Data', 'Name', sizes{k, 1});
    d.Props.Array.Size = sizes{k, 2};
    d.DataType = 'double';
end

add_line(sub, 'i_A/1', 'cellStep/1', 'autorouting', 'smart');
add_line(sub, 'T_C/1', 'cellStep/2', 'autorouting', 'smart');
add_line(sub, 'x_state/1', 'cellStep/3', 'autorouting', 'smart');
add_line(sub, 'cellStep/4', 'x_state/1', 'autorouting', 'smart');
add_line(sub, 'cellStep/1', 'V/1',   'autorouting', 'smart');
add_line(sub, 'cellStep/2', 'SOC/1', 'autorouting', 'smart');
add_line(sub, 'cellStep/3', 'x/1',   'autorouting', 'smart');

% Mask: the user only sets the initial SOC on the block
mk = Simulink.Mask.create(sub);
mk.addParameter('Name', 'SOC0', 'Prompt', 'Initial SOC [0-1]', 'Value', '1', 'Type', 'edit');
mk.Type        = 'LFP cell (2RC + hysteresis)';
mk.Description = ['Discrete 2RC equivalent-circuit LFP cell with one-state hysteresis. ' ...
                  'Parameters: workspace struct p = lfp.cellParams(), step dt [s]. ' ...
                  'Inputs: current [A] (+ = discharge), temperature [degC].'];
mk.Display     = sprintf('disp(''LFP cell\\n2RC + H'');\nport_label(''input'',1,''i [A]'');\nport_label(''input'',2,''T [degC]'');\nport_label(''output'',1,''V'');\nport_label(''output'',2,''SOC'');\nport_label(''output'',3,''x'');');

%% ---------------- Test harness ----------------
add_block('simulink/Sources/From Workspace', [mdl '/Current profile'], ...
          'Position', [80 100 200 130], 'VariableName', 'iProfile', ...
          'SampleTime', 'dt', 'Interpolate', 'off', ...
          'OutputAfterFinalValue', 'Holding final value');
add_block('simulink/Sources/Constant', [mdl '/Cell temperature'], ...
          'Position', [110 170 170 200], 'Value', 'T_amb');
add_block('simulink/Sinks/To Workspace', [mdl '/V_sim'],   'Position', [620 80 700 110], ...
          'VariableName', 'V_sim',   'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl '/SOC_sim'], 'Position', [620 140 700 170], ...
          'VariableName', 'SOC_sim', 'SaveFormat', 'Array');
add_block('simulink/Sinks/To Workspace', [mdl '/x_sim'],   'Position', [620 200 700 230], ...
          'VariableName', 'x_sim',   'SaveFormat', 'Array');
add_block('simulink/Sinks/Scope', [mdl '/Voltage scope'], 'Position', [620 20 650 50]);

add_line(mdl, 'Current profile/1',  'LFP Cell 2RC+H/1', 'autorouting', 'smart');
add_line(mdl, 'Cell temperature/1', 'LFP Cell 2RC+H/2', 'autorouting', 'smart');
add_line(mdl, 'LFP Cell 2RC+H/1', 'V_sim/1',   'autorouting', 'smart');
add_line(mdl, 'LFP Cell 2RC+H/1', 'Voltage scope/1', 'autorouting', 'smart');
add_line(mdl, 'LFP Cell 2RC+H/2', 'SOC_sim/1', 'autorouting', 'smart');
add_line(mdl, 'LFP Cell 2RC+H/3', 'x_sim/1',   'autorouting', 'smart');

save_system(mdl, mdlFile);
close_system(mdl, 0);
fprintf('Built %s\n', mdlFile);
end

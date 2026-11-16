function setup_paths()
%SETUP_PATHS Add project source folders to the MATLAB path.
%   Run once per MATLAB session from the repository root.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'models'));      % Simulink models + generated Simscape Battery library
for d = ["results/figures", "results/tables"]
    if ~isfolder(fullfile(root, d))
        mkdir(fullfile(root, d));
    end
end
fprintf('Project paths added (root: %s)\n', root);
end

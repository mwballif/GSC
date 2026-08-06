%==============================================================================
% config.m
%
% Purpose: Set all paths and execution flags for the project.
% Reads:   nothing
% Writes:  nothing (defines variables in the caller's workspace)
% NOTE: only file holding paths. Model parameters go in model/parameters.m.
%==============================================================================

%% Root path
% Derived from this file's own location, so nothing needs editing on a new
% machine.
root = fileparts(fileparts(mfilename('fullpath')));

%% Derived paths
code_dir          = fullfile(root, 'code');
dp_matlab         = fullfile(code_dir, 'data_processing', 'matlab');
dp_stata          = fullfile(code_dir, 'data_processing', 'stata_code');
model_dir         = fullfile(code_dir, 'model');

data_raw          = fullfile(root, 'data', 'raw');
data_processed    = fullfile(root, 'data', 'processed');
data_intermediate = fullfile(root, 'data', 'processed', 'intermediate');
data_crosswalks   = fullfile(root, 'data', 'crosswalks');

res_params        = fullfile(root, 'results', 'parameters');
res_intermediate  = fullfile(root, 'results', 'intermediate');
res_figures       = fullfile(root, 'results', 'figures');
res_tables        = fullfile(root, 'results', 'tables');
logs_dir          = fullfile(root, 'logs');

%% Execution flags
RUN_BUILD           = false;  % Rebuild the panels and rerun the recovery
RUN_COUNTERFACTUALS = false;  % Not implemented; see code/model/README.md
RUN_OUTPUT          = true;   % Redraw the parameter figures

%% Random seed
% Nothing in the pipeline is stochastic. Set a seed here before adding
% anything that is.
% rng(20260727, 'twister');

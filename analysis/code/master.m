%==============================================================================
% master.m
%
% Purpose: Reproduce every result in the project, start to finish.
% Reads:   config.m
% Writes:  logs/run_<timestamp>.log, plus everything the two stages write
%
% The pipeline has two stages, matching the two folders under code/:
%   data_processing/   raw WIOT and SEA files -> panels -> recovered parameters
%   model/             recovered parameters -> equilibrium -> counterfactuals
% NOTE: the stage boundary is data/processed. Neither side crosses it.
%==============================================================================

clear; clc; close all;
run('config.m');

%% Start the log
if ~isfolder(logs_dir), mkdir(logs_dir); end
diary(fullfile(logs_dir, ['run_' datestr(now,'yyyy-mm-dd_HH-MM-SS') '.log']));
fprintf('=== Started: %s ===\n', datestr(now));

%% Stage 1: data processing
% run_pipeline.m runs the MATLAB extractors and Stata in order, so there is no
% manual step.
% NOTE: the scripts call clear, so config.m is rerun to restore the flags.
if RUN_BUILD
    run(fullfile(root,'code','data_processing','run_pipeline.m'));
    run(fullfile(fileparts(mfilename('fullpath')),'config.m'));
end

%% Stage 2: model
% Nothing to run. code/model/ is the blank template from
% ~/repos/macromodel_template, kept only to fix the file conventions any future
% model here must follow. The GSC model is specified in paper/math_appendix.pdf
% and the plan for solving it is in paper/solution_method.pdf; neither is coded.
% Restore the smoke test and the counterfactual driver below once it is.
fprintf('\nStage 2 skipped: code/model/ is a blank template, see its README.md\n');

if RUN_COUNTERFACTUALS
    error('master: RUN_COUNTERFACTUALS is set but no model is implemented');
end

%% Stage 3: output
% Parameter figures describe the recovered parameters, not a model solution, so
% they belong to data_processing. run_pipeline.m already draws them, so this
% only fires when the build was skipped.
if RUN_OUTPUT && ~RUN_BUILD
    cd(fullfile(root,'code','data_processing','matlab'));
    run('make_parameter_figures.m');
    run(fullfile(fileparts(mfilename('fullpath')),'config.m'));
end

fprintf('=== Completed: %s ===\n', datestr(now));
diary off;

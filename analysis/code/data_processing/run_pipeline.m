%==============================================================================
% run_pipeline.m
%
% Purpose: Run the data_processing stage in order, MATLAB and Stata together.
% Reads:   the raw workbooks
% Writes:  panel_A-D.csv, the six panels, recovered_*.csv, results/figures
%
%   1. process_raw_data.m       raw workbooks -> intermediate .mat files
%   2. createpanels.m           .mat          -> panel_A-D.csv
%   3. stata_code/run.do        splice at 2000 -> the six panels
%   4. recover_parameters.m     panels        -> recovered_*.csv
%   5. make_parameter_figures.m               -> results/figures
%
% NOTE: step 1 is slow and only needed when the raw workbooks change.
% NOTE: the scripts call clear, so settings are kept in the environment.
%==============================================================================

STEPS = [0 1 1 1 1];   % which of the five steps to run
STATA = '/Applications/StataNow/StataBE.app/Contents/MacOS/StataBE';

setenv('GSC_STEPS', num2str(STEPS));
setenv('GSC_DIR',   fileparts(mfilename('fullpath')));
setenv('GSC_STATA', STATA);

fprintf('=== pipeline start: %s ===\n', datestr(now));

%% Step 1: raw workbooks to .mat
if step(1), rundir('matlab', 'process_raw_data.m'); end

%% Step 2: build panel_A-D
if step(2), rundir('matlab', 'createpanels.m'); end

%% Step 3: Stata splice
if step(3), runstata; end

%% Step 4: recover the parameters
if step(4), rundir('matlab', 'recover_parameters.m'); end

%% Step 5: draw the figures
if step(5), rundir('matlab', 'make_parameter_figures.m'); end

fprintf('\n=== pipeline done: %s ===\n', datestr(now));


function tf = step(k)
% Read step k's flag back from the environment, which clear cannot wipe.
s  = sscanf(getenv('GSC_STEPS'), '%d');
tf = logical(s(k));
if tf, fprintf('\n[%d/5] running\n', k); else, fprintf('\n[%d/5] skipped\n', k); end
end


function rundir(sub, script)
% Run a script from its own folder, since they all use relative paths.
cd(fullfile(getenv('GSC_DIR'), sub));
run(script);
end


function runstata
% NOTE: -e is required, or the Stata process never exits and this blocks forever.
% NOTE: Stata batch mode does not return a nonzero exit code, so read the log.
cd(fullfile(getenv('GSC_DIR'), 'stata_code'));
if isfile('run.log'), delete('run.log'); end
system(sprintf('"%s" -b -e do run.do', getenv('GSC_STATA')));
if ~isfile('run.log') || ~isempty(regexp(fileread('run.log'), '(?m)^r\(\d+\);', 'once'))
    error('Stata failed. See stata_code/run.log. Nothing downstream ran.');
end
end

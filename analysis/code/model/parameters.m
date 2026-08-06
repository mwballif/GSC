function P = parameters

% Calibrated parameters
P.theta     = 4;            % Trade elasticity
P.psi       = 0.57;         % Consumption elasticity of substitution
P.delta     = 0.95;         % Discount factor
P.d         = 0.05;         % Depreciation rate of capital
P.eta       = 2;            % Elasticity across tradable varieties
P.zeta      = 1;            % Investment CES elasticity
P.sigma     = 0;            % Capital adjustment cost

% Income elasticities, CLM (2021), normalized to sum to one
P.eps       = [0.02; 1.00; 1.17]/2.19;

% Experiment
P.freezeyear = 1965;        % Year the wedge is frozen at
P.pad        = 20;          % Years appended after the sample so the terminal
                            % bond condition binds outside the reported window

% Solver settings
P.tolprice  = 1e-13;        % Cost and price fixed point
P.tolcons   = 1e-14;        % Real consumption
P.tolyear   = 1e-13;        % Income residual
P.tolpath   = 1e-7;         % Net export path. The data satisfies its own
                            % accounting only to 2e-8, so anything tighter is
                            % the solver chasing rounding noise.
P.brkw      = [-0.5 0.5];   % Bracket on log wage change
P.brkc      = [-3.0 3.0];   % Bracket on log consumption change
P.fdstep    = 1e-5;         % Newton step, as a share of value added
P.maxpath   = 20;           % Newton iterations on the path

% Where the data lives
here        = fileparts(mfilename('fullpath'));
P.datadir   = fullfile(here,'..','..','data','processed');

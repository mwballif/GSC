function P = parameters

% parameters: Sets every number the model is not told by the data.
% Calibrated elasticities first, then the experiment, then the solver settings.
% Inputs:  none.
% Output:  P (structure of calibrated parameters).

%---------------------------------------------
%   1. Calibrated parameters
%---------------------------------------------
P.theta     = 2;            % Trade elasticity
P.psi       = 0.57;         % Consumption elasticity of substitution
P.delta     = 0.95;         % Discount factor
P.d         = 0.05;         % Depreciation rate of capital
P.zeta      = 1;            % Investment CES elasticity

% Income elasticities, CLM (2021), normalized to sum to one
P.eps       = [0.02; 1.00; 1.17]/2.19;

%---------------------------------------------
%   2. Experiment
%---------------------------------------------
P.freezeyear = 1965;        % Year trade costs are frozen at
P.ssyear     = 2150;        % Year the steady state is dated at. A label only:
                            % the shocks are held at their last observed values,
                            % so the rest point is the same at any date.
P.pad        = 20;          % Years held at the last observed value after the
                            % sample, so the terminal conditions bind outside
                            % the reported window. Independent of P.ssyear.
P.Bbar       = 0;           % Bond target the terminal condition anchors on

%---------------------------------------------
%   3. Solver settings
%---------------------------------------------
P.tolprice  = 1e-13;        % Cost and price fixed point
P.tolcons   = 1e-14;        % Real consumption
P.tolyear   = 1e-13;        % Net export residual, inside the year
P.tolpath   = 1e-7;         % Net export path. The data satisfies its own
                            % accounting only to 2e-8, so anything tighter is
                            % the solver chasing rounding noise.
P.tolss     = 1e-10;        % Steady state capital, relative change
P.ssdamp    = 1;            % Share of the step the steady state takes
P.brkw      = [-0.5 0.5];   % Bracket on the log wage change
P.fdstep    = 1e-5;         % Finite-difference step for the Jacobians
P.maxpath   = 20;           % Newton iterations on the path
P.maxss     = 50;           % Steady state iterations

%---------------------------------------------
%   4. Where the data lives
%---------------------------------------------
here        = fileparts(mfilename('fullpath'));
P.datadir   = fullfile(here,'..','..','data','processed');

function P = parameters

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Every number the model is not told by the data.
%
%  Inputs:  none
%  Output:  P
%
%==============================================================================

% - calibrated parameters - %
P.theta     = 2;            % Trade elasticity
P.psi       = 0.57;         % Consumption elasticity of substitution
P.delta     = 0.95;         % Discount factor
P.d         = 0.05;         % Depreciation rate of capital
P.zeta      = 1;            % Investment CES elasticity

% Income elasticities, CLM (2021), normalized to sum to one
P.eps       = [0.02; 1.00; 1.17]/2.19;

% - experiment - %
P.freezeyear = 1965;        % Year trade costs are frozen at
P.ssyear     = 2150;        % Year the steady state is dated at, EQconditions.tex's T.
                            % The wedges stop at the last data year, leaving
                            % 136 years for the model to settle.

	% EQconditions.tex's Bbar; zero in the recovery %
P.Bbar       = 0;

% - solver settings - %
P.tolprice  = 1e-13;        % Cost and price fixed point
P.tolcons   = 1e-14;        % Real consumption
P.tolw      = 1e-11;        % EQconditions.tex's inner loop error. It suggests 1e-6;
                            % the path solver needs the wage tighter than that
P.tolpath   = 1e-7;         % Euler equations along the path. The data's own
                            % accounting only holds to 2e-8.
P.tolss     = 1e-10;        % Steady state capital, relative change
P.ssdamp    = 1;            % Share of the step the steady state takes
P.fdstep    = 1e-5;         % Finite-difference step for the Jacobians
P.maxw      = 5000;         % Steps of EQconditions.tex's wage update rule
P.maxpath   = 30;           % Newton iterations on the path
P.maxss     = 50;           % Steady state iterations

% - where the data lives - %
here        = fileparts(mfilename('fullpath'));
P.datadir   = fullfile(here,'..','..','data','processed');

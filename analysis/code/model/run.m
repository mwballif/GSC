%==============================================================================
% run: Solves the model and reports the counterfactual. Run this.
% Checks the data, solves the steady state, runs the data and frozen-trade-cost
% paths, and prints the counterfactual table.
% Reads:   data/processed/*.csv
% Writes:  results/solution.mat
%==============================================================================

clear; clc; close all;

V = variables;
P = parameters;
D = loaddata(P,V);
B = baseline(P,V,D);
%%
%---------------------------------------------
%   2. Terminal steady state
%---------------------------------------------
S = steadystate(D.tau,P,V,D,B);
fprintf('\nSteady state solved in %d iterations\n',S.itq    `er);
for i = 1:V.ncty
    fprintf('  %-3s  K_ss = %.2f\n',V.countries{i},S.K(i));
end

%%
%---------------------------------------------
%   3. The two runs
%---------------------------------------------
% The data, then trade costs frozen with everything else moving as recovered.
name = {'Data', sprintf('Trade costs frozen at %d',P.freezeyear)};
fprintf('\n%s\n',name{1});  r(1).o = dynamic(D.tau, S,P,V,D,B);
fprintf('%s\n',  name{2});  r(2).o = dynamic(D.tau0,S,P,V,D,B);

%---------------------------------------------
%   4. US value added shares
%---------------------------------------------
% The outcome the counterfactual is about, one series per run.
w = 1:D.T;
for k = 1:2
    va = bsxfun(@times,D.beta(:,V.USA),squeeze(r(k).o.Y(:,V.USA,:)));
    va = bsxfun(@rdivide,va,sum(va,1));
    r(k).man = va(V.MAN,:);
    r(k).gds = va(V.AGR,:) + va(V.MAN,:);
    r(k).nx  = r(k).o.NX(w)' ./ B.VA(V.USA,w);
end

%---------------------------------------------
%   5. The baseline against the data
%---------------------------------------------
% The terminal conditions pin capital and bonds at their steady state values,
% which the data does not satisfy, so the two are not the same path.
vaD  = bsxfun(@times,D.beta(:,V.USA),squeeze(D.Y(:,V.USA,:)));
manD = vaD(V.MAN,:)./sum(vaD,1);
fprintf('\nBaseline against the data\n');
fprintf('  manufacturing share, max gap           %.4f\n', ...
        max(abs(r(1).man(w)-manD(w))));
fprintf('  net exports over value added, max gap  %.3f\n', ...
        max(abs(r(1).o.NX(w)'-D.NX(V.USA,w))./B.VA(V.USA,w)));

%---------------------------------------------
%   6. The counterfactual table
%---------------------------------------------
% dva is the change in the share. The second column is how much of the data's
% change freezing trade costs fails to deliver.
win = {'1965-2014', 1, D.Tdata; ...
       '1970-2007', find(D.years==1970,1), find(D.years==2007,1)};
for iw = 1:size(win,1)
    a = win{iw,2};  b = win{iw,3};
    dm0 = r(1).man(b)-r(1).man(a);
    dg0 = r(1).gds(b)-r(1).gds(a);
    fprintf('\n%s                  Manufacturing        Goods (a and m)\n',win{iw,1});
    fprintf('                              dva   1-dvaCF/dvaD     dva   1-dvaCF/dvaD\n');
    fprintf('%-28s%7.1f%%                %7.1f%%\n',name{1},100*dm0,100*dg0);
    dm = r(2).man(b)-r(2).man(a);
    dg = r(2).gds(b)-r(2).gds(a);
    fprintf('%-28s%7.1f%%  %10.1f%%   %7.1f%%  %10.1f%%\n', ...
            name{2},100*dm,100*(1-dm/dm0),100*dg,100*(1-dg/dg0));
end

%---------------------------------------------
%   7. Save
%---------------------------------------------
if ~exist('results','dir'), mkdir('results'), end
save('results/solution.mat','P','V','D','B','S','r','name');
fprintf('\nSolution written to results/solution.mat\n');

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Solves the model and reports the counterfactual. Run this.
%  Checks the data, solves the terminal steady state (Section 1, step 1), checks
%  Section 3 year by year against the data, then solves the transition (step 2)
%  at the recovered trade costs and with them frozen.
%
%  Output:  results/solution.mat
%  
%  Figures and tables produced:
%           Table: counterfactual value added shares, printed to screen
%  
%  Data used:
%           data/processed/*.csv, via loaddata.m
%
%==============================================================================

clear; clc; close all;

V = variables;
P = parameters;
D = loaddata(P,V);
D = padyears(P,V,D);
B = baseline(P,V,D);

fprintf('Data, %d to %d, solved over %d periods\n', ...
        D.years(1),D.years(D.Tdata),D.T);
fprintf('  output equals spending routed through trade shares   %.1e\n',D.chkY);
fprintf('  consumption shares add to one                        %.1e\n',B.chks);
fprintf('  investment shares add to one                          %.1e\n',B.chkx);
fprintf('  investment equals its price times its quantity        %.1e\n',B.chkX);
fprintf('  Euler wedge equals 1+phi*(B-Bbar)                    %.1e\n',B.chkw);

%%
% - step 1: terminal steady state, at the data's wedges - %
	% each run gets its own below; this one is for the checks that follow %
Wd = wedges(D,P);
S  = steadystate(Wd,P,V,D,B);
fprintf('\nSteady state solved in %d iterations\n',S.iter);
fprintf('  R = %.4f, world consumption expenditure normalized to one\n',S.R);
for i = 1:V.ncty
    fprintf('  %-3s  K_ss = %.4e   E^C_ss = %.4f   w_ss = %.4e\n', ...
            V.countries{i},S.K(i),S.EC(i),S.w(i));
end
fprintf('  capital Euler residual, max                          %.1e\n', ...
        max(abs(S.resid)));

%%
% - Section 3 against the data - %
	% every data year, at its own consumption share and capital stocks %
d = 1:D.Tdata;
o = cell(D.Tdata,1);
for t = d
    o{t} = static(t,struct('EC',B.eUS(t)),D.Kdata(:,t:t+1),Wd,P,V,D,B);
end

man  = zeros(D.Tdata,1);
manD = zeros(D.Tdata,1);
nxg  = zeros(D.Tdata,1);
for t = d
    va      = D.beta(:,V.USA).*o{t}.Y(:,V.USA);
    vaD     = D.beta(:,V.USA).*D.Y(:,V.USA,t);
    man(t)  = va(V.MAN)/sum(va);
    manD(t) = vaD(V.MAN)/sum(vaD);
    nxg(t)  = o{t}.NX(V.USA)/o{t}.VA(V.USA) - D.NX(V.USA,t)/B.VA(V.USA,t);
end

fprintf('\nStatic block at the data\n');
fprintf('  wage ratio, max deviation from one                   %.1e\n', ...
        max(abs(cellfun(@(x) x.wagehat,o)-1)));
fprintf('  net export gap the wage ratio closes, max            %.1e\n', ...
        max(abs(cellfun(@(x) x.g,o))));
fprintf('  net exports over value added, max gap                %.1e\n',max(abs(nxg)));
fprintf('  US manufacturing share, max gap                      %.1e\n', ...
        max(abs(man-manD)));

	% the bond Euler at the data path, both ways %
	% (note: the gap between the two is employment growth) %
k    = 1:D.Tdata-1;
pt   = zeros(V.ncty,D.Tdata);
for t = d, pt(:,t) = o{t}.phitilde; end
ea   = [B.eUS(1:D.Tdata); 1-B.eUS(1:D.Tdata)];
aa   = (pt(:,k+1)./pt(:,k))./D.wedge(:,k);
Lr   = D.L(:,k+1)./D.L(:,k);
gE   = log(B.eUS(k+1)./B.eUS(k))';

Rt   = 1./(P.delta*sum(aa.*ea(:,k),1)');
res1 = gE - log(aa(V.USA,:))' - log(P.delta*Rt);

RtL  = 1./(P.delta*sum(Lr.*aa.*ea(:,k),1)');
res2 = gE - log(Lr(V.USA,:))' - log(aa(V.USA,:))' - log(P.delta*RtL);

fprintf('  bond Euler at the data, total expenditure, max       %.1e\n',max(abs(res1)));
fprintf('  bond Euler at the data, expenditure per worker, max  %.1e\n',max(abs(res2)));

%%
% - step 2: the runs - %
	% each run gets its own wedge path and its own terminal steady state %
cf = { {},       'Data'
       {'tau'},  sprintf('Trade costs frozen at %d',P.freezeyear) };
name = cf(:,2)';
r    = struct('W',cell(size(cf,1),1),'S',[],'o',[]);

for k = 1:size(cf,1)
    fprintf('\n%s\n',name{k});
    r(k).W = wedges(D,P,cf{k,1}{:});
    r(k).S = steadystate(r(k).W,P,V,D,B);
    r(k).o = dynamic(r(k).W,r(k).S,P,V,D,B);
end

% - US value added shares, the outcome - %
w = 1:D.T;
for k = 1:2
    va = bsxfun(@times,D.beta(:,V.USA),squeeze(r(k).o.Y(:,V.USA,:)));
    va = bsxfun(@rdivide,va,sum(va,1));
    r(k).man = va(V.MAN,:);
    r(k).gds = va(V.AGR,:) + va(V.MAN,:);
    r(k).nx  = r(k).o.NX(V.USA,:)./r(k).o.VA(V.USA,:);
end

% - the baseline against the data - %
	% (note: step 2.1 pins terminal capital, which the data does not satisfy) %
vaD  = bsxfun(@times,D.beta(:,V.USA),squeeze(D.Y(:,V.USA,:)));
manD = vaD(V.MAN,:)./sum(vaD,1);
nxD  = D.NX(V.USA,:)./B.VA(V.USA,:);
fprintf('\nBaseline against the data, over the sample\n');
fprintf('  max Euler residual on the path                       %.1e\n', ...
        max(abs(r(1).o.res)));
fprintf('  manufacturing share, max gap                         %.4f\n', ...
        max(abs(r(1).man(d)-manD(d))));
fprintf('  net exports over value added, max gap                %.4f\n', ...
        max(abs(r(1).nx(d)-nxD(d))));
fprintf('  world consumption expenditure, max deviation from one %.1e\n', ...
        max(abs(sum(r(1).o.EC,1)-1)));
fprintf('  R, mean %.4f, range [%.4f %.4f]\n', ...
        mean(r(1).o.R(2:end)),min(r(1).o.R(2:end)),max(r(1).o.R(2:end)));
fprintf('  bond position at the horizon, gap from the target    %.2e\n', ...
        r(1).o.bondgap);

% - the counterfactual table - %
	% dva is the change in the share, the second column what freezing misses %
win = {sprintf('%d-%d',D.years(1),D.years(D.Tdata)), 1, D.Tdata; ...
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

% - steady state table - %
	% one row per variable, one column per run and region %
tdir = fullfile('..','..','results','tables');
if ~exist(tdir,'dir'), mkdir(tdir), end

row = {'capital_stock',           @(S,i) S.K(i)
       'capital_over_2014',       @(S,i) S.K(i)/D.Kdata(i,D.Tdata)
       'investment',              @(S,i) S.X(i)
       'consumption_expenditure', @(S,i) S.EC(i)
       'wage',                    @(S,i) S.w(i)
       'rental_rate',             @(S,i) S.r(i)
       'price_of_investment',     @(S,i) S.PX(i)
       'net_exports',             @(S,i) S.NX(i)
       'interest_rate',           @(S,i) S.R};

T = table(row(:,1),'VariableNames',{'variable'});
for k = 1:numel(r)
    for i = 1:V.ncty
        col = sprintf('%s_%s',matlab.lang.makeValidName(name{k}),V.countries{i});
        T.(col) = cellfun(@(f) f(r(k).S,i),row(:,2));
    end
end
writetable(T,fullfile(tdir,'steady_state.csv'));
fprintf('\nSteady state written to %s\n',fullfile(tdir,'steady_state.csv'));

% - save - %
if ~exist('results','dir'), mkdir('results'), end
save('results/solution.mat','P','V','D','B','S','Wd','o','r','name');
fprintf('\nSolution written to results/solution.mat\n');

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Plots every figure the model produces. Run run.m first.
%
%  Output:  ../../results/figures/*.pdf
%  
%  Figures produced:
%           us_trade_motivation.pdf, value_added_shares.pdf,
%           value_added_gap.pdf, trade_imbalances.pdf, tradecost.pdf
%  
%  Data used:
%           results/solution.mat
%
%==============================================================================

clear; clc; close all;

L = load('results/solution.mat');
V = L.V;  P = L.P;  D = L.D;  B = L.B;  r = L.r;  name = L.name;  S = L.r(1).S;
years = D.years;
d  = 1:D.Tdata;
w  = d;                     % the sample, not the padded years the model solves
k0 = find(years == P.freezeyear,1);

outdir = fullfile('..','..','results','figures');
if ~exist(outdir,'dir'), mkdir(outdir), end

sty = {'k-','b--'};
LW  = 1.5;

% - the motivation - %
	% services on its own axis, being several times the other two %
va  = bsxfun(@times,D.beta(:,V.USA),squeeze(D.Y(:,V.USA,:)));
va  = bsxfun(@rdivide,va,sum(va,1));
imp = 1 - squeeze(D.pi(:,V.USA,V.USA,:));
nx  = D.NX(V.USA,:)./B.VA(V.USA,:);

f1 = figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
yyaxis left
plot(years(d),va(V.AGR,d),'--','Color',[0 .5 0],'LineWidth',LW);
plot(years(d),va(V.MAN,d),'-', 'Color','b','LineWidth',LW);
ylabel('Share of value added');
yyaxis right
plot(years(d),va(V.SER,d),'-','Color','r','LineWidth',LW);
title('US value added shares'); xlabel('Year');
legend({'Agriculture','Manufacturing','Services (right axis)'}, ...
       'Location','east','Box','off');

subplot(1,2,2); hold on; box on; grid on;
yyaxis left
plot(years(d),100*imp(V.AGR,d),'--','Color',[0 .5 0],'LineWidth',LW);
plot(years(d),100*imp(V.MAN,d),'-', 'Color','b','LineWidth',LW);
ylabel('Percent of sector expenditure');
yyaxis right
plot(years(d),100*nx(d),'k-','LineWidth',LW);
ylabel('Percent of GDP');
title('US import shares and net exports'); xlabel('Year');
legend({'Agriculture','Manufacturing','Net exports (right axis)'}, ...
       'Location','southwest','Box','off');

% - value added shares, data against the counterfactual - %
f2 = figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
for k = 1:2, plot(years(w),100*r(k).man(w),sty{k},'LineWidth',LW); end
title('Manufacturing'); xlabel('Year'); ylabel('Value added share');
legend(name,'Location','northeast','Box','off');
subplot(1,2,2); hold on; box on; grid on;
for k = 1:2, plot(years(w),100*r(k).gds(w),sty{k},'LineWidth',LW); end
title('Goods (a and m)'); xlabel('Year');

% - the gap - %
f3 = figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
plot(years(w),100*(r(1).man(w)-r(2).man(w)),'b--','LineWidth',LW);
yline(0,'k-');
title('Manufacturing'); xlabel('Year');
ylabel('Data minus counterfactual, points');
subplot(1,2,2); hold on; box on; grid on;
plot(years(w),100*(r(1).gds(w)-r(2).gds(w)),'b--','LineWidth',LW);
yline(0,'k-');
title('Goods (a and m)'); xlabel('Year');

% - trade imbalances - %
f4 = figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
for k = 1:2, plot(years(w),100*r(k).nx(w),sty{k},'LineWidth',LW); end
yline(0,'k-');
title('US trade imbalance'); xlabel('Year'); ylabel('Percent of GDP');
legend(name,'Location','southwest','Box','off');

% - manufacturing trade costs - %
tauUS  = squeeze(D.tau(V.MAN,V.USA,V.ROW,w));   % US importing from ROW
tauROW = squeeze(D.tau(V.MAN,V.ROW,V.USA,w));   % ROW importing from US
f5 = figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
plot(years(w),tauUS/tauUS(k0),'k-','LineWidth',LW);
plot(years(w),tauROW/tauROW(k0),'b--','LineWidth',LW);
yline(1,'k--');
title(sprintf('Manufacturing trade costs, %d = 1',P.freezeyear));
xlabel('Year'); ylabel('Trade cost, importer-facing');
legend({'US importing from ROW','ROW importing from US'}, ...
       'Location','northeast','Box','off');

% - the transition onto the steady state - %
	% the whole horizon, not just the sample; steady state as a dashed line %
o  = r(1).o;
yy = years(1:D.T);

f6 = figure('Position',[100,100,980,700],'Color','w');

subplot(2,2,1); hold on; box on; grid on
for i = 1:V.ncty
    plot(yy,o.K(i,1:D.T)/o.K(i,1),sty{i},'LineWidth',LW);
    yline(S.K(i)/o.K(i,1),sty{i}(1),'LineStyle','--','LineWidth',1);
end
xline(years(D.Tdata),'k:','LineWidth',1);
title('Capital stock'); xlabel('Year'); ylabel('1965 = 1');
legend(V.countries,'Location','southeast','Box','off');

subplot(2,2,2); hold on; box on; grid on
plot(yy,o.e,'k-','LineWidth',LW);
yline(S.eUS,'b--','LineWidth',1);
xline(years(D.Tdata),'k:','LineWidth',1);
title('US share of world consumption expenditure');
xlabel('Year'); ylabel('Share');

subplot(2,2,3); hold on; box on; grid on
plot(yy(2:end),o.R(2:D.T),'k-','LineWidth',LW);
yline(S.R,'b--','LineWidth',1);
xline(years(D.Tdata),'k:','LineWidth',1);
title('Interest rate'); xlabel('Year'); ylabel('Gross rate');

subplot(2,2,4); hold on; box on; grid on
plot(yy,100*o.NX(V.USA,1:D.T)./o.VA(V.USA,1:D.T),'k-','LineWidth',LW);
yline(0,'b--','LineWidth',1);
xline(years(D.Tdata),'k:','LineWidth',1);
title('US net exports'); xlabel('Year'); ylabel('Percent of value added');

sgtitle(sprintf('Transition onto the %d steady state',years(D.T)));

% - export - %
nm = {f1,'us_trade_motivation'; f2,'value_added_shares'; f3,'value_added_gap';
      f4,'trade_imbalances';    f5,'tradecost';          f6,'transition'};
for q = 1:size(nm,1)
    exportgraphics(nm{q,1},fullfile(outdir,[nm{q,2} '.pdf']), ...
                   'ContentType','vector','BackgroundColor','white');
end
fprintf('Figures written to %s\n',outdir);

%==============================================================================
% makefigures: Plots every figure the model produces. Run run.m first.
% One PDF per figure: the motivation, the value added shares, the gap between
% data and counterfactual, the US trade imbalance, and the trade costs.
% Reads:   results/solution.mat
% Writes:  results/figures/*.pdf
%==============================================================================

clear; clc; close all;

L = load('results/solution.mat');
V = L.V;  P = L.P;  D = L.D;  B = L.B;  r = L.r;  name = L.name;
years = D.years;
w  = 1:D.T;
k0 = find(years == P.freezeyear,1);

outdir = fullfile('..','..','results','figures');
if ~exist(outdir,'dir'), mkdir(outdir), end

sty = {'k-','b--'};
LW  = 1.5;

%---------------------------------------------
%   1. The motivation
%---------------------------------------------
% Services is several times the other two, so it gets its own axis.
va  = bsxfun(@times,D.beta(:,V.USA),squeeze(D.Y(:,V.USA,:)));
va  = bsxfun(@rdivide,va,sum(va,1));
imp = 1 - squeeze(D.pi(:,V.USA,V.USA,:));
nx  = D.NX(V.USA,:)./B.VA(V.USA,:);

f1 = figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
yyaxis left
plot(years,va(V.AGR,:),'--','Color',[0 .5 0],'LineWidth',LW);
plot(years,va(V.MAN,:),'-', 'Color','b','LineWidth',LW);
ylabel('Share of value added');
yyaxis right
plot(years,va(V.SER,:),'-','Color','r','LineWidth',LW);
title('US value added shares'); xlabel('Year');
legend({'Agriculture','Manufacturing','Services (right axis)'}, ...
       'Location','east','Box','off');

subplot(1,2,2); hold on; box on; grid on;
yyaxis left
plot(years,100*imp(V.AGR,:),'--','Color',[0 .5 0],'LineWidth',LW);
plot(years,100*imp(V.MAN,:),'-', 'Color','b','LineWidth',LW);
ylabel('Percent of sector expenditure');
yyaxis right
plot(years,100*nx,'k-','LineWidth',LW);
ylabel('Percent of GDP');
title('US import shares and net exports'); xlabel('Year');
legend({'Agriculture','Manufacturing','Net exports (right axis)'}, ...
       'Location','southwest','Box','off');

%---------------------------------------------
%   2. Value added shares, data against the counterfactual
%---------------------------------------------
f2 = figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
for k = 1:2, plot(years,100*r(k).man(w),sty{k},'LineWidth',LW); end
title('Manufacturing'); xlabel('Year'); ylabel('Value added share');
legend(name,'Location','northeast','Box','off');
subplot(1,2,2); hold on; box on; grid on;
for k = 1:2, plot(years,100*r(k).gds(w),sty{k},'LineWidth',LW); end
title('Goods (a and m)'); xlabel('Year');

%---------------------------------------------
%   3. The gap
%---------------------------------------------
f3 = figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
plot(years,100*(r(1).man(w)-r(2).man(w)),'b--','LineWidth',LW);
yline(0,'k-');
title('Manufacturing'); xlabel('Year');
ylabel('Data minus counterfactual, points');
subplot(1,2,2); hold on; box on; grid on;
plot(years,100*(r(1).gds(w)-r(2).gds(w)),'b--','LineWidth',LW);
yline(0,'k-');
title('Goods (a and m)'); xlabel('Year');

%---------------------------------------------
%   4. Trade imbalances
%---------------------------------------------
f4 = figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
for k = 1:2, plot(years,100*r(k).nx(w),sty{k},'LineWidth',LW); end
yline(0,'k-');
title('US trade imbalance'); xlabel('Year'); ylabel('Percent of GDP');
legend(name,'Location','southwest','Box','off');

%---------------------------------------------
%   5. Manufacturing trade costs
%---------------------------------------------
tauUS  = squeeze(D.tau(V.MAN,V.USA,V.ROW,w));   % US importing from ROW
tauROW = squeeze(D.tau(V.MAN,V.ROW,V.USA,w));   % ROW importing from US
f5 = figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
plot(years,tauUS/tauUS(k0),'k-','LineWidth',LW);
plot(years,tauROW/tauROW(k0),'b--','LineWidth',LW);
yline(1,'k--');
title(sprintf('Manufacturing trade costs, %d = 1',P.freezeyear));
xlabel('Year'); ylabel('Trade cost, importer-facing');
legend({'US importing from ROW','ROW importing from US'}, ...
       'Location','northeast','Box','off');

%---------------------------------------------
%   6. Export
%---------------------------------------------
nm = {f1,'us_trade_motivation'; f2,'value_added_shares'; f3,'value_added_gap';
      f4,'trade_imbalances';    f5,'tradecost'};
for q = 1:size(nm,1)
    exportgraphics(nm{q,1},fullfile(outdir,[nm{q,2} '.pdf']), ...
                   'ContentType','vector','BackgroundColor','white');
end
fprintf('Figures written to %s\n',outdir);

% master: Solves the model and reproduces the paper's exhibits. Run this.
clear; clc; close all;
savefig = 1;

%---------------------------------------------
%   Setup
%---------------------------------------------
V = variables;
P = parameters;
D = loaddata(P,V);
B = baseline(P,V,D);

%---------------------------------------------
%   Checks. Nothing below means anything until these are small.
%---------------------------------------------
[g,chk] = yearmodel(1,1,D.NX(V.USA,1),P,V,D,B);
fprintf('Checks\n');
fprintf('  consumption shares add to one    %.1e\n',B.chks);
fprintf('  Y = Pi*E in the data             %.1e\n',D.chkY);
fprintf('  zero shock, income residual      %.1e\n',abs(g));
fprintf('  zero shock, prices return one    %.1e\n',max(abs(chk.Phat(:)-1)));
fprintf('  zero shock, output reproduces    %.1e\n', ...
        max(abs(chk.Y(:)./reshape(D.Y(:,:,1),[],1)-1)));

%---------------------------------------------
%   Solve twice: at the recovered wedge, and with the wedge removed
%---------------------------------------------
fprintf('\nSolving baseline...\n');
base = solvepath(B.omega(V.USA,:)',P,V,D,B);
fprintf('Solving counterfactual...\n');
cf   = solvepath(ones(D.T-1,1),P,V,D,B);

fprintf('  baseline returns the observed net exports  %.1e\n', ...
        max(abs(base.NX - D.NX(V.USA,:)'))/max(abs(D.NX(V.USA,:))));

%---------------------------------------------
%   Value added shares: manufacturing, and goods (agriculture + manufacturing)
%---------------------------------------------
Yb = squeeze(base.Y(:,V.USA,:));
Yc = squeeze(cf.Y(:,V.USA,:));
denb = sum(bsxfun(@times,D.beta(:,V.USA),Yb),1);
denc = sum(bsxfun(@times,D.beta(:,V.USA),Yc),1);

manb = D.beta(V.MAN,V.USA)*Yb(V.MAN,:)./denb;
manc = D.beta(V.MAN,V.USA)*Yc(V.MAN,:)./denc;
gdsb = (D.beta(V.AGR,V.USA)*Yb(V.AGR,:) + D.beta(V.MAN,V.USA)*Yb(V.MAN,:))./denb;
gdsc = (D.beta(V.AGR,V.USA)*Yc(V.AGR,:) + D.beta(V.MAN,V.USA)*Yc(V.MAN,:))./denc;

dman = [manb(end)-manb(1); manc(end)-manc(1)];
dgds = [gdsb(end)-gdsb(1); gdsc(end)-gdsc(1)];

%---------------------------------------------
%   The counterfactual table
%---------------------------------------------
fprintf('\n                         Manufacturing            Goods (a and m)\n');
fprintf('                    dva_US    1-dvaCF/dvaD     dva_US    1-dvaCF/dvaD\n');
fprintf('Data              %7.1f%%                   %7.1f%%\n', ...
        100*dman(1),100*dgds(1));
fprintf('No wedge          %7.1f%%   %9.1f%%      %7.1f%%   %9.1f%%\n', ...
        100*dman(2),100*(1-dman(2)/dman(1)),100*dgds(2),100*(1-dgds(2)/dgds(1)));

%% Figure 1: value added shares, data against the counterfactual
figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
plot(D.years,100*manb,'k-','LineWidth',1.5);
plot(D.years,100*manc,'k:','LineWidth',1.5);
title('Manufacturing'); xlabel('Year'); ylabel('Value Added Share');
legend('Data','No financial friction','Location','northeast');
subplot(1,2,2); hold on; box on; grid on;
plot(D.years,100*gdsb,'k-','LineWidth',1.5);
plot(D.years,100*gdsc,'k:','LineWidth',1.5);
title('Goods (a and m)'); xlabel('Year');

%% Figure 2: trade imbalances, the channel the shock works through
figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
plot(D.years,100*base.NX'./B.VA(V.USA,:),'k-','LineWidth',1.5);
plot(D.years,100*cf.NX'  ./B.VA(V.USA,:),'k:','LineWidth',1.5);
yline(0,'k-');
title('U.S. trade imbalance'); xlabel('Year'); ylabel('Share of GDP, percent');
legend('Data','No financial friction','Location','southwest');

%% Figure 3: the wedge that is being removed
figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
plot(D.years(1:end-1),B.omega(V.USA,:),'k-','LineWidth',1.5);
yline(1,'k--');
title('U.S. Euler equation wedge'); xlabel('Year'); ylabel('Wedge');

if savefig == 1
    if ~exist('results','dir'), mkdir('results'), end
    figure(1); exportgraphics(gcf,'results/value_added_shares.pdf','ContentType','vector');
    figure(2); exportgraphics(gcf,'results/trade_imbalances.pdf','ContentType','vector');
    figure(3); exportgraphics(gcf,'results/wedge.pdf','ContentType','vector');
    save('results/solution.mat','P','V','D','B','base','cf','manb','manc','gdsb','gdsc');
end

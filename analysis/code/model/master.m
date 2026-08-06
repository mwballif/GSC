% master: Solves the model and builds the exhibits. Run this.
clear; clc; close all;
savefig = 1;
runsens = 1;      % also check the answer against the length of the padding

%---------------------------------------------
%   Setup
%---------------------------------------------
V = variables;
P = parameters;
D = loaddata(P,V);
B = baseline(P,V,D);

Tdata = D.T;
years = D.years;
w     = 1:Tdata;                  % the window that gets reported
D0 = D;  B0 = B;                  % unpadded, kept for the sensitivity run

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
%   Extend the horizon past the sample
%---------------------------------------------
[D,B] = padyears(P.pad,P,V,D,B);

%---------------------------------------------
%   Wedge paths. The padded years carry no friction in any run, so they
%   settle the bond position without contributing to the comparison.
%---------------------------------------------
k0     = find(years == P.freezeyear,1);
omData = B.omega(V.USA,:)';
omFroz = omData;  omFroz(1:Tdata-1) = omData(k0);
omNone = omData;  omNone(1:Tdata-1) = 1;

%---------------------------------------------
%   Four runs. Only the wedge, or net exports, differs across them.
%---------------------------------------------
name = {'Data', sprintf('Friction frozen at %d',P.freezeyear), ...
        'No friction', 'No trade imbalances'};

fprintf('\n%s\n',name{1});  r(1).o = solvepath(omData,P,V,D,B);
fprintf('%s\n',  name{2});  r(2).o = solvepath(omFroz,P,V,D,B);
fprintf('%s\n',  name{3});  r(3).o = solvepath(omNone,P,V,D,B);
fprintf('%s\n',  name{4});  [~,r(4).o] = pathmodel(zeros(D.T,1),omData,P,V,D,B);

fprintf('\n  baseline returns the observed net exports  %.1e\n', ...
        max(abs(r(1).o.NX(w) - D.NX(V.USA,w)'))/max(abs(D.NX(V.USA,w))));

for k = 1:4
    [r(k).man, r(k).gds] = vashares(r(k).o.Y,D,V);
    r(k).nx = r(k).o.NX(w)' ./ B.VA(V.USA,w);
end

%---------------------------------------------
%   The counterfactual table, over the full sample and over the
%   1970-2007 window the paper reports
%---------------------------------------------
win = {'1965-2014', 1, Tdata; ...
       '1970-2007', find(years==1970,1), find(years==2007,1)};

for iw = 1:size(win,1)
    a = win{iw,2};  b = win{iw,3};
    fprintf('\n%s                    Manufacturing          Goods (a and m)\n',win{iw,1});
    fprintf('                            dva     1-dvaCF/dvaD      dva     1-dvaCF/dvaD\n');
    dm0 = r(1).man(b)-r(1).man(a);
    dg0 = r(1).gds(b)-r(1).gds(a);
    fprintf('%-26s%7.1f%%                  %7.1f%%\n',name{1},100*dm0,100*dg0);
    for k = 2:4
        dm = r(k).man(b)-r(k).man(a);
        dg = r(k).gds(b)-r(k).gds(a);
        fprintf('%-26s%7.1f%%   %10.1f%%   %7.1f%%   %10.1f%%\n', ...
                name{k},100*dm,100*(1-dm/dm0),100*dg,100*(1-dg/dg0));
    end
end

dmData = r(1).man(Tdata) - r(1).man(1);

%---------------------------------------------
%   Does the answer still depend on where the horizon ends
%---------------------------------------------
if runsens == 1
    pads = [0 10 20 30];
    fprintf('\nPadding   dva man, frozen   1-dvaCF/dvaD\n');
    for ip = 1:numel(pads)
        [Ds,Bs] = padyears(pads(ip),P,V,D0,B0);
        om = Bs.omega(V.USA,:)';  om(1:Tdata-1) = om(k0);
        os = solvepath(om,P,V,Ds,Bs);
        ms = vashares(os.Y,Ds,V);
        fprintf('%7d   %14.1f%%   %12.1f%%\n', pads(ip), ...
                100*(ms(Tdata)-ms(1)), 100*(1-(ms(Tdata)-ms(1))/dmData));
    end
end

%---------------------------------------------
%   Figures
%---------------------------------------------
sty = {'k-','b--','r:','m-.'};

%% Figure 1: value added shares, data against the counterfactuals
figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
for k = 1:4, plot(years,100*r(k).man(w),sty{k},'LineWidth',1.5); end
title('Manufacturing'); xlabel('Year'); ylabel('Value Added Share');
legend(name,'Location','northeast');
subplot(1,2,2); hold on; box on; grid on;
for k = 1:4, plot(years,100*r(k).gds(w),sty{k},'LineWidth',1.5); end
title('Goods (a and m)'); xlabel('Year');

%% Figure 2: the gap. This is where the answer is visible.
figure('Position',[100,100,900,380],'Color','w');
subplot(1,2,1); hold on; box on; grid on;
for k = 2:4, plot(years,100*(r(1).man(w)-r(k).man(w)),sty{k},'LineWidth',1.5); end
yline(0,'k-');
title('Manufacturing'); xlabel('Year');
ylabel('Data minus counterfactual, percentage points');
legend(name(2:4),'Location','southwest');
subplot(1,2,2); hold on; box on; grid on;
for k = 2:4, plot(years,100*(r(1).gds(w)-r(k).gds(w)),sty{k},'LineWidth',1.5); end
yline(0,'k-');
title('Goods (a and m)'); xlabel('Year');

%% Figure 3: trade imbalances, the channel the friction works through
figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
for k = 1:4, plot(years,100*r(k).nx,sty{k},'LineWidth',1.5); end
yline(0,'k-');
title('U.S. trade imbalance'); xlabel('Year'); ylabel('Share of GDP, percent');
legend(name,'Location','southwest');

%% Figure 4: the friction, against the year it is frozen at
figure('Position',[100,100,650,400],'Color','w');
hold on; box on; grid on;
plot(years(1:end-1),omData(1:Tdata-1)/omData(k0),'k-','LineWidth',1.5);
yline(1,'k--');
title(sprintf('U.S. financial friction, %d = 1',P.freezeyear));
xlabel('Year'); ylabel('Wedge');

if savefig == 1
    if ~exist('results','dir'), mkdir('results'), end
    figure(1); exportgraphics(gcf,'results/value_added_shares.pdf','ContentType','vector');
    figure(2); exportgraphics(gcf,'results/value_added_gap.pdf','ContentType','vector');
    figure(3); exportgraphics(gcf,'results/trade_imbalances.pdf','ContentType','vector');
    figure(4); exportgraphics(gcf,'results/friction.pdf','ContentType','vector');
    save('results/solution.mat','P','V','D','B','r','name','years','Tdata');
end

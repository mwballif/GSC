%==============================================================================
% make_parameter_figures.m
%
% Purpose: Plot the recovered parameters.
% Reads:   recovered_parameters.csv, recovered_friction.csv,
%          recovered_invshares.csv, recovered_constants.csv,
%          CountrySectorPanel_2country.csv
% Writes:  results/figures/*.pdf
%
% Shared conventions, so every figure reads the same way:
%   sgtitle    descriptive Title Case, no math and no numbers
%   panel      title is "identity: $symbol$" with the LaTeX interpreter, where
%              identity is the sector or country and the symbol carries any
%              normalization; no ylabel anywhere
%   axes       box on, xlim to the sample, xlabel 'Year' on the bottom row only
%   legend     first panel only, Box off
%   lines      LineWidth 1.5, sector colour from col, US solid and ROW dashed;
%              2.0 and black is reserved for an emphasized series
%   reference  yline at the neutral value, ':' in grey
%
% Figure 1: the consumption demand shifters mu by sector, one panel per country.
% Figure 2: tau indexed to the base year, one panel per sector. The two
% directional tau lines are dotted (the asymmetry is the relative-price
% contamination); the Head-Ries index is the emphasized line.
% Figure 2b: the Head-Ries index on its own, one panel per sector, a single
% line because the index is symmetric across importers.
% Figure 3: productivities as log(T)^(1/theta), one stacked panel per sector.
% Figure 4: the financial friction as the effective return wedge, one line per
% country. Both countries' frictions are recovered, so neither line is a
% normalization. The wedge is the ratio form; phi's level is not plotted
% because it is not invariant to the bond normalization.
% Figure 5: the investment tax (appendix eq:xi-recover). Only the growth is
% identified, so the left panel is the ratio and the right its cumulation.
% Figure 6: the recovered investment demand shifters mu^x (appendix eq:mux) by
% sector, one panel per country, drawn like Figure 1.
% Figure 7: the value added share of gross output, beta, against the single
% constant the model holds it at. The reference line is per sector rather than
% a single neutral value, so it carries the sector colour.
%
% NOTE: theta below must match recover_parameters.m.
% NOTE: these are fundamental productivities, not measured productivity.
%==============================================================================

clear; close all;

datapath = "../../../data/processed/";
figpath  = "../../../results/figures/";
if ~isfolder(figpath); mkdir(figpath); end

baseYear        = 1965;   % normalization year for the trade cost index
includeServices = true;   % third trade cost panel (tradable services)
theta           = 2;      % trade elasticity; must match recover_parameters.m

secs   = ["AGR", "MAN", "SER"];
slabs  = ["Agriculture", "Manufacturing", "Services"];
sups   = ["a", "m", "s"];                 % sector superscripts for labels
cnames = ["USA", "ROW"];
clabs  = ["United States", "Rest of the World"];
J = 3;

% sector colors: agriculture teal-green, manufacturing blue, services red
col = [0    0.45 0.35;
       0    0    0.80;
       0.85 0.10 0.10];

% country colors: US solid line, ROW dashed line
colUS  = [0    0    0.80];   % manufacturing blue
colROW = [0.85 0.10 0.10];   % services red

%% load recovered parameters
tab   = readtable(datapath + "recovered_parameters.csv");
years = unique(tab.year);
Ty    = length(years);

mu   = zeros(2, J, Ty);
tau  = zeros(2, J, Ty);
htau = zeros(J, Ty);
Tprd = zeros(2, J, Ty);
for i = 1:2
    for j = 1:J
        rows = strcmp(tab.country, cnames(i)) & strcmp(tab.sector, secs(j));
        sub  = sortrows(tab(rows, :), 'year');
        mu(i, j, :)   = sub.mu;
        tau(i, j, :)  = sub.tau;
        Tprd(i, j, :) = sub.T;
        % htau is symmetric, so the US (importer 1) rows carry the sector-year
        % value; the ROW rows duplicate it.
        if i == 1
            htau(j, :) = sub.htau;
        end
    end
end

%% Figure 1: Sectoral Consumption Demand Shifters
% One panel per country, three sector lines; line styles follow the paper.
styles = [":", "-", "--"];

fig1 = figure('Units', 'inches', 'Position', [1 1 7 4.35], 'Color', 'w');
for i = 1:2
    subplot(1, 2, i); hold on; box on;
    for j = 1:J
        plot(years, squeeze(mu(i, j, :)), styles(j), ...
            'Color', col(j, :), 'LineWidth', 1.5);
    end
    title(sprintf('%s: $\\mu^j_{%s,t}$', clabs(i), erase(cnames(i), "A")), ...
        'Interpreter', 'latex');
    xlabel('Year'); xlim([years(1) years(end)]);
    if i == 1
        legend(slabs, 'Location', 'northwest', 'Box', 'off');
    end
end
sgtitle(fig1, 'Evolution of Sectoral Consumption Demand Shifters');
exportgraphics(fig1, figpath + "consumption_demand_shifters.pdf");

%% Figure 2: Sectoral Trade Costs
% One panel per sector, indexed to the base year. The directional lines are
% dotted because their asymmetry is relative-price contamination; the Head-Ries
% index is the emphasized line, on the same base so the three are comparable.
tb = find(years == baseYear);
if isempty(tb)
    tb = 1;
    warning('Base year %d not in data; normalizing to %d instead.', ...
        baseYear, years(1));
end

nPan = 2 + includeServices;
fig2 = figure('Units', 'inches', 'Position', [1 1 3.5*nPan 4.35], 'Color', 'w');
for j = 1:nPan
    subplot(1, nPan, j); hold on; box on;
    base = tau(:, j, tb);
    h1 = plot(years, squeeze(tau(1, j, :)) / base(1), ':', ...
        'Color', colUS, 'LineWidth', 1.5);
    h2 = plot(years, squeeze(tau(2, j, :)) / base(2), ':', ...
        'Color', colROW, 'LineWidth', 1.5);
    h3 = plot(years, squeeze(htau(j, :)) / htau(j, tb), '-k', ...
        'LineWidth', 2.0);
    yline(1, ':', 'Color', [0.6 0.6 0.6]);
    title(sprintf('%s: $\\tau^%s_{i,t}/\\tau^%s_{i,%d}$', ...
        slabs(j), sups(j), sups(j), years(tb)), 'Interpreter', 'latex');
    xlabel('Year'); xlim([years(1) years(end)]);
    if j == 1
        legend([h1 h2 h3], {'US importing', 'ROW importing', 'Head-Ries'}, ...
            'Location', 'southwest', 'Box', 'off');
    end
end
sgtitle(fig2, 'Evolution of Sectoral Trade Costs');
exportgraphics(fig2, figpath + "trade_costs.pdf");

%% Figure 2b: Head-Ries Symmetric Trade Friction
% One line per panel: the index is one number per sector-year, and unlike tau it
% cancels prices, so it carries no relative-price contamination.
figH = figure('Units', 'inches', 'Position', [1 1 3.5*nPan 4.35], 'Color', 'w');
for j = 1:nPan
    subplot(1, nPan, j); hold on; box on;
    plot(years, squeeze(htau(j, :)), '-', ...
        'Color', col(j, :), 'LineWidth', 1.5);
    title(sprintf('%s: $\\hat\\tau^%s_{t}$', slabs(j), sups(j)), ...
        'Interpreter', 'latex');
    xlabel('Year'); xlim([years(1) years(end)]);
end
sgtitle(figH, 'Head-Ries Symmetric Trade Friction');
exportgraphics(figH, figpath + "trade_costs_headries.pdf");

%% Figure 3: Sectoral Productivities
% One stacked panel per sector, US solid and ROW dashed, every series starting
% at zero in the base year.
fig3 = figure('Units', 'inches', 'Position', [1 1 6.5 6.5], 'Color', 'w');
for j = 1:J
    subplot(J, 1, j); hold on; box on;
    base = Tprd(:, j, tb);
    h1 = plot(years, log(squeeze(Tprd(1, j, :)) / base(1)) / theta, '-', ...
        'Color', col(j, :), 'LineWidth', 1.5);
    h2 = plot(years, log(squeeze(Tprd(2, j, :)) / base(2)) / theta, '--', ...
        'Color', col(j, :), 'LineWidth', 1.5);
    yline(0, ':', 'Color', [0.6 0.6 0.6]);
    title(sprintf('%s: $\\log(T^%s_{i,t}/T^%s_{i,%d})^{1/\\theta}$', ...
        slabs(j), sups(j), sups(j), years(tb)), 'Interpreter', 'latex');
    xlim([years(1) years(end)]);
    if j == 1
        legend([h1 h2], clabs, 'Location', 'northwest', 'Box', 'off');
    end
    if j == J
        xlabel('Year');
    else
        set(gca, 'XTickLabel', []);
    end
end
sgtitle(fig3, 'Evolution of Sectoral Productivities');
exportgraphics(fig3, figpath + "productivities.pdf");

%% load the country-year block: friction, bonds, capital wedge
fr    = readtable(datapath + "recovered_friction.csv");
yrsF  = unique(fr.year);
TyF   = length(yrsF);

wedge  = zeros(2, TyF);
bonds  = zeros(2, TyF);
chirat = zeros(2, TyF);
chilvl = zeros(2, TyF);
for i = 1:2
    sub = sortrows(fr(strcmp(fr.country, cnames(i)), :), 'year');
    wedge(i, :)  = sub.wedge;
    bonds(i, :)  = sub.bonds;
    chirat(i, :) = sub.chi_ratio;
    chilvl(i, :) = sub.chi;
end

%% Figure 4: Financial Friction
% R is observed (the 10-year Treasury yield), so both countries' frictions are
% recovered from their own Euler equations and neither is normalized.
%
% NOTE: plot the wedge, not phi. phi is in units of 1/USD millions and its level
% moves with the bond normalization, while the wedge is invariant to it; phi
% also blows up where ROW bonds cross zero (2000-2007).
fig4 = figure('Units', 'inches', 'Position', [1 1 4.5 4.35], 'Color', 'w');
hold on; box on;
h1 = plot(yrsF, wedge(1, :), '-',  'Color', colUS,  'LineWidth', 1.5);
h2 = plot(yrsF, wedge(2, :), '--', 'Color', colROW, 'LineWidth', 1.5);
yline(1, ':', 'Color', [0.6 0.6 0.6]);
title('$1 + \phi_{i,t}(B_{i,t+1} - \bar{B}_i)$', 'Interpreter', 'latex');
xlabel('Year'); xlim([yrsF(1) yrsF(end)]);
legend([h1 h2], clabs, 'Location', 'northeast', 'Box', 'off');
% NOTE: single-panel figure, so shrink the axes or the sgtitle lands on top of
% the panel title.
set(gca, 'Position', [0.13 0.13 0.80 0.72]);

sgtitle(fig4, 'Financial Friction: Effective Return Wedge');
exportgraphics(fig4, figpath + "financial_friction.pdf");

%% Figure 5: Investment Tax
% The capital Euler identifies only the growth of chi, so the level on the right
% is a normalization: chi is one in the first year and chained forward.
fig5 = figure('Units', 'inches', 'Position', [1 1 7 4.35], 'Color', 'w');

subplot(1, 2, 1); hold on; box on;
h1 = plot(yrsF, chirat(1, :), '-',  'Color', colUS,  'LineWidth', 1.5);
h2 = plot(yrsF, chirat(2, :), '--', 'Color', colROW, 'LineWidth', 1.5);
yline(1, ':', 'Color', [0.6 0.6 0.6]);
title('Ratio: $\chi_{i,t+1}/\chi_{i,t}$', 'Interpreter', 'latex');
xlabel('Year'); xlim([yrsF(1) yrsF(end)]);
legend([h1 h2], clabs, 'Location', 'best', 'Box', 'off');

subplot(1, 2, 2); hold on; box on;
plot(yrsF, chilvl(1, :), '-',  'Color', colUS,  'LineWidth', 1.5);
plot(yrsF, chilvl(2, :), '--', 'Color', colROW, 'LineWidth', 1.5);
yline(1, ':', 'Color', [0.6 0.6 0.6]);
title(sprintf('Level: $\\chi_{i,t}$, %d $= 1$', yrsF(1)), 'Interpreter', 'latex');
xlabel('Year'); xlim([yrsF(1) yrsF(end)]);

sgtitle(fig5, 'Investment Tax');
exportgraphics(fig5, figpath + "investment_efficiency.pdf");

%% Figure 6: Sectoral Investment Demand Shifters
% The investment-side counterpart of Figure 1, drawn the same way: one panel per
% country, three sector lines, same styles. At zeta = 1 the shifters equal the
% observed expenditure shares.
%
% NOTE: the paper's constant upsilon, which mu^x replaces, is no longer drawn.
% NOTE: the vertical gap against upsilon used to be absorbed by the consumption
% shifter mu; mu^x now takes it, which is why mu^AGR is no longer noisy.
iv   = readtable(datapath + "recovered_invshares.csv");
yrsI = unique(iv.year);

fig6 = figure('Units', 'inches', 'Position', [1 1 7 4.35], 'Color', 'w');
for i = 1:2
    subplot(1, 2, i); hold on; box on;
    for j = 1:J
        sub = sortrows(iv(strcmp(iv.country, cnames(i)) & ...
                          strcmp(iv.sector, secs(j)), :), 'year');
        plot(yrsI, sub.mu_x, styles(j), ...
            'Color', col(j, :), 'LineWidth', 1.5);
    end
    title(sprintf('%s: $\\mu^{x,j}_{%s,t}$', clabs(i), erase(cnames(i), "A")), ...
        'Interpreter', 'latex');
    xlabel('Year'); xlim([yrsI(1) yrsI(end)]); ylim([0 1]);
    if i == 1
        legend(slabs, 'Location', 'northwest', 'Box', 'off');
    end
end
sgtitle(fig6, 'Evolution of Sectoral Investment Demand Shifters');
exportgraphics(fig6, figpath + "investment_demand_shifters.pdf");

%% figure 7: value added shares against the constant the model uses
% The model takes beta as time invariant. The panel shows what it does.
pan  = readtable(datapath + "CountrySectorPanel_2country.csv", 'TextType', 'char');
cons = readtable(datapath + "recovered_constants.csv", 'TextType', 'char');
yrsB = unique(pan.year);

fig7 = figure('Units', 'inches', 'Position', [1 1 7 4.35], 'Color', 'w');
for i = 1:2
    subplot(1, 2, i); hold on; box on;
    hb = gobjects(J, 1);
    for j = 1:J
        sub = sortrows(pan(strcmp(pan.country, cnames(i)) & ...
                           strcmp(pan.sector, secs(j)), :), 'year');
        hb(j) = plot(yrsB, sub.va_wiot ./ sub.go_wiot, '-', ...
            'Color', col(j, :), 'LineWidth', 1.5);
        b = cons.beta(strcmp(cons.country, cnames(i)) & ...
                      strcmp(cons.sector, secs(j)));
        yline(b, ':', 'Color', col(j, :), 'LineWidth', 1.5);
    end
    title(sprintf('%s: $\\beta^{j}_{%s}$', clabs(i), erase(cnames(i), "A")), ...
        'Interpreter', 'latex');
    xlabel('Year'); xlim([yrsB(1) yrsB(end)]); ylim([0.25 0.70]);
    if i == 1
        legend(hb, slabs, 'Location', 'southwest', 'Box', 'off');
    end
end
sgtitle(fig7, 'Value Added Shares Against the Constant the Model Uses');
exportgraphics(fig7, figpath + "value_added_shares_beta.pdf");

fprintf('Figures written to %s\n', figpath);

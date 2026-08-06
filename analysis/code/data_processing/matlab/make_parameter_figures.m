%{
==============================================================================
make_parameter_figures.m

Purpose: Plot the recovered parameters.
Reads:   recovered_parameters.csv, recovered_friction.csv,
         recovered_invshares.csv, recovered_world_rate.csv
Writes:  results/figures/*.pdf

Figure 1 (RH Figure 2): mu by sector, one panel per country.
Figure 2 (RH Figure 3): tau indexed to the base year, one panel per
sector, US and ROW lines. tau is the cost the named country pays to
import from the other country. Services are included since they are
treated as tradable here; set includeServices = false to match the
two-panel figure in the paper.
Figure 3 (RH Figure 4): productivities as log(T)^(1/theta), one stacked panel
per sector, US solid and ROW dashed, normalized to zero in the base year.
Figure 4: the financial friction, plotted as the effective return wedge
1 + phi(B - Bbar) rather than phi itself, alongside the world interest rate.
Figure 5: the investment-specific efficiency shifter chi, in levels, at the
baseline sigma = 0 and at the interior sigma reported alongside it.
Figure 6: sectoral investment shares, the model's constant upsilon against the
observed year by year shares.

NOTE: theta below must match recover_parameters.m.
NOTE: these are fundamental productivities, not measured productivity.
==============================================================================
%}

clear; close all;

datapath = "../../../data/processed/";
figpath  = "../../../results/figures/";
if ~isfolder(figpath); mkdir(figpath); end

baseYear        = 1965;   % normalization year for the trade cost index
includeServices = true;   % third trade cost panel (tradable services)
theta           = 4;      % trade elasticity; must match recover_parameters.m

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

%% load recovered parameters
tab   = readtable(datapath + "recovered_parameters.csv");
years = unique(tab.year);
Ty    = length(years);

mu   = zeros(2, J, Ty);
tau  = zeros(2, J, Ty);
Tprd = zeros(2, J, Ty);
for i = 1:2
    for j = 1:J
        rows = strcmp(tab.country, cnames(i)) & strcmp(tab.sector, secs(j));
        sub  = sortrows(tab(rows, :), 'year');
        mu(i, j, :)   = sub.mu;
        tau(i, j, :)  = sub.tau;
        Tprd(i, j, :) = sub.T;
    end
end

%% Figure: Evolution of Sectoral Demand Shifters (RH Figure 2)
% one panel per country, three sector lines; line styles follow the paper
styles = [":", "-", "--"];

fig1 = figure('Units', 'inches', 'Position', [1 1 7 5.8], 'Color', 'w');
for i = 1:2
    subplot(1, 2, i); hold on; box on;
    for j = 1:J
        plot(years, squeeze(mu(i, j, :)), styles(j), ...
            'Color', col(j, :), 'LineWidth', 1.5);
    end
    title(sprintf('%s: $\\mu^j_{%s,t}$', clabs(i), erase(cnames(i), "A")), ...
        'Interpreter', 'latex');
    xlabel('Year');
    xlim([years(1) years(end)]);
    if i == 1
        legend(slabs, 'Location', 'northwest', 'Box', 'off');
    end
end
sgtitle(fig1, 'Evolution of Sectoral Demand Shifters');
exportgraphics(fig1, figpath + "demand_shifters.pdf");

%% Figure: Evolution of Sectoral Trade Costs (RH Figure 3)
% one panel per sector, indexed to the base year; US solid, ROW dashed
tb = find(years == baseYear);
if isempty(tb)
    tb = 1;
    warning('Base year %d not in data; normalizing to %d instead.', ...
        baseYear, years(1));
end

nPan = 2 + includeServices;
fig2 = figure('Units', 'inches', 'Position', [1 1 3.5*nPan 5.8], 'Color', 'w');
for j = 1:nPan
    subplot(1, nPan, j); hold on; box on;
    base = tau(:, j, tb);
    plot(years, squeeze(tau(1, j, :)) / base(1), '-', ...
        'Color', col(j, :), 'LineWidth', 1.5);
    plot(years, squeeze(tau(2, j, :)) / base(2), '--', ...
        'Color', col(j, :), 'LineWidth', 1.5);
    title(slabs(j));
    xlabel('Year');
    xlim([years(1) years(end)]);
    ylabel(sprintf(['Index: $\\tau^%s_t/\\tau^%s_{%d}$ ' ...
        '($\\tau^%s_{US,%d} = %.1f$, $\\tau^%s_{ROW,%d} = %.1f$)'], ...
        sups(j), sups(j), years(tb), ...
        sups(j), years(tb), base(1), sups(j), years(tb), base(2)), ...
        'Interpreter', 'latex');
    if j == 1
        legend(clabs, 'Location', 'southwest', 'Box', 'off');
    end
end
sgtitle(fig2, 'Evolution of Sectoral Trade Costs');
exportgraphics(fig2, figpath + "trade_costs.pdf");

%% Figure: Evolution of Sectoral Productivities (RH Figure 4)
% One stacked panel per sector, US solid and ROW dashed, every series starting
% at zero.

fig3 = figure('Units', 'inches', 'Position', [1 1 6.5 6.5], 'Color', 'w');
for j = 1:J
    subplot(J, 1, j); hold on; box on;
    base = Tprd(:, j, tb);
    plot(years, log(squeeze(Tprd(1, j, :)) / base(1)) / theta, '-', ...
        'Color', col(j, :), 'LineWidth', 1.5);
    plot(years, log(squeeze(Tprd(2, j, :)) / base(2)) / theta, '--', ...
        'Color', col(j, :), 'LineWidth', 1.5);
    yline(0, ':', 'Color', [0.6 0.6 0.6]);
    ylabel(slabs(j));
    xlim([years(1) years(end)]);
    if j == 1
        legend(["US", "ROW"], 'Location', 'northwest', 'Box', 'off');
        title(sprintf('Sectoral Productivities: $\\log(T^j_{i,t})^{1/\\theta}$, %d = 0', ...
            years(tb)), 'Interpreter', 'latex');
    end
    if j == J
        xlabel('Year');
    else
        set(gca, 'XTickLabel', []);
    end
end
sgtitle(fig3, 'Evolution of Sectoral Productivities');
exportgraphics(fig3, figpath + "productivities.pdf");

%% load the country-year block: friction, wedge, bonds, chi
fr    = readtable(datapath + "recovered_friction.csv");
yrsF  = unique(fr.year);
TyF   = length(yrsF);

wedge  = zeros(2, TyF);
bonds  = zeros(2, TyF);
chi    = zeros(2, TyF);
for i = 1:2
    sub = sortrows(fr(strcmp(fr.country, cnames(i)), :), 'year');
    wedge(i, :)  = sub.wedge;
    bonds(i, :)  = sub.bonds;
    chi(i, :)    = sub.chi;
end

Rw    = readtable(datapath + "recovered_world_rate.csv");
Rw    = sortrows(Rw, 'year');

%% Figure: Financial Friction
% Left panel: the effective return wedge. Right panel: the net foreign asset
% position behind it.
%
% NOTE: plot the wedge, not phi, which blows up where bonds cross zero.
fig4 = figure('Units', 'inches', 'Position', [1 1 7 4], 'Color', 'w');

subplot(1, 2, 1); hold on; box on;
plot(yrsF, wedge(1, :), '-', 'Color', [0 0 0.8], 'LineWidth', 1.5);
yline(1, ':', 'Color', [0.6 0.6 0.6]);
title('Effective return wedge', 'Interpreter', 'latex');
ylabel('$1 + \phi_{US,t}(B_{US,t+1} - \bar{B}_{US})$', 'Interpreter', 'latex');
xlabel('Year'); xlim([yrsF(1) yrsF(end)]);

subplot(1, 2, 2); hold on; box on;
plot(yrsF, bonds(1, :) / 1e6, '-', 'Color', [0 0 0.8], 'LineWidth', 1.5);
yline(0, ':', 'Color', [0.6 0.6 0.6]);
title('US net foreign assets', 'Interpreter', 'latex');
ylabel('$B_{US,t+1}$, trillions of USD', 'Interpreter', 'latex');
xlabel('Year'); xlim([yrsF(1) yrsF(end)]);

sgtitle(fig4, sprintf(['Financial Friction (world rate: mean %.3f, ' ...
    'range %.3f to %.3f)'], mean(Rw.R_world), min(Rw.R_world), max(Rw.R_world)));
exportgraphics(fig4, figpath + "financial_friction.pdf");

%% Figure: Investment-Specific Efficiency Shifters
% NOTE: at sigma = 0 investment drops out and chi is just capital growth.
fig5 = figure('Units', 'inches', 'Position', [1 1 5 4], 'Color', 'w');
hold on; box on;
plot(yrsF, chi(1, :), '-',  'Color', [0 0 0.8], 'LineWidth', 1.5);
plot(yrsF, chi(2, :), '--', 'Color', [0.85 0.1 0.1], 'LineWidth', 1.5);
title("\sigma = 0 (the paper's calibration)", 'Interpreter', 'tex');
ylabel('$\chi_{i,t}$', 'Interpreter', 'latex');
xlabel('Year'); xlim([yrsF(1) yrsF(end)]);
legend(clabs, 'Location', 'best', 'Box', 'off');
sgtitle(fig5, 'Investment-Specific Efficiency Shifters');
exportgraphics(fig5, figpath + "investment_efficiency.pdf");

%% Figure: Sectoral Investment Shares
% Solid lines are the observed investment shares; dashed horizontals are the
% constant upsilon the model imposes at zeta = 1.
%
% NOTE: the vertical gap is what the mu inversion absorbs.
iv    = readtable(datapath + "recovered_invshares.csv");
yrsI  = unique(iv.year);

fig6 = figure('Units', 'inches', 'Position', [1 1 7 4], 'Color', 'w');
for i = 1:2
    subplot(1, 2, i); hold on; box on;
    % NOTE: collect handles, or yline objects hijack the legend.
    h = gobjects(1, J);
    for j = 1:J
        sub = sortrows(iv(strcmp(iv.country, cnames(i)) & ...
                          strcmp(iv.sector, secs(j)), :), 'year');
        h(j) = plot(yrsI, sub.x_share_obs, '-', ...
            'Color', col(j, :), 'LineWidth', 1.5);
        yline(sub.upsilon(1), '--', 'Color', col(j, :), 'LineWidth', 1.0);
    end
    title(clabs(i));
    ylabel('$x^j_{i,t}$ (solid) vs $\upsilon^j_i$ (dashed)', 'Interpreter', 'latex');
    xlabel('Year'); xlim([yrsI(1) yrsI(end)]); ylim([0 1]);
    if i == 1
        legend(h, slabs, 'Location', 'best', 'Box', 'off');
    end
end
sgtitle(fig6, 'Sectoral Investment Shares: Observed vs Model Constant');
exportgraphics(fig6, figpath + "investment_shares.pdf");

fprintf('Figures written to %s\n', figpath);

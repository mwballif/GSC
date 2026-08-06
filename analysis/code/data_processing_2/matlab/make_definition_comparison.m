%{
==============================================================================
make_definition_comparison.m

Purpose: Compare the baseline sector definition against the data_processing_2
         experiment (distributive trade counted as goods, government excluded).
Reads:   data/processed{,_2}/CountrySectorPanel_2country.csv
         data/processed{,_2}/recovered_parameters.csv
Writes:  results/figures/definition_comparison.pdf
==============================================================================
%}

clear; close all;

root = "../../../";
d1   = root + "data/processed/";
d2   = root + "data/processed_2/";
figpath = root + "results/figures/";

secs  = ["AGR", "MAN", "SER"];
slabs = ["Agriculture", "Manufacturing", "Services"];
col   = [0 0.45 0.35; 0 0 0.80; 0.85 0.10 0.10];

%% US consumption expenditure shares under each convention
shares = @(d) local_shares(d);
[yrs, s1] = shares(d1);
[~,   s2] = shares(d2);

%% US demand shifters under each convention
p1 = readtable(d1 + "recovered_parameters.csv");
p2 = readtable(d2 + "recovered_parameters.csv");
m1 = local_mu(p1, secs);
m2 = local_mu(p2, secs);
yrsp = unique(p1.year);

%% figure: top row consumption shares, bottom row demand shifters
fig = figure('Units', 'inches', 'Position', [1 1 9 6], 'Color', 'w');
for j = 1:3
    subplot(2, 3, j); hold on; box on;
    plot(yrs, s1(:, j), '-',  'Color', col(j, :), 'LineWidth', 1.5);
    plot(yrs, s2(:, j), '--', 'Color', col(j, :), 'LineWidth', 1.5);
    title(slabs(j));
    xlim([yrs(1) yrs(end)]);
    if j == 1
        ylabel('Consumption share');
        legend({'Baseline', 'Trade as goods'}, 'Location', 'northwest', 'Box', 'off');
    end
end
for j = 1:3
    subplot(2, 3, 3 + j); hold on; box on;
    plot(yrsp, m1(:, j), '-',  'Color', col(j, :), 'LineWidth', 1.5);
    plot(yrsp, m2(:, j), '--', 'Color', col(j, :), 'LineWidth', 1.5);
    xlabel('Year');
    xlim([yrsp(1) yrsp(end)]);
    if j == 1
        ylabel('Demand shifter');
    end
end
sgtitle(fig, 'United States: baseline definition (solid) against trade-as-goods (dashed)');
exportgraphics(fig, figpath + "definition_comparison.pdf");

%% numbers for the note
fprintf('\nUS consumption shares\n');
for y = [1965 1990 2014]
    t = find(yrs == y);
    fprintf('%d  base %.3f %.3f %.3f | exp %.3f %.3f %.3f\n', y, s1(t,:), s2(t,:));
end
fprintf('\nUS mu, first and last year\n');
for j = 1:3
    fprintf('%s  base %.3f -> %.3f | exp %.3f -> %.3f\n', secs(j), ...
        m1(1,j), m1(end,j), m2(1,j), m2(end,j));
end

function [yrs, S] = local_shares(d)
    t   = readtable(d + "CountrySectorPanel_2country.csv");
    t   = t(strcmp(t.country, "USA"), :);
    yrs = unique(t.year);
    S   = zeros(numel(yrs), 3);
    secs = ["AGR", "MAN", "SER"];
    for j = 1:3
        sub = sortrows(t(strcmp(t.sector, secs(j)), :), 'year');
        S(:, j) = sub.consump;
    end
    S = S ./ sum(S, 2);
end

function M = local_mu(t, secs)
    t = t(strcmp(t.country, "USA"), :);
    M = zeros(numel(unique(t.year)), 3);
    for j = 1:3
        sub = sortrows(t(strcmp(t.sector, secs(j)), :), 'year');
        M(:, j) = sub.mu;
    end
end

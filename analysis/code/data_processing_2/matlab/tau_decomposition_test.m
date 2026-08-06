%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% tau_decomposition_test.m
%
% Diagnostic for the recovered sectoral trade costs. It splits tau into its
% two multiplicative pieces and reports which one drives its movement, to
% separate a genuine trade-cost signal from a price-level or import-share
% artifact (the agriculture trade-cost puzzle).
%
% Recovery identity (recover_parameters.m, sheet eqs 11-16), for importer d
% buying from exporter o:
%
%   tau(d,o) = ( P_d / P_o )  *  ( pi_oo / pi_do )^(1/theta)
%              \___________/     \__________________/
%               price ratio        import-share term
%
% Because log tau = log(price ratio) + log(share term) EXACTLY, the
% variance of log tau splits cleanly into a price contribution and a share
% contribution via the covariance decomposition
%
%   var(log tau) = cov(log tau, log price) + cov(log tau, log share).
%
% If the share term carries most of the variance, tau's weirdness is the
% low-tradability / near-zero / jumpy import-share issue. If the price
% ratio carries it, it is the sectoral price-level construction (go_lvl).
%
% Reads the same two country panels recover_parameters.m uses. Run from the
% matlab code folder so the relative datapath resolves.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear

datapath = '../../../data/processed_2/';
theta    = 4;                       % trade elasticity, as in recover_parameters
years    = 1965:2014;
Ty       = numel(years);
secs     = {'AGR','MAN','SER'};
J        = 3;
cnames   = {'USA','ROW'};

cs = readtable(strcat(datapath, 'CountrySectorPanel_2country.csv'));    % prices (go_lvl)
bp = readtable(strcat(datapath, 'ImpExpSectorPanel_2country.csv'));     % import shares (imp_sh)

%% Sector price levels P(i,j,t) = go_lvl, exactly as recover_parameters reads them
P = nan(2, J, Ty);
for i = 1:2
    for j = 1:J
        for t = 1:Ty
            row = strcmp(cs.country, cnames{i}) & strcmp(cs.sector, secs{j}) & cs.year == years(t);
            if any(row), P(i,j,t) = cs.go_lvl(find(row,1)); end
        end
    end
end

%% Import shares pi(d,o,j,t): share of importer d sector j sourced from exporter o
pi_mat = nan(2, 2, J, Ty);
for d = 1:2
    for o = 1:2
        for j = 1:J
            for t = 1:Ty
                row = strcmp(bp.importer, cnames{d}) & strcmp(bp.exporter, cnames{o}) & ...
                      strcmp(bp.sector, secs{j}) & bp.year == years(t);
                if any(row), pi_mat(d,o,j,t) = bp.imp_sh(find(row,1)); end
            end
        end
    end
end

%% Decompose tau for each importer d (exporter o is the other country)
tau       = nan(2, J, Ty);   % tau(d,j,t): importer d buying sector j from the other country
price_cmp = nan(2, J, Ty);   % P_d / P_o
share_cmp = nan(2, J, Ty);   % (pi_oo / pi_do)^(1/theta)
for d = 1:2
    o = 3 - d;
    for j = 1:J
        for t = 1:Ty
            price_cmp(d,j,t) = P(d,j,t) / P(o,j,t);
            share_cmp(d,j,t) = (pi_mat(o,o,j,t) / pi_mat(d,o,j,t))^(1/theta);
            tau(d,j,t)       = price_cmp(d,j,t) * share_cmp(d,j,t);
        end
    end
end

%% Variance decomposition of log(tau): which component moves it?
fprintf('\n============================================================\n');
fprintf('Variance decomposition of log(tau), %d-%d\n', years(1), years(end));
fprintf('log tau = log(price ratio) + log(share term), so the two shares\n');
fprintf('below sum to 100%%. The larger one is what drives tau.\n');
fprintf('------------------------------------------------------------\n');
fprintf('%-4s %-9s %10s %8s %8s   %s\n', 'sec', 'importer', 'var(lnT)', '%price', '%share', 'verdict');
for j = 1:J
    for d = 1:2
        lt = log(squeeze(tau(d,j,:)));
        lp = log(squeeze(price_cmp(d,j,:)));
        ls = log(squeeze(share_cmp(d,j,:)));
        ok = isfinite(lt) & isfinite(lp) & isfinite(ls);
        vt = var(lt(ok));
        cp = cov(lt(ok), lp(ok)); cp = cp(1,2);
        cq = cov(lt(ok), ls(ok)); cq = cq(1,2);
        pctP = 100 * cp / vt;
        pctS = 100 * cq / vt;
        if pctS >= pctP, verdict = 'SHARE-driven (tradability / zero-flow)';
        else            verdict = 'PRICE-driven (go_lvl construction)';
        end
        fprintf('%-4s %-9s %10.3f %7.0f%% %7.0f%%   %s\n', secs{j}, cnames{d}, vt, pctP, pctS, verdict);
    end
end

%% Import-share health: near-zero levels, jumpiness, and the 2000-2001 seam
fprintf('\n============================================================\n');
fprintf('Import-share diagnostics (pi_do, importer d from the other country)\n');
fprintf('------------------------------------------------------------\n');
fprintf('%-4s %-9s %10s %12s %12s\n', 'sec', 'importer', 'min pi', 'max|dlnpi|', 'ln jump 00->01');
t2000 = find(years == 2000); t2001 = find(years == 2001);
for j = 1:J
    for d = 1:2
        o = 3 - d;
        pis = squeeze(pi_mat(d,o,j,:));
        dln = abs(diff(log(pis)));
        seam = log(pis(t2001)) - log(pis(t2000));
        fprintf('%-4s %-9s %10.2e %12.3f %12.3f\n', secs{j}, cnames{d}, min(pis), max(dln(isfinite(dln))), seam);
    end
end
fprintf('\n(min pi near 0 => share term explodes; large max|dlnpi| or a big\n');
fprintf(' 00->01 jump => spliced-share artifact feeding tau.)\n');

%% Plots: tau and its two components, normalized to 1965 = 1
% In logs the normalized lines add up, so you can read off which component
% carries tau's path by eye.
t70 = find(years == 1965);
figure('Name','tau decomposition','Color','w');
for j = 1:J
    for d = 1:2
        subplot(J, 2, (j-1)*2 + d); hold on; box on;
        norm_tau   = squeeze(tau(d,j,:))       / tau(d,j,t70);
        norm_price = squeeze(price_cmp(d,j,:)) / price_cmp(d,j,t70);
        norm_share = squeeze(share_cmp(d,j,:)) / share_cmp(d,j,t70);
        plot(years, norm_tau,   '-k', 'LineWidth', 1.8);
        plot(years, norm_price, '--', 'Color', [0.10 0.45 0.80], 'LineWidth', 1.3);
        plot(years, norm_share, ':',  'Color', [0.30 0.65 0.20], 'LineWidth', 1.6);
        xlim([1965 2014]);
        title(sprintf('%s: %s importing (from %s)', secs{j}, cnames{d}, cnames{3-d}));
        if j == 1 && d == 1
            legend({'\tau','price ratio P_d/P_o','share term (\pi_{oo}/\pi_{do})^{1/\theta}'}, ...
                   'Location','best','FontSize',7);
        end
        ylabel('index, 1965 = 1');
    end
end
sgtitle('Trade-cost decomposition: does \tau track the price ratio or the share term?');

% Save a copy next to the data if the folder is writable, otherwise just show
try
    figdir = strcat(datapath, 'diagnostics/');
    if ~isfolder(figdir), mkdir(figdir); end
    saveas(gcf, strcat(figdir, 'tau_decomposition.png'));
    fprintf('\nFigure saved to %stau_decomposition.png\n', figdir);
catch
    fprintf('\n(Could not save figure; it is open on screen.)\n');
end

%==============================================================================
% aggregator_test_paper.m
%
% Purpose: Verify the CES aggregator derivation against the paper on random draws.
%
% NOTE: diagnostic only, not part of the pipeline.
%==============================================================================

clear

datapath = '../../../data/processed/';

%% options
exponent   = 'paper';        %'paper' -> (eps^j - psi);  'updated' -> (1-psi)*eps^j
yr_lo      = 1970;           % paper's window; set 1965 to use the full panel
yr_hi      = 2007;           % paper's window; set 2014 to use the full panel
kappa_mode = 'fit';          %'fit' to match the paper's first-year ratios, or a 2x1 vector
resid_sec  = 3;              % sector taken as the residual (3 = services)

% Paper's Figure 2, first year of its sample, read off the plot. Used only as
% the fitting target for kappa; the levels themselves are not identified.
mu_paper_1970 = [0.470 1.900 0.850;    % USA: AGR MAN SER
                 0.260 0.460 0.220];   % ROW: AGR MAN SER

%% parameters
psi  = 0.57;                        %price elasticity of demand, Comin et al.
zeta = 1;                           %investment elasticity, homothetic
eps_clm = [0.02 1.0 1.17];          %Comin-Lashkari-Mestieri, Table III col 1
eps  = eps_clm / sum(eps_clm);      %model imposes sum_j eps^j = 1

%% load
cs = readtable(strcat(datapath, 'CountrySectorPanel_2country.csv'));
cp = readtable(strcat(datapath, 'CountryPanel_2country.csv'));
io = readtable(strcat(datapath, 'panel_D.csv'));

secs = {'AGR','MAN','SER'};
cnames = {'USA','ROW'};
years = yr_lo:yr_hi;
Ty = numel(years); J = 3; usa_code = 24;

GO = zeros(2,J,Ty); EXPD = zeros(2,J,Ty); XE = zeros(2,J,Ty); P = zeros(2,J,Ty);
for i = 1:2
    for j = 1:J
        for t = 1:Ty
            r = strcmp(cs.country,cnames{i}) & strcmp(cs.sector,secs{j}) & cs.year==years(t);
            GO(i,j,t)   = cs.go_wiot(r);
            EXPD(i,j,t) = cs.expend(r);
            XE(i,j,t)   = cs.invest(r);
            P(i,j,t)    = cs.go_lvl(r);
        end
    end
end

L = zeros(2,Ty); GDP = zeros(2,Ty); PX = zeros(2,Ty);
for i = 1:2
    for t = 1:Ty
        r = strcmp(cp.country,cnames{i}) & cp.year==years(t);
        L(i,t)   = cp.emp(r);
        GDP(i,t) = cp.gdp(r);
        PX(i,t)  = cp.invest_pi(r);
    end
end

% intermediate flows, chain-linked at 2000 as elsewhere in the pipeline
yrs_all = 1965:2014; Ta = numel(yrs_all);
IOF = zeros(2,J,J,Ta); IO_R = zeros(2,J,J,Ta);
for j = 1:J
    for m = 1:J
        for t = 1:Ta
            rows = io.sector==j & io.source_sector==m & io.year==yrs_all(t);
            lr = rows & io.source==0;  r16 = rows & io.source==1;
            IOF(1,j,m,t)  = sum(io.io_flow(lr  & io.country==usa_code));
            IOF(2,j,m,t)  = sum(io.io_flow(lr  & io.country~=usa_code));
            IO_R(1,j,m,t) = sum(io.io_flow(r16 & io.country==usa_code));
            IO_R(2,j,m,t) = sum(io.io_flow(r16 & io.country~=usa_code));
        end
    end
end
t00 = find(yrs_all==2000);
for t = t00+1:Ta
    IOF(:,:,:,t) = IOF(:,:,:,t-1) .* (IO_R(:,:,:,t) ./ IO_R(:,:,:,t-1));
end
IOF = IOF(:,:,:, ismember(yrs_all, years));      % trim to the sample window

%% time-invariant investment shares, and aggregates
ups = mean(XE ./ sum(XE,2), 3, 'omitnan');
PXX = squeeze(sum(XE,2));                        % P^X X, observed
NX  = squeeze(sum(GO,2)) - squeeze(sum(EXPD,2));
EC  = GDP - PXX - NX;                            % budget constraint, paper eq 8

%% exponent on real consumption per worker
switch exponent
    case 'paper',   ex = eps - psi;              % paper's aggregator
    case 'updated', ex = (1-psi) * eps;          % math appendix aggregator
    otherwise, error('exponent must be paper or updated')
end
fprintf('exponent on C/L: [%+.3f %+.3f %+.3f], spread %.3f\n', ex, max(ex)-min(ex));

%% N^j: sectoral consumption expenditure
% Tradables come from goods market clearing; the residual sector comes from the
% shares adding to one, which is the paper's route for its nontradable sector.
Amat = zeros(2,J,Ty);
trad = setdiff(1:J, resid_sec);
for i = 1:2
    for t = 1:Ty
        Pv = reshape(P(i,:,t), 1, J);
        N  = zeros(1,J);
        for j = trad
            N(j) = EXPD(i,j,t) - sum(IOF(i,:,j,t)) ...
                   - ups(i,j) * (Pv(j)/PX(i,t))^(1-zeta) * PXX(i,t);
        end
        N(resid_sec) = EC(i,t) - sum(N(trad));
        assert(all(N > 0), 'consumption expenditure not positive, %s %d', cnames{i}, years(t))
        Amat(i,:,t) = N ./ (L(i,t) * Pv.^(1-psi) * (EC(i,t)/L(i,t))^psi);
    end
end

%% mu, given kappa
    function m = mu_at(a, ex, kap)
        g  = @(x) log(sum(a .* exp(-ex*x))) - log(kap);
        xg = linspace(-400, 400, 8001);
        vg = arrayfun(g, xg);
        ok = isfinite(vg); xg = xg(ok); vg = vg(ok);
        k  = find(sign(vg(1:end-1)) ~= sign(vg(2:end)), 1);
        if isempty(k), m = nan(size(a)); return, end
        m = a .* exp(fzero(g, [xg(k) xg(k+1)])).^(-ex);
    end

%% kappa
% Fitted so the first-year mu RATIOS match the paper's Figure 2. kappa changes
% the ratios (see header), so this is what makes the trends comparable.
if isnumeric(kappa_mode)
    kappa = kappa_mode(:);
else
    kappa = zeros(2,1);
    for i = 1:2
        a      = reshape(Amat(i,:,1), 1, J);
        target = log(mu_paper_1970(i,:) / mu_paper_1970(i,1));
        obj    = @(lk) fitloss(a, ex, exp(lk), target);
        lk     = fminbnd(obj, log(sum(a))-6, log(sum(a))+6);
        kappa(i) = exp(lk);
        m = mu_at(a, ex, kappa(i));
        fprintf('kappa_%s = %8.3f fitted | ratios %5.2f : %5.2f : %5.2f  (paper %5.2f : %5.2f : %5.2f)\n', ...
            cnames{i}, kappa(i), m/m(1), mu_paper_1970(i,:)/mu_paper_1970(i,1));
    end
end

mu = zeros(2,J,Ty);
for i = 1:2
    for t = 1:Ty
        mu(i,:,t) = mu_at(reshape(Amat(i,:,t),1,J), ex, kappa(i));
    end
end
assert(all(mu(:) > 0), 'mu is not strictly positive')

%% report
fprintf('\n%-4s %-4s %9s %9s %8s\n', 'ctry','sec', num2str(yr_lo), num2str(yr_hi), 'ratio');
for i = 1:2
    for j = 1:J
        v = squeeze(mu(i,j,:));
        fprintf('%-4s %-4s %9.3f %9.3f %8.2f\n', cnames{i}, secs{j}, v(1), v(end), v(end)/v(1));
    end
    fprintf('%-4s %-4s %9.3f %9.3f\n', cnames{i}, 'sum', sum(mu(i,:,1)), sum(mu(i,:,end)));
end
fprintf('\nPaper Figure 2, USA, read off the plot: AGR 0.47->0.02, MAN 1.90->1.05, SER 0.85->2.15\n');
fprintf('Paper Figure 2, ROW, read off the plot: AGR 0.26->0.16, MAN 0.46->0.42, SER 0.22->0.38\n');

%% figure, laid out like the paper's Figure 2
figure('Color','w','Position',[100 100 900 400]);
sty = {':', '-', '--'};
col = {[0.10 0.45 0.35], [0.00 0.00 0.70], [0.80 0.10 0.10]};
lw  = [1.8 1.8 1.8];
for i = 1:2
    subplot(1,2,i); hold on; box on;
    for j = 1:J
        plot(years, squeeze(mu(i,j,:)), sty{j}, 'Color', col{j}, 'LineWidth', lw(j));
    end
    xlim([yr_lo yr_hi]); xlabel('Year');
    if i==1
        title('United States: $\mu^j_{US,t}$','Interpreter','latex');
        legend(secs, 'Location','best', 'Box','off');
    else
        title('Rest of the World: $\mu^j_{ROW,t}$','Interpreter','latex');
    end
end
sgtitle(sprintf('Evolution of Sectoral Demand Shifters (%s exponent)', exponent));

%% note
% Set exponent = 'updated' and rerun to see the same data under the math
% appendix aggregator. Only the exponent changes; N^j and kappa are identical.
% The paper's exponents span 0.525 and the updated ones span 0.226, a factor of
% (1-psi), and the trends compress in the same proportion. That spread, not the
% level of eps, is what drives how far the series move apart over time; a pure
% rescaling of eps is absorbed by kappa and changes nothing.

%% helper
function L = fitloss(a, ex, kap, target)
    g  = @(x) log(sum(a .* exp(-ex*x))) - log(kap);
    xg = linspace(-400, 400, 8001);
    vg = arrayfun(g, xg);
    ok = isfinite(vg); xg = xg(ok); vg = vg(ok);
    k  = find(sign(vg(1:end-1)) ~= sign(vg(2:end)), 1);
    if isempty(k), L = 1e6; return, end
    m = a .* exp(fzero(g, [xg(k) xg(k+1)])).^(-ex);
    L = sum((log(m/m(1)) - target).^2);
end

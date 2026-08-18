% recover model parameters
clear
datapath = '../../../data/processed/';
cwpath   = '../../../data/crosswalks/';
rawpath  = '../../../data/raw/';

% calibrated parameters
theta = 2;
psi   = 0.57;

% normalize income elasticities to sum to 1
eps_norm = 'sum1';
eps_clm  = [0.02 1.0 1.17];
switch eps_norm
    case 'sum1', eps = eps_clm / sum(eps_clm);   
    case 'clm',  eps = eps_clm;
    otherwise,   error('eps_norm must be sum1 or clm')
end

zeta  = 1;                          % investment elasticity, Atalay (2015)
eta   = 2;
delta = 0.95;
d     = 0.05;
Gam   = gamma((theta+1-eta)/theta)^(1/(1-eta));   % EK constant

% capital stock anchor. The law of motion is iterated forward from the PWT
% stock in this year (eq:kpath). The appendix anchors at 1970, matching the
% paper's sample start; at 1965 the sample's first year is the anchor and no
% backward step is needed. Anchoring later moves the whole capital level,
% hence the rental rate, unit costs, productivities and trade costs.
k_anchor_year = 1965;

% net foreign asset position of the US in the first year, in USD millions,
% and the friction's baseline position. Bonds are in zero net supply, so ROW
% takes the mirror image of both (eq:bmirror).
% NOTE: the wedge is algebraically invariant to both; only phi's level moves.
B1965_USA = 0;
Bbar_USA  = 0;

% compute VA-weighted capital share (phi)
phi_measure = 'alpha_w';
cf  = readtable(strcat(cwpath, 'capital_shares_cf2007.csv'));
cwk = readtable(strcat(cwpath, 'country_num_crosswalk.csv'));

cf_ctry  = string(cf.country);
cwk_ctry = string(cwk.country);
cf_phi   = cf.(phi_measure);

pb_w = readtable(strcat(datapath, 'panel_B.csv'));
pb_w = pb_w(~(pb_w.year == 2000 & pb_w.source == 1), :);

nC     = height(cwk);
va_i   = zeros(nC,1);
phi_i  = nan(nC,1);

for k = 1:nC
    rows    = pb_w.country == cwk.country_numcode(k);
    va_i(k) = sum(pb_w.va(rows)) / numel(unique(pb_w.year(rows)));
    
    hit     = find(cf_ctry == cwk_ctry(k), 1);
    if ~isempty(hit), phi_i(k) = cf_phi(hit); end
end

is_row = cwk_ctry ~= "USA";
use    = is_row & ~isnan(phi_i);

phi    = zeros(2,1);
phi(1) = cf_phi(cf_ctry == "USA");
phi(2) = sum(phi_i(use) .* va_i(use)) / sum(va_i(use));

% coverage diagnostics
cover = 100 * sum(va_i(use)) / sum(va_i(is_row));
fprintf('phi from Caselli-Feyrer %s: USA %.3f, ROW %.3f (ROW covers %.0f%% of non-US value added)\n', ...
        phi_measure, phi(1), phi(2), cover);
if cover < 75
    fprintf('  missing:');
    for k = find(is_row & isnan(phi_i))'
        fprintf(' %s(%.0f%%)', cwk_ctry(k), 100*va_i(k)/sum(va_i(is_row)));
    end
    fprintf('\n');
end

% load data panels
cs = readtable(strcat(datapath, 'CountrySectorPanel_2country.csv'));
cp = readtable(strcat(datapath, 'CountryPanel_2country.csv'));
bp = readtable(strcat(datapath, 'ImpExpSectorPanel_2country.csv'));
io = readtable(strcat(datapath, 'panel_D.csv'));

usa_code = 24;
years = 1965:2014;
Ty = numel(years);
secs = {'AGR','MAN','SER'};
J = 3;
cnames = {'USA','ROW'};

% extract nominal sectoral variables
GO   = zeros(2,J,Ty);
VA   = zeros(2,J,Ty);
EXPD = zeros(2,J,Ty);
CE   = zeros(2,J,Ty);
XE   = zeros(2,J,Ty);
P    = zeros(2,J,Ty);
NXS  = zeros(2,J,Ty);

for i = 1:2
    for j = 1:J
        for t = 1:Ty
            row = strcmp(cs.country, cnames{i}) & strcmp(cs.sector, secs{j}) & cs.year == years(t);
            GO(i,j,t)   = cs.go_wiot(row);
            VA(i,j,t)   = cs.va_wiot(row);
            EXPD(i,j,t) = cs.expend(row);
            CE(i,j,t)   = cs.consump(row);
            XE(i,j,t)   = cs.invest(row);
            P(i,j,t)    = cs.go_lvl(row);
            NXS(i,j,t)  = cs.nx(row);
        end
    end
end

% extract country-level aggregates
GDP    = zeros(2,Ty);
L      = zeros(2,Ty);
K      = zeros(2,Ty);
PC     = zeros(2,Ty);
PX_pwt = zeros(2,Ty);

for i = 1:2
    for t = 1:Ty
        row = strcmp(cp.country, cnames{i}) & cp.year == years(t);
        GDP(i,t)    = cp.gdp(row);
        L(i,t)      = cp.emp(row);
        K(i,t)      = cp.k_stock(row);
        PC(i,t)     = cp.consump_pi(row);
        PX_pwt(i,t) = cp.invest_pi(row);
    end
end

% read the world interest rate: the gross yield on the 10-year US Treasury
% note, R_t = 1 + i_t/100 (FRED DGS10, annual averages). Bonds are in zero
% net supply, so both countries face the same R_t, which is why neither
% country's friction has to be normalized below.
dgs   = readtable(strcat(rawpath, 'DGS10.csv'));
dgs_d = dgs.observation_date;
if ~isdatetime(dgs_d)
    dgs_d = datetime(string(dgs_d), 'InputFormat', 'yyyy-MM-dd');
end
dgs_y = year(dgs_d);

R_obs = nan(1,Ty);
for t = 1:Ty
    hit = find(dgs_y == years(t), 1);
    assert(~isempty(hit), 'DGS10.csv has no observation for %d', years(t))
    R_obs(t) = 1 + dgs.DGS10(hit)/100;
end
assert(all(R_obs > 1), 'the Treasury yield is not strictly positive in every year')

% extract bilateral import shares
pi_mat = zeros(2,2,J,Ty);
for im = 1:2
    for ex = 1:2
        for j = 1:J
            for t = 1:Ty
                row = strcmp(bp.importer, cnames{im}) & strcmp(bp.exporter, cnames{ex}) & ...
                      strcmp(bp.sector, secs{j}) & bp.year == years(t);
                pi_mat(im,ex,j,t) = bp.imp_sh(row);
            end
        end
    end
end

% splice IO flows (LR to R16)
IOF  = zeros(2,J,J,Ty);
IO_R = zeros(2,J,J,Ty);

for j = 1:J
    for m = 1:J
        for t = 1:Ty
            rows = io.sector == j & io.source_sector == m & io.year == years(t);
            lr   = rows & io.source == 0;
            r16  = rows & io.source == 1;
            
            IOF(1,j,m,t)  = sum(io.io_flow(lr  & io.country == usa_code));
            IOF(2,j,m,t)  = sum(io.io_flow(lr  & io.country ~= usa_code));
            IO_R(1,j,m,t) = sum(io.io_flow(r16 & io.country == usa_code));
            IO_R(2,j,m,t) = sum(io.io_flow(r16 & io.country ~= usa_code));
        end
    end
end

t00 = find(years == 2000);
for t = t00+1:Ty
    IOF(:,:,:,t) = IOF(:,:,:,t-1) .* (IO_R(:,:,:,t) ./ IO_R(:,:,:,t-1));
end

% validate IO column identity
fprintf('Column identity, sum_m D^{j,m} vs GO^j - VA^j (max rel dev):\n');
for i = 1:2
    for j = 1:J
        buy = squeeze(sum(IOF(i,j,:,:),3));
        tgt = squeeze(GO(i,j,:) - VA(i,j,:));
        dev = abs(buy ./ tgt - 1);
        fprintf('  %-3s %-3s  pre-2000 max %.3f   post-2000 max %.3f\n', ...
                cnames{i}, secs{j}, max(dev(1:t00)), max(dev(t00+1:end)));
    end
end

% compute shares
beta  = mean(VA ./ GO, 3, 'omitnan');
x_obs = XE ./ sum(XE,2);              % observed investment shares, x^j
ups   = mean(x_obs, 3, 'omitnan');    % their time average, the paper's constant

nu_shares = mean(IOF ./ sum(IOF,3), 4, 'omitnan');
nu = cell(2,1);
for i = 1:2
    nu{i} = squeeze(nu_shares(i,:,:));
end

% recover the investment demand shifters and the investment price index
% (eq:mux and eq:PXrecover)
%
% Investment is homothetic CES, so the observed share x^j = P^jX^j/E^X
% inverts the share equation directly: mu^{x,j} = x^j (P^j/P^X)^(zeta-1).
% P^X is not in the data, but imposing sum_j mu^{x,j} = 1 gives it in closed
% form. At zeta = 1 both collapse to their Cobb-Douglas limits, mu^x = x^j
% and P^X = prod_j (P^j)^(x^j), which is the index the model's yearmodel.m
% already uses, now with observed rather than time-averaged weights.
%
% The panel's investment column is gross fixed capital formation plus changes
% in inventories, so a handful of cells are negative, almost all agriculture
% running its inventories down. The aggregator needs mu^x > 0, so those shares
% are floored and the rest renormalized. The floor is two orders of magnitude
% below the smallest positive agricultural share; the diagnostics below say how
% many cells it binds on and how much expenditure it moves.
x_floor = 1e-5;
x_adj   = max(x_obs, x_floor);
x_adj   = x_adj ./ sum(x_adj, 2);
nfloor  = squeeze(sum(x_obs < x_floor, 3));

mux = zeros(2,J,Ty);
PX  = zeros(2,Ty);

for i = 1:2
    for t = 1:Ty
        Pv = reshape(P(i,:,t), 1, J);
        xv = reshape(x_adj(i,:,t), 1, J);
        if abs(zeta - 1) < 1e-10
            PX(i,t)    = prod(Pv .^ xv);
            mux(i,:,t) = xv;
        else
            PX(i,t)    = sum(xv .* Pv.^(zeta-1))^(1/(zeta-1));
            mux(i,:,t) = xv .* (Pv / PX(i,t)).^(zeta-1);
        end
    end
end

assert(all(mux(:) > 0), 'recovered mu^x is not strictly positive')
assert(max(abs(squeeze(sum(mux,2)) - 1), [], 'all') < 1e-10, ...
       'normalization sum_j mu^x = 1 failed')

% The investment term in the mu inversion below is now sectoral investment
% expenditure itself, since mu^{x,j}(P^j/P^X)^(1-zeta) = x^j by construction.
% Checked here rather than assumed; the gap against the observed column is the
% floor, nothing else.
PXX    = squeeze(sum(XE,2));          % investment expenditure, E^X
XE_mod = mux .* (P ./ reshape(PX,2,1,Ty)).^(1-zeta) .* reshape(PXX,2,1,Ty);
assert(max(abs(XE_mod ./ (x_adj .* reshape(PXX,2,1,Ty)) - 1), [], 'all') < 1e-10, ...
       'the recovered investment shifters do not reproduce investment expenditure')

fprintf('\nInvestment block (zeta = %.2f):\n', zeta);
for i = 1:2
    for j = 1:J
        if nfloor(i,j) > 0
            fprintf(['  %-3s %-3s  share floored at %.0e in %2d of %d years, ' ...
                     'max share moved %.4f\n'], cnames{i}, secs{j}, x_floor, ...
                    nfloor(i,j), Ty, max(abs(x_adj(i,j,:) - x_obs(i,j,:))));
        end
    end
end
fprintf('  investment expenditure vs the observed column: max gap %.2e of E^X\n', ...
        max(abs(XE_mod - XE) ./ reshape(PXX,2,1,Ty), [], 'all'));
for i = 1:2
    ratio = PX(i,:) ./ PX_pwt(i,:);
    fprintf(['  %-3s  recovered P^X vs PWT investment price: corr(logs) %+.3f' ...
             '   ratio range [%.3f %.3f]\n'], cnames{i}, ...
            corr(log(PX(i,:))', log(PX_pwt(i,:))'), ...
            min(ratio)/mean(ratio), max(ratio)/mean(ratio));
    fprintf('  %-3s  mu^x range by sector:', cnames{i});
    for j = 1:J
        fprintf('  %s [%.3f %.3f]', secs{j}, min(mux(i,j,:)), max(mux(i,j,:)));
    end
    fprintf('\n');
end

% build the capital stock from the law of motion, anchored at k_anchor_year
% (eq:kpath)
%
% The model has a law of motion as well as a capital Euler, and both have to hold
% on the same stock, so K is accumulated rather than read from PWT every year.
% Only one year of the PWT stock is used. Forward, an error in the anchor decays
% at (1-d)^t; the backward step needed for years before the anchor amplifies it
% by 1/(1-d) a year, which is why the anchor defaults to the first year.
%
% Real investment is now E^X over the RECOVERED P^X, not the PWT price level.
Xq   = PXX ./ PX;                     % investment quantity, X = E^X/P^X

% The two price indices have different bases, so PWT's real stock has to be
% revalued before it can anchor a series accumulated from this real flow:
% nominal it at the PWT investment price, then deflate by the model's own
% index. Skipping this understates capital by a third and inflates the rental
% rate by the same factor, which does not cancel in the capital Euler.
Kdat = K .* PX_pwt ./ PX;

ta = find(years == k_anchor_year);
assert(~isempty(ta), 'k_anchor_year = %d is outside the sample', k_anchor_year)

Klom = zeros(2,Ty);
Klom(:,ta) = Kdat(:,ta);
for t = ta:Ty-1
    Klom(:,t+1) = (1-d) * Klom(:,t) + Xq(:,t);
end
for t = ta-1:-1:1
    Klom(:,t) = (Klom(:,t+1) - Xq(:,t)) / (1-d);
end
assert(all(Klom(:) > 0), 'the accumulated capital stock went non-positive')

% factor prices from the firm's FOCs (eq:rental and its labour counterpart).
% One rental rate for the whole file: unit costs, the budget constraint and the
% capital Euler all see this r, and all see the accumulated stock.
%
% Value added is the panel's, not the model's sum_j beta^j Y^j reconstruction.
% The constant shares miss measured value added by up to 5 per cent (US) and
% 12 per cent (ROW), and putting that error into household income degrades the
% over-identifying check sum_j N^j/E^C - 1 from about 1 per cent to 6 (US) and
% 15 (ROW). Verified both ways.
w = (1 - phi) .* GDP ./ L;
r = phi .* GDP ./ Klom;

% the model's own value added, for the diagnostic below
VAm = zeros(2,Ty);
for i = 1:2
    VAm(i,:) = sum(beta(i,:)' .* squeeze(GO(i,:,:)), 1);
end

% Drift against the PWT stock. d = 0.05 is the paper's parameter; the
% depreciation PWT's own stock and measured investment jointly imply is nearer
% 0.04 (US) and 0.01 (ROW), so the accumulated series drifts below PWT. Reported
% rather than fixed: calibrating d per country would absorb splice and coverage
% error into a technology parameter.
fprintf('\nCapital block:\n');
for i = 1:2
    gK   = Klom(i,:) ./ Kdat(i,:) - 1;
    dimp = 1 - (Kdat(i,2:end) - Xq(i,1:end-1)) ./ Kdat(i,1:end-1);
    fprintf('  %-3s  K vs the revalued PWT stock: 1990 %+.0f%%, 2014 %+.0f%%   implied d mean %.3f\n', ...
            cnames{i}, 100*gK(years == 1990), 100*gK(end), mean(dimp));
    fprintf('  %-3s  VA at constant shares vs panel GDP: max gap %.1f%%\n', ...
            cnames{i}, 100*max(abs(VAm(i,:) ./ GDP(i,:) - 1)));
end

% trade accounting checks
NX = squeeze(sum(GO,2)) - squeeze(sum(EXPD,2));
NX_panel  = squeeze(sum(NXS,2));
GO_tot    = squeeze(sum(GO,2));

gap_cons  = max(abs(NX(:) - NX_panel(:))) / max(abs(NX(:)));
gap_world = max(abs(sum(NX,1))) / max(sum(GO_tot,1));

if gap_cons > 1e-6
    error(['recover_parameters: the panel''s nx column disagrees with gross ' ...
           'output minus total expenditure by %.2e (relative). The trade ' ...
           'quantities are no longer totals of one spliced matrix.'], gap_cons);
end
if gap_world > 1e-9
    error(['recover_parameters: world net exports are %.2e of world gross ' ...
           'output, not zero. In a two-country world one country''s surplus ' ...
           'is the other''s deficit identically, so there is no equilibrium ' ...
           'to solve for.'], gap_world);
end
fprintf(['Trade accounting: nx vs GO-E %.1e, world sum %.1e of gross output ' ...
         '(both must be ~0).\n'], gap_cons, gap_world);

% consumption expenditure residual
EC      = w .* L + r .* Klom - PXX - NX;   % = GDP - E^X - NX
EC_wiot = squeeze(sum(CE,2));

% anchor CES aggregator constant (kappa) to PWT
mu       = zeros(2,J,Ty);
s_share  = zeros(2,J,Ty);
Cbar     = zeros(2,Ty);
PC_model = zeros(2,Ty);
addup    = zeros(2,Ty);

kappa_source = 'pwt_anchor';
if isnumeric(kappa_source)
    kappa = kappa_source(:);
else
    kappa = zeros(2,1);
    for i = 1:2
        ktmp = zeros(1,Ty);
        for t = 1:Ty
            Pv = reshape(P(i,:,t), 1, J);
            Nv = zeros(1,J);
            for j = 1:J
                Nv(j) = EXPD(i,j,t) - sum(IOF(i,:,j,t)) ...
                        - mux(i,j,t) * (Pv(j)/PX(i,t))^(1-zeta) * PXX(i,t);
            end
            cb = (EC(i,t)/PC(i,t)) / L(i,t);
            ktmp(t) = sum( Nv ./ (L(i,t) * Pv.^(1-psi) * (EC(i,t)/L(i,t))^psi) ...
                          .* cb.^(-(1-psi)*eps) );
        end
        kappa(i) = mean(ktmp);
        fprintf('kappa_%s = %.4f (PWT-anchored mean; sample range %.4f to %.4f)\n', ...
                cnames{i}, kappa(i), min(ktmp), max(ktmp));
    end
end

for i = 1:2
    for t = 1:Ty
        Pv = reshape(P(i,:,t), 1, J);
        
        % compute sectoral demand numerators (Y - NX - intermediate - investment).
        % The investment term uses the recovered mu^x, so it equals observed
        % sectoral investment expenditure and no longer leaves a gap for mu to
        % absorb. Agriculture bore that gap before, its consumption share being
        % under one percent.
        N = zeros(1,J);
        for j = 1:J
            Dj   = sum(IOF(i,:,j,t));
            Xj   = mux(i,j,t) * (Pv(j)/PX(i,t))^(1-zeta) * PXX(i,t);
            N(j) = EXPD(i,j,t) - Dj - Xj;
        end
        
        assert(all(N > 0), 'numerator of eq:mu-tradables is not positive for %s %d', ...
               cnames{i}, years(t))
        addup(i,t) = sum(N) / EC(i,t) - 1;
        
        % root-finding for real per-capita consumption (C/L) from implicit CES aggregator
        A = N ./ (L(i,t) * Pv.^(1-psi) * (EC(i,t)/L(i,t))^psi);
        g = @(x) log(sum(A .* exp(-(1-psi)*eps*x))) - log(kappa(i));
        
        xlo = -20; xhi = 20;
        while g(xlo) < 0 && xlo > -700, xlo = xlo - 20; end
        while g(xhi) > 0 && xhi <  700, xhi = xhi + 20; end
        
        assert(g(xlo) > 0 && g(xhi) < 0, ...
               ['eq:kappa has no solution in a sensible range for %s %d: ' ...
                'kappa_%s = %.4f is outside what the data can deliver'], ...
               cnames{i}, years(t), cnames{i}, kappa(i))
               
        Cbar(i,t) = exp(fzero(g, [xlo xhi]));
        
        % recover demand shifters (mu) matching eq:mu-tradables
        mu(i,:,t)      = A .* Cbar(i,t).^(-(1-psi)*eps);
        
        % compute implied consumption expenditure shares (s^j)
        s_share(i,:,t) = N / EC(i,t);
        PC_model(i,t)  = (EC(i,t)/L(i,t)) / Cbar(i,t);
    end
end

% validate mu positivity and normalization
assert(all(mu(:) > 0), 'recovered mu is not strictly positive')
assert(max(abs(squeeze(sum(mu,2))./kappa - 1), [], 'all') < 1e-8, ...
       'normalization sum_j mu = kappa failed')

fprintf('\nDemand shifter recovery diagnostics:\n');
fprintf('  over-identifying check, sum_j N^j / E^C - 1:\n');
for i = 1:2
    a = addup(i,:);
    fprintf('    %-3s  pre-2000 max %.2e   post-2000 max %.2e\n', ...
            cnames{i}, max(abs(a(1:t00))), max(abs(a(t00+1:end))));
end

fprintf('  budget-constraint E^C vs WIOT consumption column:\n');
for i = 1:2
    gap = EC(i,:) ./ EC_wiot(i,:) - 1;
    fprintf('    %-3s  pre-2000 max %.2e   post-2000 max %.2e\n', ...
            cnames{i}, max(abs(gap(1:t00))), max(abs(gap(t00+1:end))));
end

fprintf('  model-implied P^C vs PWT consumption price level (validation):\n');
for i = 1:2
    ratio = PC_model(i,:) ./ PC(i,:);
    fprintf('    %-3s  corr(logs) %+.3f   ratio range [%.3f %.3f]\n', ...
            cnames{i}, corr(log(PC_model(i,:))', log(PC(i,:))'), ...
            min(ratio)/mean(ratio), max(ratio)/mean(ratio));
end

% compute unit cost constants (varkappa)
varkappa = zeros(2,J);
for i = 1:2
    for j = 1:J
        b  = beta(i,j);
        f  = phi(i);
        nv = nu{i}(j,:);
        varkappa(i,j) = (b * f^f * (1-f)^(1-f))^(-b) * ...
                        ((1-b) * prod(nv.^nv))^(-(1-b));
    end
end

% compute unit costs (c) wrapping factor prices and intermediate prices
c = zeros(2,J,Ty);
for i = 1:2
    for j = 1:J
        for t = 1:Ty
            Pvec = squeeze(P(i,:,t));
            c(i,j,t) = varkappa(i,j) * (r(i,t)^phi(i) * w(i,t)^(1-phi(i)))^beta(i,j) * ...
                       prod(Pvec .^ nu{i}(j,:))^(1-beta(i,j));
        end
    end
end

% recover bilateral trade costs (tau) and home productivities (T)
tau   = ones(2,2,J,Ty);
Tprod = zeros(2,J,Ty);
for j = 1:J
    for t = 1:Ty
        for im = 1:2
            for ex = 1:2
                if im ~= ex
                    % tau from gravity ratio (relative prices and trade shares)
                    tau(im,ex,j,t) = (P(im,j,t)/P(ex,j,t)) * ...
                                     (pi_mat(ex,ex,j,t)/pi_mat(im,ex,j,t))^(1/theta);
                end
            end
        end
        for i = 1:2
            % T from inverting home trade share equation
            Tprod(i,j,t) = pi_mat(i,i,j,t) * (Gam * c(i,j,t) / P(i,j,t))^theta;
        end
    end
end

% compute Head-Ries symmetric trade friction (htau)
htau = zeros(J,Ty);
for j = 1:J
    for t = 1:Ty
        htau(j,t) = (pi_mat(1,1,j,t) * pi_mat(2,2,j,t) / ...
                     (pi_mat(1,2,j,t) * pi_mat(2,1,j,t)))^(1/(2*theta));
    end
end

% compute structural wedge (phitilde) from consumption shares
varpi = s_share;
phitilde = zeros(2,Ty);
for i = 1:2
    for t = 1:Ty
        phitilde(i,t) = sum(eps .* varpi(i,:,t))^(-1);
    end
end

% roll the bond position forward from the balance of payments (eq:bop). The
% stock carried into t earns R_t, not R_{t+1}, since the bond FOC prices bonds
% bought at t. Zero net supply makes ROW the mirror image (eq:bmirror), which
% holds here because world net exports are zero to machine precision.
B      = zeros(2,Ty);
B(:,1) = [B1965_USA; -B1965_USA];
Bbar   = [Bbar_USA; -Bbar_USA];

for t = 1:Ty-1
    B(:,t+1) = R_obs(t) * B(:,t) + NX(:,t);
end
assert(max(abs(B(1,:) + B(2,:))) / max(abs(B(1,:))) < 1e-9, ...
       'the two bond positions are not mirror images, so bonds are not in zero net supply')

% recover the friction for each country separately (eq:phi-recover). With
% R_{t+1} observed both Euler equations are free, so nothing is normalized:
% the US friction is now recovered rather than set to zero.
%
% NOTE: phi is undefined where B_{t+1} = Bbar, so do not set Bbar to a value
% the series attains.
phi_f = nan(2,Ty-1);
wedge = nan(2,Ty-1);

for t = 1:Ty-1
    for i = 1:2
        % the Euler residual: what the wedge has to be to close the equation
        resid = (EC(i,t)/L(i,t)) / (EC(i,t+1)/L(i,t+1)) * ...
                phitilde(i,t+1)/phitilde(i,t) * delta * R_obs(t+1);
        gap   = B(i,t+1) - Bbar(i);

        phi_f(i,t) = (resid - 1) / gap;
        wedge(i,t) = 1 + phi_f(i,t) * gap;
    end
end

bscale = max(abs(B - Bbar), [], 'all');
if min(abs(B(:,2:Ty) - Bbar), [], 'all') < 1e-6 * bscale
    warning(['recover_parameters: the bond position comes within 1e-6 of Bbar, ' ...
             'so phi is near-singular there. The wedge is still well behaved.'])
end

% the rate the US Euler equation would need at zero friction, which is how R
% used to be identified. Now an over-identifying check against the Treasury yield.
R_euler = nan(2,Ty-1);
for i = 1:2
    for t = 1:Ty-1
        R_euler(i,t) = ((EC(i,t+1)/L(i,t+1)) / (EC(i,t)/L(i,t))) / delta * ...
                       phitilde(i,t)/phitilde(i,t+1);
    end
end

fprintf('\nFinancial friction:\n');
fprintf('  observed R (10-year Treasury): mean %.4f, range [%.4f %.4f]\n', ...
        mean(R_obs), min(R_obs), max(R_obs));
for i = 1:2
    fprintf(['  %-3s  wedge range [%.4f %.4f]   frictionless Euler R mean %.4f ' ...
             '(observed %.4f)\n'], cnames{i}, min(wedge(i,:)), max(wedge(i,:)), ...
            mean(R_euler(i,:)), mean(R_obs(2:Ty)));
end

% recover the investment tax from the capital Euler equation (eq:xi-recover).
% Only the growth of chi is identified, so chi is one in the first year and
% chained forward.
%
% NOTE: R cancels here. The wedge already contains delta*R_{t+1}, so chi is
% invariant to the interest rate series and only the expenditure growth,
% rental rate and investment price move it.
chi_ratio = nan(2,Ty-1);
for i = 1:2
    for t = 1:Ty-1
        chi_ratio(i,t) = (R_obs(t+1) / wedge(i,t)) * PX(i,t) / ...
                         ( r(i,t+1) + (1-d) * PX(i,t+1) );
    end
end

chi = ones(2,Ty);
for t = 1:Ty-1
    chi(:,t+1) = chi(:,t) .* chi_ratio(:,t);
end

% steady state: the ratio at one gives the required rent, hence the terminal
% capital stock the forward solve needs (eq:kss)
r_ss = PX(:,Ty) * (1/delta - (1-d));
K_ss = phi .* GDP(:,Ty) ./ r_ss;

fprintf('\nInvestment tax:\n');
for i = 1:2
    fprintf('  %-3s  chi_t+1/chi_t mean %.4f range [%.4f %.4f], level %d %.3f\n', ...
            cnames{i}, mean(chi_ratio(i,:)), min(chi_ratio(i,:)), max(chi_ratio(i,:)), ...
            years(Ty), chi(i,Ty));
    fprintf('  %-3s  K_ss / K_%d %.3f\n', cnames{i}, years(Ty), K_ss(i) / Klom(i,Ty));
end

% export time-varying parameters
n = 2*J*Ty;
country = cell(n,1);
yr      = zeros(n,1);
sec     = cell(n,1);
mu_v    = zeros(n,1);
c_v     = zeros(n,1);
T_v     = zeros(n,1);
tau_v   = zeros(n,1);
dex = 0;

for i = 1:2
    for j = 1:J
        for t = 1:Ty
            dex = dex + 1;
            country{dex} = cnames{i};
            yr(dex)      = years(t);
            sec{dex}     = secs{j};
            mu_v(dex)    = mu(i,j,t);
            c_v(dex)     = c(i,j,t);
            T_v(dex)     = Tprod(i,j,t);
            tau_v(dex)   = tau(i,3-i,j,t);
        end
    end
end

s_v = zeros(n,1);
htau_v = zeros(n,1);
dex = 0;

for i = 1:2
    for j = 1:J
        for t = 1:Ty
            dex = dex + 1;
            s_v(dex)   = s_share(i,j,t);
            htau_v(dex) = htau(j,t);
        end
    end
end

out = table(country, yr, sec, mu_v, c_v, T_v, tau_v, htau_v, s_v, ...
    'VariableNames', {'country','year','sector','mu','unit_cost','T', ...
                      'tau','htau','cons_share'});
writetable(out, strcat(datapath, 'recovered_parameters.csv'))

% export constant parameters
n2 = 2*J;
country2 = cell(n2,1);
sec2     = cell(n2,1);
beta_v   = zeros(n2,1);
ups_v    = zeros(n2,1);
kappa_v  = zeros(n2,1);
kagg_v   = zeros(n2,1);
phi_v    = zeros(n2,1);
dex = 0;

for i = 1:2
    for j = 1:J
        dex = dex + 1;
        country2{dex} = cnames{i};
        sec2{dex}     = secs{j};
        beta_v(dex)   = beta(i,j);
        ups_v(dex)    = ups(i,j);
        kappa_v(dex)  = varkappa(i,j);
        kagg_v(dex)   = kappa(i);
        phi_v(dex)    = phi(i);
    end
end

out2 = table(country2, sec2, beta_v, ups_v, kappa_v, kagg_v, phi_v, ...
    'VariableNames', {'country','sector','beta','upsilon','varkappa','kappa_agg','phi'});
writetable(out2, strcat(datapath, 'recovered_constants.csv'))

% export IO coefficients (nu)
n3 = 2*J*J;
country3 = cell(n3,1);
use_sec  = cell(n3,1);
src_sec  = cell(n3,1);
nu_v     = zeros(n3,1);
dex = 0;

for i = 1:2
    for j = 1:J
        for m = 1:J
            dex = dex + 1;
            country3{dex} = cnames{i};
            use_sec{dex}  = secs{j};
            src_sec{dex}  = secs{m};
            nu_v(dex)     = nu{i}(j,m);
        end
    end
end

out3 = table(country3, use_sec, src_sec, nu_v, ...
    'VariableNames', {'country','using_sector','source_sector','nu'});
writetable(out3, strcat(datapath, 'recovered_nu.csv'))

% export friction, wedge, bonds and the investment tax. Row t holds the
% quantities dated t: the wedge and chi_ratio span t to t+1, chi is the level
% at t, and bonds is the position B_{t+1} the friction is charged on.
n4 = 2*(Ty-1);
country4 = cell(n4,1);
yr4      = zeros(n4,1);
phi_fv   = zeros(n4,1);
wedge_v  = zeros(n4,1);
bonds_v  = zeros(n4,1);
chirat_v = zeros(n4,1);
chilvl_v = zeros(n4,1);
dex = 0;

for i = 1:2
    for t = 1:Ty-1
        dex = dex + 1;
        country4{dex} = cnames{i};
        yr4(dex)      = years(t);
        phi_fv(dex)   = phi_f(i,t);
        wedge_v(dex)  = wedge(i,t);
        bonds_v(dex)  = B(i,t+1);
        chirat_v(dex) = chi_ratio(i,t);
        chilvl_v(dex) = chi(i,t);
    end
end

out4 = table(country4, yr4, phi_fv, wedge_v, bonds_v, chirat_v, chilvl_v, ...
    'VariableNames', {'country','year','friction','wedge','bonds', ...
                      'chi_ratio','chi'});
writetable(out4, strcat(datapath, 'recovered_friction.csv'))

% export sectoral investment shares and the recovered investment shifters
n6 = 2*J*Ty;
country6 = cell(n6,1);
yr6      = zeros(n6,1);
sec6     = cell(n6,1);
xobs_v   = zeros(n6,1);
ups6_v   = zeros(n6,1);
mux_v    = zeros(n6,1);
dex = 0;

for i = 1:2
    for j = 1:J
        for t = 1:Ty
            dex = dex + 1;
            country6{dex} = cnames{i};
            yr6(dex)      = years(t);
            sec6{dex}     = secs{j};
            xobs_v(dex)   = x_obs(i,j,t);
            ups6_v(dex)   = ups(i,j);
            mux_v(dex)    = mux(i,j,t);
        end
    end
end

out6 = table(country6, yr6, sec6, xobs_v, ups6_v, mux_v, ...
    'VariableNames', {'country','year','sector','x_share_obs','upsilon','mu_x'});
writetable(out6, strcat(datapath, 'recovered_invshares.csv'))

% export the world interest rate. Row t holds R_{t+1}, the rate that prices a
% bond bought at t, so it lines up with the friction file.
n5 = Ty-1;
yr5     = (years(1:Ty-1))';
Rw_v    = R_obs(2:Ty)';
out5 = table(yr5, Rw_v, ...
    'VariableNames', {'year','R_world'});
writetable(out5, strcat(datapath, 'recovered_world_rate.csv'))

% export country-year consumption block
n7 = 2*Ty;
country7 = cell(n7,1);
yr7      = zeros(n7,1);
cbar_v   = zeros(n7,1);
pcm_v    = zeros(n7,1);
pxm_v    = zeros(n7,1);
ec_v     = zeros(n7,1);
k_v      = zeros(n7,1);
r_v      = zeros(n7,1);
vam_v    = zeros(n7,1);
dex = 0;

for i = 1:2
    for t = 1:Ty
        dex = dex + 1;
        country7{dex} = cnames{i};
        yr7(dex)      = years(t);
        cbar_v(dex)   = Cbar(i,t);
        pcm_v(dex)    = PC_model(i,t);
        pxm_v(dex)    = PX(i,t);
        ec_v(dex)     = EC(i,t);
        k_v(dex)      = Klom(i,t);
        r_v(dex)      = r(i,t);
        vam_v(dex)    = VAm(i,t);
    end
end

out7 = table(country7, yr7, cbar_v, pcm_v, pxm_v, ec_v, k_v, r_v, vam_v, ...
    'VariableNames', {'country','year','cbar','pc_model','px_model','ec','k','r','va_model'});
writetable(out7, strcat(datapath, 'recovered_consumption.csv'))
fprintf('Done. Parameters written to %s\n', datapath)
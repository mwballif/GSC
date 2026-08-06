%==============================================================================
% recover_parameters.m
%
% Purpose: Recover the model's disturbances from the two-country panels: demand
%          shifters mu, unit costs c, trade costs tau, productivities T, the
%          financial friction, and the investment efficiency shifter chi.
% Reads:   the three _2country panels, panel_B.csv, panel_D.csv, the crosswalks
% Writes:  recovered_parameters.csv, recovered_constants.csv, recovered_nu.csv,
%          recovered_friction.csv, recovered_invshares.csv,
%          recovered_world_rate.csv, recovered_consumption.csv
%
% Follows Reyes-Heroles, "Globalization and Structural Change in the United
% States", with the four changes in PROJECT_SPEC.md: reparameterized CES
% aggregator, tradable services, extended sample, and the financial friction in
% place of the intertemporal preference shifter. Every equation implemented here
% is labelled with its tag in paper/math_appendix.tex.
%
% NOTE: never name a loop counter d. It is the depreciation rate.
%==============================================================================

clear

datapath = '../../../data/processed/';
cwpath   = '../../../data/crosswalks/';

%% Set calibrated parameters
% NOTE: these must match model/parameters.m.
theta = 4;                          % Trade elasticity
psi   = 0.57;                       % Price elasticity of demand
% Sectoral income elasticities [AGR MAN SER], Comin-Lashkari-Mestieri (2021).
% They normalize manufacturing to one; this model normalizes the sum to one.
%
% DO NOT "translate" these into the paper's units. The appendix aggregator is
% CLM's own functional form: their eq (1) puts the exponent eps*(1-sigma)/sigma
% on real consumption, their eq (3) expenditure function gives price index
% exponent (1-sigma)(eps-1), and their relative demand elasticity is
% (1-sigma)(eps_i - eps_j) -- all three match eq:aggregator, eq:priceindex and
% eq:demand-raw exactly. So CLM's published values belong here untranslated.
% The PAPER's eqs (4), (6), (7) are the reparameterized ones, with
% eps_paper = (1-psi)*eps_CLM + psi; its epsilons are therefore NOT comparable
% to these, and converting CLM into paper units and back would put a negative
% value on agriculture, which CLM's own eps > 0 restriction rules out.
%
% NOTE: at a FIXED kappa the choice is irrelevant, exactly as the appendix says
% under eq:aggregator: rescaling every eps by a common factor is absorbed by the
% units of C, since the kappa equation moves C by the reciprocal power. Verified
% to 2e-14. It matters here only because kappa_source below is 'pwt_anchor',
% which makes kappa itself a function of eps; on that path switching the
% normalization moves mu by up to three orders of magnitude and flips the cross
% sector ranking. Set kappa numerically to recover the invariance.
eps_norm = 'sum1';
eps_clm  = [0.02 1.0 1.17];
switch eps_norm
    case 'sum1', eps = eps_clm / sum(eps_clm);   %[0.0091 0.4566 0.5342]
    case 'clm',  eps = eps_clm;
    otherwise,   error('eps_norm must be sum1 or clm')
end
zeta  = 1;                          %investment elasticity
eta   = 2;                          %within sector elasticity
delta = 0.95;                       %discount factor
d     = 0.05;                       %depreciation rate
% Capital adjustment cost parameter, sigma. Zero is the paper's calibration:
% adjustment costs are infinite.
%
% NOTE: at sigma = 0 investment drops out and chi is just capital growth.
sigma = 0;
Gam   = gamma((theta+1-eta)/theta)^(1/(1-eta));   %EK constant

%% Set the capital share in value added, phi
% From Caselli and Feyrer (2007) Table II. alpha_w is the total capital share;
% alpha_k nets out land and resource rents.
%
% NOTE: K is PWT reproducible capital, so alpha_k is the consistent pairing.
phi_measure = 'alpha_w';

cf  = readtable(strcat(cwpath, 'capital_shares_cf2007.csv'));
cwk = readtable(strcat(cwpath, 'country_num_crosswalk.csv'));
cf_ctry  = string(cf.country);
cwk_ctry = string(cwk.country);
cf_phi   = cf.(phi_measure);

% Aggregate phi to ROW as a value-added-weighted mean of member shares. Weights
% are mean annual value added per country from panel_B.
pb_w = readtable(strcat(datapath, 'panel_B.csv'));
pb_w = pb_w(~(pb_w.year == 2000 & pb_w.source == 1), :);

nC     = height(cwk);
va_i   = zeros(nC,1);      %mean annual value added by country
phi_i  = nan(nC,1);        %CF share by country, NaN where unavailable
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

% Warn about coverage.
%
% NOTE: uncovered countries get the covered countries' weighted mean.
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

%% load two country panels (USA vs ROW aggregate)
cs = readtable(strcat(datapath, 'CountrySectorPanel_2country.csv'));   %country sector output and prices
cp = readtable(strcat(datapath, 'CountryPanel_2country.csv'));         %country aggregates
bp = readtable(strcat(datapath, 'ImpExpSectorPanel_2country.csv'));    %bilateral trade

% panel_D carries both releases; the splice below needs the 2000 row of each.
io = readtable(strcat(datapath, 'panel_D.csv'));
usa_code = 24;

years = 1965:2014;
Ty = numel(years);
secs = {'AGR','MAN','SER'};
J = 3;
cnames = {'USA','ROW'};

%% read country sector panel
GO   = zeros(2,J,Ty);    %nominal gross output
VA   = zeros(2,J,Ty);    %value added
EXPD = zeros(2,J,Ty);    %sector expenditure
CE   = zeros(2,J,Ty);    %consumption expenditure
XE   = zeros(2,J,Ty);    %investment expenditure
P    = zeros(2,J,Ty);    %sector price level
NXS  = zeros(2,J,Ty);    %sectoral net exports, as stored (audited below)

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

%% read country panel
GDP = zeros(2,Ty);   %gdp
L   = zeros(2,Ty);   %employment
K   = zeros(2,Ty);   %capital stock
PC  = zeros(2,Ty);   %consumption price
PX  = zeros(2,Ty);   %investment price

for i = 1:2
    for t = 1:Ty
        row = strcmp(cp.country, cnames{i}) & cp.year == years(t);
        GDP(i,t) = cp.gdp(row);
        L(i,t)   = cp.emp(row);
        K(i,t)   = cp.k_stock(row);
        PC(i,t)  = cp.consump_pi(row);
        PX(i,t)  = cp.invest_pi(row);
    end
end

%% read import shares
%pi_mat(im,ex) is share of importer im expenditure sourced from exporter ex
%
%The destination index is im, not d: d is the depreciation rate set above and
%a loop counter named d silently overwrote it, leaving 1-d = -1 in the chi
%block downstream.
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

%% read input-output flows, chain-linked at 2000
%IOF(i,j,m,t) is spending by country i's sector j (using) on inputs from
%sector m (source), summed over every source country.
%
%panel_D never passes through the Stata stage, so the 2000 splice has to
%happen here. Read raw, its post-2000 rows are R16 levels while every other
%quantity in the panel has been chain-linked onto the LR 2000 level. The two
%bases are not comparable and the WIOT identity
%    E^j = P^jC^j + P^jX^j + sum_m P^jD^{m,j}
%then fails in all 14 post-2000 years (by up to 17.6% in ROW agriculture)
%while holding exactly in all 36 years before. Splice rule is the same one
%the panels use: LR levels through 2000, R16 growth rates after.
IOF  = zeros(2,J,J,Ty);     %spliced
IO_R = zeros(2,J,J,Ty);     %raw R16 levels, 2000-2014 only
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

%Column identity behind eq:interm in the math appendix: sector j's total
%intermediate purchases, sum_m D^{j,m}, must equal GO^j - VA^j. When it holds,
%the closed form (1-beta) nu Y evaluated at year-t shares equals the measured
%flows exactly, which is why the mu recovery below uses the flows; at the
%calibrated time-invariant shares the closed form misses the flows by tens of
%percent and would push mu^AGR negative, so it is never used. Passes at the 1%
%level before 2000; the post-2000 gap is the IO splice, which rescales flows
%by R16 growth rates while GO and VA are spliced separately.
fprintf('Column identity, sum_m D^{j,m} vs GO^j - VA^j (max rel dev):\n');
for i = 1:2
    for j = 1:J
        buy = squeeze(sum(IOF(i,j,:,:),3));      %total purchases by sector j
        tgt = squeeze(GO(i,j,:) - VA(i,j,:));
        dev = abs(buy ./ tgt - 1);
        fprintf('  %-3s %-3s  pre-2000 max %.3f   post-2000 max %.3f\n', ...
                cnames{i}, secs{j}, max(dev(1:t00)), max(dev(t00+1:end)));
    end
end

%% shares from data
beta = mean(VA ./ GO, 3, 'omitnan');            %value added share of gross output
ups  = mean(XE ./ sum(XE,2), 3, 'omitnan');     %investment expenditure shares

%IO shares, row is using (producing) sector, column is source sector, rows
%sum to 1; time-invariant, so recovered as a time average like beta and ups
nu_shares = mean(IOF ./ sum(IOF,3), 4, 'omitnan');   %(2 x J x J)
nu = cell(2,1);
for i = 1:2
    nu{i} = squeeze(nu_shares(i,:,:));
end

%% factor prices
w = (1 - phi) .* GDP ./ L;   %wage
r = phi .* GDP ./ K;         %rental rate

%% aggregates
PXX   = squeeze(sum(XE,2));      %total investment expenditure, P^X X

% Aggregate net exports: output minus total expenditure, the one definition.
%
% NOTE: if a check below fires, the Stata stage is splicing trade separately.
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

% Total consumption expenditure from the budget constraint (math appendix,
% 53), as in the paper's eq (8), rather than from separate measurement. Since
% w and r are imputed from the capital share, w L + r K = GDP identically, so
% this is the national accounts identity E^C = GDP - investment - net exports.
% The WIOT consumption column is kept only as a cross-check: the two agree
% within a release and diverge only through the 2000 splice.
EC      = w .* L + r .* K - PXX - NX;
EC_wiot = squeeze(sum(CE,2));

%% Recover the demand shifters mu
% Invert the sectoral demand system for mu, sector by sector. See
% eq:mu-tradables in the math appendix for the expression.
%
% NOTE: the exponent is (1-psi)*eps^j, not the paper's eps^j - psi.
% NOTE: intermediate demand uses observed flows, not the beta/nu reconstruction.
% NOTE: C is identified by sum_j mu^j = kappa, so P^C is an output, not an input.

% Anchor the level of kappa to the PWT consumption price level, while still
% imposing that sum_j mu^j be constant over time.
%
% NOTE: kappa's level is free; its constancy over time is what binds.
kappa_source = 'pwt_anchor';        %'pwt_anchor' or a 2x1 vector of values

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
                        - ups(i,j) * (Pv(j)/PX(i,t))^(1-zeta) * PXX(i,t);
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

mu       = zeros(2,J,Ty);
s_share  = zeros(2,J,Ty);    %consumption expenditure shares s^j, eq:cons-shares
Cbar     = zeros(2,Ty);      %C_{i,t}/L_{i,t}, recovered from eq:kappa
PC_model = zeros(2,Ty);      %model-implied ideal consumption price index
addup    = zeros(2,Ty);      %sum_j N^j / E^C - 1, the adding-up check

for i = 1:2
    for t = 1:Ty
        Pv = reshape(P(i,:,t), 1, J);

        % numerators N^j of eq:mu-tradables
        N = zeros(1,J);
        for j = 1:J
            Dj   = sum(IOF(i,:,j,t));                                  %actual flows
            Xj   = ups(i,j) * (Pv(j)/PX(i,t))^(1-zeta) * PXX(i,t);     %eq:invshares
            N(j) = EXPD(i,j,t) - Dj - Xj;      %= Y^j - NX^j - D - X
        end
        assert(all(N > 0), 'numerator of eq:mu-tradables is not positive for %s %d', ...
               cnames{i}, years(t))

        addup(i,t) = sum(N) / EC(i,t) - 1;

        % solve eq:kappa for C/L. g is strictly decreasing in x = ln(C/L), so
        % bracket by expanding outward until the sign changes.
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

        mu(i,:,t)      = A .* Cbar(i,t).^(-(1-psi)*eps);
        s_share(i,:,t) = N / EC(i,t);
        PC_model(i,t)  = (EC(i,t)/L(i,t)) / Cbar(i,t);
    end
end

% mu must be strictly positive: mu^(1/psi) enters the CES aggregator.
assert(all(mu(:) > 0), 'recovered mu is not strictly positive')
% and must satisfy the normalization by construction
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
    % gap, not d: d is the depreciation rate and this assignment turned it
    % into a 1 x Ty row vector for every block downstream.
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

%% unit cost constants varkappa (math appendix, eq:unitcost)
% Named varkappa, not kappa, because kappa above is the CES aggregator's
% normalization sum_j mu^j = kappa_i. The appendix uses varkappa for this one
% precisely to keep them apart; reusing one name here previously overwrote the
% aggregator constant so it never reached disk.
%
% varkappa = (beta phi^phi (1-phi)^(1-phi))^(-beta)
%            * ((1-beta) prod_m nu_m^nu_m)^(-(1-beta))
% which is the appendix's expression regrouped; verified identical to 4e-16.
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

%% unit costs c (math appendix, eq:unitcost)
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

%% trade costs tau and productivities T (math appendix, eq:gravity-ratio and eq:homeshare)
%tau(im,ex) is the cost of importer im buying from exporter ex. Loop counters
%are im/ex rather than d/o for the reason given at the import share block.
tau   = ones(2,2,J,Ty);
Tprod = zeros(2,J,Ty);
for j = 1:J
    for t = 1:Ty
        for im = 1:2
            for ex = 1:2
                if im ~= ex
                    tau(im,ex,j,t) = (P(im,j,t)/P(ex,j,t)) * ...
                                     (pi_mat(ex,ex,j,t)/pi_mat(im,ex,j,t))^(1/theta);
                end
            end
        end
        for i = 1:2
            Tprod(i,j,t) = pi_mat(i,i,j,t) * (Gam * c(i,j,t) / P(i,j,t))^theta;
        end
    end
end

%% Recover the financial friction and the world interest rate
% Two equations, three unknowns, so ROW's friction is normalized to zero. The
% ROW Euler equation then gives the world interest rate, and the US Euler
% equation gives the US friction. See eq:euler in the math appendix.

% Consumption expenditure shares, eq:cons-shares in the appendix. The recovery
% already delivers them as N^j/E^C. They sum to one only up to the
% over-identifying residual reported above (well under 1% before 2000), not by
% construction -- that residual IS the appendix's adding-up check.
varpi = s_share;

% Structural wedge under aggregator (1): phitilde(i,t) = (sum_j eps_j s^j)^{-1}.
% The paper's counterpart is (1-psi)*(sum_j eps_j s^j - psi)^{-1}; the (1-psi)
% factors cancel at the differentiation step under eq:aggregator. See eq:euler.
phitilde = zeros(2,Ty);
for i = 1:2
    for t = 1:Ty
        phitilde(i,t) = sum(eps .* varpi(i,:,t))^(-1);
    end
end

% World interest rate R_{t+1} from the ROW Euler equation alone, since the
% normalization phi_ROW = 0 leaves R as its only unknown. Appendix eq:worldR:
%   R_{t+1} = (1/delta) * (E^C_ROW,t+1/E^C_ROW,t) * (L_ROW,t/L_ROW,t+1)
%                       * (phitilde_ROW,t/phitilde_ROW,t+1)
% Written below with per-worker expenditure, which folds the two ratios into one.
R_w = zeros(1,Ty-1);
for t = 1:Ty-1
    ecpc_next = EC(2,t+1) / L(2,t+1);
    ecpc_now  = EC(2,t)   / L(2,t);
    R_w(t) = (ecpc_next / ecpc_now) / delta * ...
             phitilde(2,t) / phitilde(2,t+1);
end

% Accumulate bonds from net exports, then back out the US friction.
%
% NOTE: bonds earn R_t, i.e. R_w(t-1), not R_w(t).
% NOTE: report the wedge, not phi, which blows up where bonds cross zero.
B     = zeros(2,Ty);
phi_f = nan(2,Ty-1);    % friction, undefined at T (needs t+1)
wedge = nan(2,Ty-1);    % effective return wedge, 1 + phi (B - Bbar)
Bbar  = [0; 0];         % baseline foreign asset positions [US; ROW]

for t = 1:Ty-1
    % Bonds at t+1, at the return earned into t
    if t == 1
        B(:,t+1) = NX(:,t);                          % B(:,1) = 0
    else
        B(:,t+1) = R_w(t-1) * B(:,t) + NX(:,t);
    end

    % US friction (ROW friction is zero by normalization)
    phi_f(1,t) = (1 / (B(1,t+1) - Bbar(1))) * ...
        (EC(1,t)/L(1,t) / (EC(1,t+1)/L(1,t+1)) * ...
         phitilde(1,t+1)/phitilde(1,t) * delta * R_w(t) - 1);
    phi_f(2,t) = 0;

    for i = 1:2
        wedge(i,t) = 1 + phi_f(i,t) * (B(i,t+1) - Bbar(i));
    end
end

%% Recover the investment efficiency shifter chi
% Invert the capital accumulation equation directly, using the observed PWT
% capital stock. Undefined in the terminal year, which needs next year's capital.
%
% NOTE: no recursion needed. K is observed, so the law of motion suffices.

X = PXX ./ PX;                  % real aggregate investment

chi = nan(2,Ty);
for i = 1:2
    for t = 1:Ty-1
        net      = K(i,t+1) - (1-d) * K(i,t);
        chi(i,t) = net / (X(i,t)^sigma * K(i,t)^(1-sigma));
    end
end

fprintf('\nInvestment block:\n');
for i = 1:2
    fprintf('  %-3s  chi (sigma=%.2f) mean %.4f range [%.4f %.4f]\n', ...
        cnames{i}, sigma, mean(chi(i,1:Ty-1)), min(chi(i,1:Ty-1)), max(chi(i,1:Ty-1)));
end
fprintf('  Euler return wedge 1+phi(B-Bbar), USA: range [%.4f %.4f]\n', ...
    min(wedge(1,1:Ty-1)), max(wedge(1,1:Ty-1)));

%% sectoral investment shares: observed vs the model's constant upsilon
% ups is a time average of XE./sum(XE,2). The model imposes zeta = 1, so
% eq:invshares makes the share of investment spending on sector j equal to
% upsilon^j in every year. x_obs is the actual year by year share. The gap is
% what the mu inversion has to absorb, and agriculture bears it because its
% consumption share is under one percent.
x_obs = XE ./ sum(XE,2);        % (2 x J x Ty) observed investment shares

%% save time varying parameters
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
            tau_v(dex)   = tau(i,3-i,j,t);   %import trade cost
        end
    end
end

% s_share is exported because the counterfactual needs baseline consumption
% expenditure shares as weights: written in changes, the demand block uses
% observed shares and the mu levels drop out entirely.
s_v = zeros(n,1);
dex = 0;
for i = 1:2
    for j = 1:J
        for t = 1:Ty
            dex = dex + 1;
            s_v(dex) = s_share(i,j,t);
        end
    end
end

out = table(country, yr, sec, mu_v, c_v, T_v, tau_v, s_v, ...
    'VariableNames', {'country','year','sector','mu','unit_cost','T','tau','cons_share'});
writetable(out, strcat(datapath, 'recovered_parameters.csv'))

%% save constant parameters
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
        kappa_v(dex)  = varkappa(i,j);   %unit cost constant, eq:unitcost
        kagg_v(dex)   = kappa(i);        %CES aggregator constant, eq:kappa
        phi_v(dex)    = phi(i);
    end
end

out2 = table(country2, sec2, beta_v, ups_v, kappa_v, kagg_v, phi_v, ...
    'VariableNames', {'country','sector','beta','upsilon','varkappa','kappa_agg','phi'});
writetable(out2, strcat(datapath, 'recovered_constants.csv'))

%% save IO coefficients nu
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

%% save country-year level parameters (friction, efficiency shifter, world interest rate)
% phi_f(i,t)      financial friction coefficient, undefined at T. Units depend
%                 on the units of B; use wedge for anything interpretable.
% wedge(i,t)      1 + phi_f (B - Bbar), the effective return wedge.
% bonds(i,t)      net foreign asset position B_{i,t+1}, millions USD.
% chi(i,t)        investment-specific efficiency shifter at sigma.
% R_w(t)          world interest rate for period t+1.
n4 = 2*(Ty-1);
country4 = cell(n4,1);
yr4      = zeros(n4,1);
phi_fv   = zeros(n4,1);
wedge_v  = zeros(n4,1);
bonds_v  = zeros(n4,1);
chi_v    = zeros(n4,1);

dex = 0;
for i = 1:2
    for t = 1:Ty-1
        dex = dex + 1;
        country4{dex} = cnames{i};
        yr4(dex)      = years(t);
        phi_fv(dex)   = phi_f(i,t);
        wedge_v(dex)  = wedge(i,t);
        bonds_v(dex)  = B(i,t+1);
        chi_v(dex)    = chi(i,t);
    end
end

out4 = table(country4, yr4, phi_fv, wedge_v, bonds_v, chi_v, ...
    'VariableNames', {'country','year','friction','wedge','bonds','chi'});
writetable(out4, strcat(datapath, 'recovered_friction.csv'))

% Sectoral investment shares: the model's constant upsilon against the
% observed year by year shares (see the investment block above).
n6 = 2*J*Ty;
country6 = cell(n6,1);
yr6      = zeros(n6,1);
sec6     = cell(n6,1);
xobs_v   = zeros(n6,1);
ups6_v   = zeros(n6,1);

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
        end
    end
end

out6 = table(country6, yr6, sec6, xobs_v, ups6_v, ...
    'VariableNames', {'country','year','sector','x_share_obs','upsilon'});
writetable(out6, strcat(datapath, 'recovered_invshares.csv'))

% World interest rate (country-invariant, one value per year transition)
n5 = Ty-1;
yr5     = (years(1:Ty-1))';
Rw_v    = R_w';

out5 = table(yr5, Rw_v, ...
    'VariableNames', {'year','R_world'});
writetable(out5, strcat(datapath, 'recovered_world_rate.csv'))

%% save the country-year consumption block, all Ty years
% cbar     C_{i,t}/L_{i,t}, real consumption per worker, the root of eq:kappa.
% pc_model the model's own ideal price index, E^C/(L cbar). An OUTPUT of the
%          recovery, not an input -- the counterfactual needs it to replace the
%          PWT stand-in, and it is the object eq:priceindex defines.
% ec       total consumption expenditure from the budget constraint.
% These are separate from recovered_friction.csv because they are defined in
% every year, while the friction and chi are not defined at T.
n7 = 2*Ty;
country7 = cell(n7,1);
yr7      = zeros(n7,1);
cbar_v   = zeros(n7,1);
pcm_v    = zeros(n7,1);
ec_v     = zeros(n7,1);

dex = 0;
for i = 1:2
    for t = 1:Ty
        dex = dex + 1;
        country7{dex} = cnames{i};
        yr7(dex)      = years(t);
        cbar_v(dex)   = Cbar(i,t);
        pcm_v(dex)    = PC_model(i,t);
        ec_v(dex)     = EC(i,t);
    end
end

out7 = table(country7, yr7, cbar_v, pcm_v, ec_v, ...
    'VariableNames', {'country','year','cbar','pc_model','ec'});
writetable(out7, strcat(datapath, 'recovered_consumption.csv'))

fprintf('Done. Parameters written to %s\n', datapath)

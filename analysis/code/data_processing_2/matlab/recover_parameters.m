%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% recover_parameters.m
% recovers demand shifters mu, unit costs c, trade costs tau,
% productivities T, the financial friction phi_{i,t} (Euler wedge), and
% the investment-specific efficiency shifter chi_{i,t} from the US and ROW
% two country panels.
%
% Follows the recovery process in Reyes-Heroles, "Globalization and
% Structural Change in the United States", except that services are
% treated as tradable.
%
% Of the paper's time-invariant parameters, beta (value added to gross
% output ratio), ups (aggregate investment expenditure shares) and nu (IO
% coefficients) are built from the data panels below rather than
% calibrated; theta, psi, eta, zeta and eps are set to the calibrated
% values from the paper's table and Comin-Lashkari-Mestieri (2021); phi is
% read from the country specific Caselli and Feyrer (2007) capital shares
% in capital_shares_cf2007.csv and aggregated to the two country system.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear

datapath = '../../../data/processed_2/';
cwpath   = '../../../data/crosswalks/';

%% set parameters
theta = 4;                          %trade elasticity
psi   = 0.57;                       %price elasticity of demand (Comin et al. 2015)
%income elasticities [agr man ser], Comin-Lashkari-Mestieri (2021, ECMA)
%Table III column 1, the world cross country baseline that also supplies
%psi = sigma = 0.57. CLM report these under their own eps_m = 1
%normalization; the GSC derivation instead states sum_j eps^j = 1.
%
%DO NOT "translate" these into the paper's units. The appendix aggregator is
%CLM's own functional form: their eq (1) puts the exponent eps*(1-sigma)/sigma
%on real consumption, their eq (3) expenditure function gives price index
%exponent (1-sigma)(eps-1), and their relative demand elasticity is
%(1-sigma)(eps_i - eps_j) -- all three match eq:aggregator, eq:priceindex and
%eq:demand-raw exactly. So CLM's published values belong here untranslated. The
%PAPER's eqs (4), (6), (7) are the reparameterized ones, with
%eps_paper = (1-psi)*eps_CLM + psi; its epsilons are therefore NOT comparable to
%these, and converting CLM into paper units and back would put a negative value
%on agriculture, which CLM's own eps > 0 restriction rules out.
%
%At a FIXED kappa the choice is irrelevant, exactly as the appendix says under
%eq:aggregator: rescaling every eps by a common factor is absorbed by the units
%of C, because the kappa equation moves C by the reciprocal power and the two
%cancel in mu. Verified to 2e-14.
%
%It matters here only because kappa_source below is 'pwt_anchor', which makes
%kappa itself a function of eps. On that path switching the normalization moves
%mu by up to three orders of magnitude and flips the cross sector ranking
%(USA 1970 goes from [0.81 5.76 3.69] to [0.77 0.42 0.17]). Set kappa
%numerically to recover the invariance. Set eps_norm to 'sum1' to divide by the
%sum (each eps scaled by 1/2.19), or 'clm' to use CLM's published values
%unscaled.
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
%Capital adjustment cost parameter in the accumulation equation
%    K_{t+1} = (1-d) K_t + chi_t X_t^sigma K_t^{1-sigma}.
%sigma = 0 is the paper's calibration table: infinite adjustment costs, so
%investment drops out of the accumulation equation entirely and chi collapses
%to the capital growth rate plus depreciation. The paper is explicit that chi
%is then uninformative for counterfactuals, which is why it instead holds the
%investment to GDP ratio fixed. sigma_alt is an interior value reported
%alongside the baseline; there the capital Euler equation becomes an
%over-identifying restriction and its residual is reported as a diagnostic.
sigma     = 0;
sigma_alt = 0.5;
Gam   = gamma((theta+1-eta)/theta)^(1/(1-eta));   %EK constant

%% capital share in value added, phi [US; ROW]
% Country specific and time invariant, from Caselli and Feyrer (2007, QJE)
% Table II, stored in capital_shares_cf2007.csv. Two measures are
% available: alpha_w is the total capital share (one minus the labor
% share) and alpha_k is the reproducible capital share, which nets out
% land and natural resource rents. Because K here is PWT reproducible
% capital (rnna), alpha_k is the internally consistent pairing and is the
% natural robustness check; alpha_w is the standard macro capital share.
phi_measure = 'alpha_w';

cf  = readtable(strcat(cwpath, 'capital_shares_cf2007.csv'));
cwk = readtable(strcat(cwpath, 'country_num_crosswalk.csv'));
cf_ctry  = string(cf.country);
cwk_ctry = string(cwk.country);
cf_phi   = cf.(phi_measure);

% phi is a share of value added, so the bloc aggregate is bloc capital
% income over bloc value added: phi_ROW = sum_i phi_i VA_i / sum_i VA_i,
% the value added weighted mean of member shares. Weights are mean annual
% value added per country from panel_B, the 25 country extraction output,
% dropping the duplicate year 2000 R16 rows.
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

% Coverage warning. CF has no data for the WIOT residual region, CHN, DEU,
% BRA, IND or TWN, so the ROW share is the covered countries' weighted
% mean, implicitly assigning that mean to the uncovered remainder.
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

%panel_D carries both releases (LR 1965-2000, R16 2000-2014). Both are kept
%here because the splice below needs the R16 year 2000 row as a growth base.
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
%percent and would push mu^AGR negative, so it is never used.
%
%In this government-exclusion arm the identity FAILS for services (by up to a
%factor of 2.8): the experiment removes more services from final demand
%(government consumption) than from production (government value added and its
%input purchases), so go_wiot = expend + nx sits below va + ii, GO - VA
%understates services' purchases, and beta^SER is overstated (0.71 against
%0.61 on consistent accounts, US 2000). The baseline arm passes at the 1%
%level before 2000. mu is unaffected -- the recovery is absorption-side
%throughout -- but beta feeds unit costs and hence recovered T.
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
NX    = squeeze(sum(GO,2)) - squeeze(sum(EXPD,2));  %aggregate net exports

% Total consumption expenditure from the budget constraint (math appendix eq
% 53), as in the paper's eq (8), rather than from separate measurement. Since
% w and r are imputed from the capital share, w L + r K = GDP identically, so
% this is the national accounts identity E^C = GDP - investment - net exports.
% The WIOT consumption column is kept only as a cross-check: the two agree
% within a release and diverge only through the 2000 splice.
% EXPERIMENT (data_processing_2): government consumption is excluded from the
% panels, but government value added is still in GDP, so GDP - investment - net
% exports no longer equals household consumption. E^C therefore comes from the
% sectoral consumption column, which makes sum_j N^j = E^C hold by construction.
% The budget-constraint version is kept as a diagnostic; the gap between them is
% roughly government consumption.
EC        = squeeze(sum(CE,2));
EC_budget = w .* L + r .* K - PXX - NX;

%% demand shifters mu (math appendix, eq:mu-inversion)
% mu^j = (Y^j - NX^j - sum_m P^j D^{m,j} - ups_j (P^j/P^X)^(1-zeta) P^X X)
%        / [ L * (P^j)^(1-psi) * (E^C/L)^psi * (C/L)^((1-psi) eps^j) ]
% for all j in J, since services are tradable here and NX^s is observed.
%
% Denominator. The exponent is (1-psi)*eps^j, which follows from the updated
% aggregator (eq:aggregator). The paper's counterpart is eps^j - psi; that
% exponent belongs to the paper's aggregator and using it here biases mu by
% factors of roughly 2 to 5, varying by sector.
%
% Numerator, first term. sum_m P^j D^{m,j} is the OBSERVED intermediate flow,
% as in the paper's Lemma 4.1, not the reconstruction
% sum_m (1-beta_m) nu_{m,j} Y_m. The two agree only with time-varying beta and
% nu; with the calibrated time-invariant values the reconstruction spans 0.68
% to 1.78 times the flow, which drove mu^AGR negative in 11 of 50 U.S. years
% and 4 ROW years -- infeasible, since mu^(1/psi) enters the aggregator.
%
% Numerator, second term. The investment term keeps the model's demand system
% (eq:invshares), as the paper does, so mu stays the only residual on that
% margin. P^X X is the observed aggregate; with zeta = 1 the relative price
% term drops out. This is what makes mu^AGR noisy (see below).
%
% C_{i,t}. Not observed, and not proxied. Substituting eq:mu-inversion into the
% ideal price index (eq:priceindex) makes the exponent on C/L equal
% (1-psi)(eps^j-1) - (1-psi)eps^j = -(1-psi) for every j, so C and P^C both
% cancel and only sum_j N^j = E^C survives -- a restriction on the data, not an
% equation for C. C is identified instead by the aggregator's own restriction
% sum_j mu^j_{i,t} = kappa_i (eq:kappa), with E^C from the budget constraint
% (eq:C-budget). Solving eq:kappa in logs, x = ln(C/L), the objective
%     g(x) = ln( sum_j A_j exp(-(1-psi) eps_j x) ) - ln(kappa)
% is strictly decreasing, so the root is unique where it exists.
%
% P^C is therefore an OUTPUT of the recovery, not an input, and is compared
% with the PWT consumption price level below as validation. Imposing an
% external P^C instead would fix the units of C from outside the model and
% leave sum_j mu^j free to drift, violating eq:aggregator.

% kappa_i is a free normalization, but not an arbitrary one: (52) has a
% solution at a sensible C only if kappa_i lies in the range the data can
% deliver. Because eps^AGR is close to zero, mu^AGR is nearly insensitive to
% C, so kappa_i below roughly max_j A_j forces C to absurd magnitudes. The
% default below therefore anchors the LEVEL of kappa_i to the PWT consumption
% price level -- the time average of sum_j mu^j implied by
% C_{i,t} = E^C_{i,t}/P^C_{PWT,i,t} -- while still imposing the model's
% restriction that sum_j mu^j be CONSTANT in t. That separates the free part
% of the normalization (its level) from the binding part (its constancy). Set
% kappa directly instead if the target draft's value is known.
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
Cbar     = zeros(2,Ty);      %C_{i,t}/L_{i,t}, recovered from (52)
PC_model = zeros(2,Ty);      %model-implied ideal consumption price index
addup    = zeros(2,Ty);      %sum_j N^j / E^C - 1, the adding-up check

for i = 1:2
    for t = 1:Ty
        Pv = reshape(P(i,:,t), 1, J);

        % numerators N^j of eq:mu-inversion
        N = zeros(1,J);
        for j = 1:J
            Dj   = sum(IOF(i,:,j,t));                                  %actual flows
            Xj   = ups(i,j) * (Pv(j)/PX(i,t))^(1-zeta) * PXX(i,t);     %eq:invshares
            N(j) = EXPD(i,j,t) - Dj - Xj;      %= Y^j - NX^j - D - X
        end
        assert(all(N > 0), 'numerator of eq:mu-inversion is not positive for %s %d', ...
               cnames{i}, years(t))

        addup(i,t) = sum(N) / EC(i,t) - 1;

        % solve (52) for C/L. g is strictly decreasing in x = ln(C/L), so
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
fprintf('  consumption-column E^C vs budget constraint (approx. govt share):\n');
for i = 1:2
    % gap, not d: d is the depreciation rate and this assignment turned it
    % into a 1 x Ty row vector for every block downstream.
    gap = EC(i,:) ./ EC_budget(i,:) - 1;
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

%% unit cost constants varkappa (math appendix, eq:unitcost). Named varkappa,
% not kappa, to avoid overwriting the CES aggregator constant above.
% kappa = (beta phi^phi (1-phi)^(1-phi))^(-beta)
%         * ((1-beta) prod_m nu_m^nu_m)^(-(1-beta))
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

%% unit costs c (eqs 8 to 10)
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

%% trade costs tau and productivities T (eqs 11 to 17)
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

%% Euler equation wedge and financial friction phi_{i,t} (math appendix, eq:euler)
% The bond Euler equation (13/36):
%   E^C_{i,t+1}/E^C_{i,t} = phitilde_{i,t+1}/phitilde_{i,t} * delta * R_{t+1}
% where phitilde_{i,t} = (sum_j eps_j * varpi_i^j_t)^{-1}
% and varpi_i^j_t = P^j_i_t C^j_i_t / E^C_{i,t} is the consumption share.
%
% Normalization: phi_{ROW,t} = 0 for all t (Euler wedge in ROW set to zero).
%
% Under the normalization phi_ROW = 0, the ROW Euler equation identifies
% the common world interest rate.
%   R_{t+1} = (1/delta) * sum_i(E^C_{i,t+1}/phitilde_{i,t+1}) / sum_i(E^C_{i,t})
%
% Bond accumulation: B_{i,t+1} = R_{t+1} * B_{i,t} + NX_{i,t}
% Initial condition: B_{i,0} = 0 (zero net foreign assets at start of sample).

% Consumption expenditure shares. These are the model's s^j from appendix eq
% (11), which the recovery already delivers as N^j/E^C, so they sum to one by
% construction. Using the raw WIOT consumption column here instead would not,
% since E^C comes from the budget constraint.
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

% World interest rate R_{t+1} from the ROW Euler equation:
%   R_{t+1} = (1/delta) * [E^C_US,t+1/phitilde_US,t+1 + E^C_ROW,t+1/phitilde_ROW,t+1]
%                   / [E^C_US,t + E^C_ROW,t]
R_w = zeros(1,Ty-1);
for t = 1:Ty-1
    ecpc_next = EC(2,t+1) / L(2,t+1);
    ecpc_now  = EC(2,t)   / L(2,t);
    R_w(t) = (ecpc_next / ecpc_now) / delta * ...
             phitilde(2,t) / phitilde(2,t+1);
end

% US friction phi_{US,t} from the US Euler equation (paper eq 45/51):
%   phi_US,t = (1/(B_US,t+1 - Bbar_US)) *
%     [ E^C_US,t / E^C_US,t+1 * L_US,t+1 / L_US,t
%       * phitilde_US,t+1 / phitilde_US,t * delta * R_{t+1} - 1 ]
%
% ROW friction is zero by normalization.
% Bond accumulation: B_{i,t+1} = R_{t+1} * B_{i,t} + NX_{i,t}
%
% Reporting note. phi itself is not a comparable number: it enters the Euler
% equation only through the product phi_{i,t}(B_{i,t+1} - Bbar_i), and B is
% measured in millions of USD, so phi comes out around 1e-7 purely because of
% the units of the denominator it is divided by. Worse, B_US crosses zero once
% between 2000 and 2007 and is only 9.7 billion in 1965, so phi has a
% near-singularity at both dates while the product does not. The wedge
%     wedge_{i,t} = 1 + phi_{i,t}(B_{i,t+1} - Bbar_i)
% is the object with an economic reading -- the gap between the world gross
% return and the effective return the country faces -- and is what gets
% plotted. phi is written out as well so the model code can use it.
B     = zeros(2,Ty);
phi_f = nan(2,Ty-1);    % friction, undefined at T (needs t+1)
wedge = nan(2,Ty-1);    % effective return wedge, 1 + phi (B - Bbar)
Bbar  = [0; 0];         % baseline foreign asset positions [US; ROW]

for t = 1:Ty-1
    % Bonds at t+1, at the return earned INTO t. The appendix has
    % B_{i,t+1} = R_t B_{i,t} + NX_{i,t}, and R_w(t) is R_{t+1}, so the stock
    % carried into t earns R_w(t-1). Using R_w(t) here moves B by up to 9% and
    % phi by up to 57%; the wedge is unaffected either way.
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

%% Investment-specific efficiency shifter chi_{i,t} (math appendix, eq 12)
% Capital accumulation:
%   K_{i,t+1} = (1-d) K_{i,t} + chi_{i,t} X_{i,t}^sigma K_{i,t}^{1-sigma}
% inverted directly for chi:
%   chi_{i,t} = (K_{i,t+1} - (1-d) K_{i,t}) / (X_{i,t}^sigma K_{i,t}^{1-sigma})
% where X_{i,t} = P^X X_{i,t} / P^X_{i,t} is real aggregate investment and
% K is the observed PWT reproducible capital stock (rnna).
%
% Why there is no backward recursion here. The paper's two-equation backward
% iteration (its eqs 47 to 49) solves jointly for the pair (K_{i,t}, chi_{i,t})
% because it does not use capital stock data: it needs the capital Euler
% equation as a second equation to pin K down, and that only works for
% sigma strictly inside (0,1). We observe K, so the law of motion alone
% identifies chi period by period and the recursion is unnecessary. The paper
% says the same thing for its own sigma = 0 case: "additional data for capital
% stocks could be used to recover this shifters using only the law of motion
% for capital".
%
% At sigma = 0 the X term vanishes and chi_{i,t} = K_{i,t+1}/K_{i,t} - (1-d),
% i.e. the observed capital growth rate plus depreciation. Investment does not
% enter it and, as the paper notes, it carries no information for the
% counterfactuals. chi_alt at sigma_alt is reported alongside it, where
% investment does enter.
%
% chi is undefined in the terminal year, which needs K_{t+1}.

X = PXX ./ PX;                  % real aggregate investment

chi     = nan(2,Ty);            % baseline, at sigma
chi_alt = nan(2,Ty);            % robustness, at sigma_alt
for i = 1:2
    for t = 1:Ty-1
        net = K(i,t+1) - (1-d) * K(i,t);
        chi(i,t)     = net / (X(i,t)^sigma     * K(i,t)^(1-sigma));
        chi_alt(i,t) = net / (X(i,t)^sigma_alt * K(i,t)^(1-sigma_alt));
    end
end

%% capital Euler equation residual (math appendix, eq:capital-euler)
% At sigma = 0 the investment FOC divides by sigma and the capital Euler
% equation does not hold, which is exactly why the paper's recursion breaks
% there. At an interior sigma it does hold, and since K, X, r and R are all
% observed or already recovered, it is an over-identifying restriction rather
% than an equation to be solved. Reported as a log residual: zero means the
% data satisfy the model's investment decision.
%
%   R_{t+1}/wedge * P^X_t/chi_t * (X_t/K_t)^{1-sigma}
%     = sigma r_{t+1} + (1-sigma) P^X_{t+1} X_{t+1}/K_{t+1}
%       + (1-d) P^X_{t+1}/chi_{t+1} * (X_{t+1}/K_{t+1})^{1-sigma}
keuler_res = nan(2,Ty);
for i = 1:2
    for t = 1:Ty-2
        lhs = R_w(t) / wedge(i,t) * PX(i,t) / chi_alt(i,t) * ...
              (X(i,t)/K(i,t))^(1-sigma_alt);
        rhs = sigma_alt * r(i,t+1) ...
              + (1-sigma_alt) * PX(i,t+1) * X(i,t+1) / K(i,t+1) ...
              + (1-d) * PX(i,t+1) / chi_alt(i,t+1) * ...
                (X(i,t+1)/K(i,t+1))^(1-sigma_alt);
        keuler_res(i,t) = log(lhs/rhs);
    end
end

fprintf('\nInvestment block:\n');
for i = 1:2
    fprintf('  %-3s  chi (sigma=%.2f) mean %.4f range [%.4f %.4f]\n', ...
        cnames{i}, sigma, mean(chi(i,1:Ty-1)), min(chi(i,1:Ty-1)), max(chi(i,1:Ty-1)));
    fprintf('       chi (sigma=%.2f) mean %.4f range [%.4f %.4f]\n', ...
        sigma_alt, mean(chi_alt(i,1:Ty-1)), min(chi_alt(i,1:Ty-1)), max(chi_alt(i,1:Ty-1)));
    fprintf('       capital Euler log residual at sigma=%.2f: mean %+.3f, sd %.3f\n', ...
        sigma_alt, mean(keuler_res(i,1:Ty-2)), std(keuler_res(i,1:Ty-2)));
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

out = table(country, yr, sec, mu_v, c_v, T_v, tau_v, ...
    'VariableNames', {'country','year','sector','mu','unit_cost','T','tau'});
writetable(out, strcat(datapath, 'recovered_parameters.csv'))

%% save constant parameters
n2 = 2*J;
country2 = cell(n2,1);
sec2     = cell(n2,1);
beta_v   = zeros(n2,1);
ups_v    = zeros(n2,1);
kappa_v  = zeros(n2,1);
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
        phi_v(dex)    = phi(i);
    end
end

out2 = table(country2, sec2, beta_v, ups_v, kappa_v, phi_v, ...
    'VariableNames', {'country','sector','beta','upsilon','kappa','phi'});
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
% chi(i,t)        investment-specific efficiency shifter at sigma (baseline).
% chi_alt(i,t)    the same at sigma_alt.
% keuler_res(i,t) capital Euler log residual at sigma_alt (over-identifying).
% R_w(t)          world interest rate for period t+1.
n4 = 2*(Ty-1);
country4 = cell(n4,1);
yr4      = zeros(n4,1);
phi_fv   = zeros(n4,1);
wedge_v  = zeros(n4,1);
bonds_v  = zeros(n4,1);
chi_v    = zeros(n4,1);
chi_av   = zeros(n4,1);
keuler_v = zeros(n4,1);

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
        chi_av(dex)   = chi_alt(i,t);
        keuler_v(dex) = keuler_res(i,t);
    end
end

out4 = table(country4, yr4, phi_fv, wedge_v, bonds_v, chi_v, chi_av, keuler_v, ...
    'VariableNames', {'country','year','friction','wedge','bonds', ...
                      'chi','chi_alt','keuler_resid'});
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

fprintf('Done. Parameters written to %s\n', datapath)

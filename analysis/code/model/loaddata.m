function D = loaddata(P,V)

% loaddata: Reads every input the model takes as given.
% Puts the panels and the recovered disturbances into arrays indexed by sector,
% country and year, then holds the last year for P.pad more years.
% Inputs:  P (parameters), V (variable locations).
% Output:  D (structure of data arrays).

%---------------------------------------------
%   1. Time-invariant parameters
%---------------------------------------------
T = readtable(fullfile(P.datadir,'recovered_constants.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
D.beta   = fill([V.nsec V.ncty],T.beta,j,i);
D.varphi = fill([V.nsec V.ncty],T.phi,j,i);
D.varphi = D.varphi(1,:)';

T = readtable(fullfile(P.datadir,'recovered_nu.csv'),'TextType','char');
j = findidx(T.using_sector,V.sectors);
m = findidx(T.source_sector,V.sectors);
i = findidx(T.country,V.countries);
D.nu = fill([V.nsec V.nsec V.ncty],T.nu,j,m,i);

%---------------------------------------------
%   2. Country panel
%---------------------------------------------
T = readtable(fullfile(P.datadir,'CountryPanel_2country.csv'),'TextType','char');
D.years = unique(T.year(:));
D.T = length(D.years);
i = findidx(T.country,V.countries);
t = findidx(T.year,D.years);
D.NX  = fill([V.ncty D.T],T.tot_nx,i,t);
D.L   = fill([V.ncty D.T],T.emp,i,t);
D.gdp = fill([V.ncty D.T],T.gdp,i,t);

% Capital and the investment price come from the recovery, not PWT. On this pair
% the law of motion and E^X = P^X X both hold; on PWT's they miss by a third.
T = readtable(fullfile(P.datadir,'recovered_consumption.csv'),'TextType','char');
i = findidx(T.country,V.countries);
t = findidx(T.year,D.years);
D.PX = fill([V.ncty D.T],T.px_model,i,t);
Kobs = fill([V.ncty D.T],T.k,i,t);

%---------------------------------------------
%   3. Country-sector panel
%---------------------------------------------
T = readtable(fullfile(P.datadir,'CountrySectorPanel_2country.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
t = findidx(T.year,D.years);
D.Y  = fill([V.nsec V.ncty D.T],T.go_wiot,j,i,t);   % Gross output is go_wiot, not go
D.E  = fill([V.nsec V.ncty D.T],T.expend,j,i,t);
D.P0 = fill([V.nsec V.ncty D.T],T.go_lvl,j,i,t);

% Summed over sectors, not read from the country panel: the two are spliced
% separately and differ by up to 1.7 per cent.
D.EX = squeeze(sum(fill([V.nsec V.ncty D.T],T.invest,j,i,t),1));

% One column past the sample, from the law of motion, so investment is defined
% in every year.
D.K = [Kobs, (1-P.d)*Kobs(:,end) + D.EX(:,end)./D.PX(:,end)];

%---------------------------------------------
%   4. Bilateral trade shares
%---------------------------------------------
T = readtable(fullfile(P.datadir,'ImpExpSectorPanel_2country.csv'),'TextType','char');
j = findidx(T.sector,V.sectors);
i = findidx(T.importer,V.countries);
h = findidx(T.exporter,V.countries);
t = findidx(T.year,D.years);
D.pi = fill([V.nsec V.ncty V.ncty D.T],T.imp_sh,j,i,h,t);
D.pi = D.pi ./ sum(D.pi,3);                         % The file rounds to eight digits

%---------------------------------------------
%   5. Recovered disturbances
%---------------------------------------------
% The wedge and the tax are dated t to t+1, so they have one column fewer.
T = readtable(fullfile(P.datadir,'recovered_invshares.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
t = findidx(T.year,D.years);
D.mux = fill([V.nsec V.ncty D.T],T.mu_x,j,i,t);

T = readtable(fullfile(P.datadir,'recovered_friction.csv'),'TextType','char');
i = findidx(T.country,V.countries);
t = findidx(T.year,D.years(1:end-1));
D.wedge  = fill([V.ncty D.T-1],T.wedge,i,t);
D.chirat = fill([V.ncty D.T-1],T.chi_ratio,i,t);
D.bond0  = fill([V.ncty D.T-1],T.bonds,i,t);

% The observed rate. R is an unknown in the solve, so this is only a start value
% and a diagnostic.
T = readtable(fullfile(P.datadir,'recovered_world_rate.csv'),'TextType','char');
t = findidx(T.year,D.years(1:end-1));
D.R0 = fill([D.T-1 1],T.R_world,t);

% Productivity, unit costs and trade costs, in levels. Each country's row
% carries the one direction it imports on.
T = readtable(fullfile(P.datadir,'recovered_parameters.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
t = findidx(T.year,D.years);
D.T_lvl = fill([V.nsec V.ncty D.T],T.T,j,i,t);
D.c0    = fill([V.nsec V.ncty D.T],T.unit_cost,j,i,t);
tauimp  = fill([V.nsec V.ncty D.T],T.tau,j,i,t);
D.tau = ones(V.nsec,V.ncty,V.ncty,D.T);
for ii = 1:V.ncty
    for hh = 1:V.ncty
        if ii ~= hh, D.tau(:,ii,hh,:) = tauimp(:,ii,:); end
    end
end

%---------------------------------------------
%   6. Check
%---------------------------------------------
% Output must be spending routed through the trade shares.
chk = zeros(V.nsec,V.ncty,D.T);
for t = 1:D.T
    for j = 1:V.nsec
        for i = 1:V.ncty
            chk(j,i,t) = sum(squeeze(D.pi(j,:,i,t))'.*D.E(j,:,t)')/D.Y(j,i,t) - 1;
        end
    end
end
D.chkY = max(abs(chk(:)));
if D.chkY > 1e-5
    error('loaddata: the data violates Y = Pi*E by %.1e',D.chkY)
end

%---------------------------------------------
%   7. Hold the last year for P.pad more years
%---------------------------------------------
% Everything held at its last observed value, which means no wedge, no growth in
% the tax and a rate of 1/delta. Capital keeps accumulating.
H = P.pad;
Tn = D.T;
D.Tdata = Tn;               % Last year that is data, not a repeat
if H > 0
    D.years  = [D.years(:); D.years(end)+(1:H)'];
    D.L      = [D.L,  repmat(D.L(:,Tn), 1,H)];
    D.gdp    = [D.gdp,repmat(D.gdp(:,Tn),1,H)];
    D.EX     = [D.EX, repmat(D.EX(:,Tn),1,H)];
    D.NX     = [D.NX, repmat(D.NX(:,Tn),1,H)];
    D.PX     = [D.PX, repmat(D.PX(:,Tn),1,H)];
    D.Y      = cat(3, D.Y,  repmat(D.Y(:,:,Tn), [1 1 H]));
    D.E      = cat(3, D.E,  repmat(D.E(:,:,Tn), [1 1 H]));
    D.P0     = cat(3, D.P0, repmat(D.P0(:,:,Tn),[1 1 H]));
    D.mux    = cat(3, D.mux,repmat(D.mux(:,:,Tn),[1 1 H]));
    D.T_lvl  = cat(3, D.T_lvl,repmat(D.T_lvl(:,:,Tn),[1 1 H]));
    D.c0     = cat(3, D.c0, repmat(D.c0(:,:,Tn),[1 1 H]));
    D.pi     = cat(4, D.pi, repmat(D.pi(:,:,:,Tn),[1 1 1 H]));
    D.tau    = cat(4, D.tau,repmat(D.tau(:,:,:,Tn),[1 1 1 H]));
    D.wedge  = [D.wedge, ones(V.ncty,H)];
    D.chirat = [D.chirat,ones(V.ncty,H)];
    D.R0     = [D.R0; (1/P.delta)*ones(H,1)];
    for k = 1:H
        D.K(:,Tn+1+k) = (1-P.d)*D.K(:,Tn+k) + D.EX(:,Tn)./D.PX(:,Tn);
    end
    D.T = Tn + H;
end

% Trade costs frozen at the freeze year, for the counterfactual.
k0 = find(D.years == P.freezeyear,1);
D.tau0 = repmat(D.tau(:,:,:,k0),[1 1 1 D.T]);


function A = fill(siz,vals,varargin)

% fill: Places long-format values into an array of the given size.
% Errors if any cell is left empty.
% Inputs:  siz (array size), vals (the values), varargin (one index per
%           dimension).
% Output:  A (the filled array).
A = NaN(siz);
A(sub2ind(siz,varargin{:})) = vals;
if any(isnan(A(:)))
    error('loaddata: %d cells unfilled',sum(isnan(A(:))))
end

function idx = findidx(col,names)

% findidx: Finds where each entry of a column sits in a reference list.
% Matches text labels or numeric years.
% Inputs:  col (table column), names (reference list).
% Output:  idx (position of each entry).
idx = zeros(numel(col),1);
for k = 1:numel(names)
    if iscell(names)
        idx(strcmp(col,names{k})) = k;
    else
        idx(col == names(k)) = k;
    end
end
if any(idx == 0), error('loaddata: entry not in the reference list'), end

function [j,i] = findji(seccol,ctycol,V)

% findji: Gets the sector and country indices for a country-sector table.
% Inputs:  seccol (sector column), ctycol (country column), V.
% Outputs: j (sector index), i (country index).
j = findidx(seccol,V.sectors);
i = findidx(ctycol,V.countries);

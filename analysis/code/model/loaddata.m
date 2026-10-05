function D = loaddata(P,V)

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Every input the model takes as given, as arrays by sector, country and
%  year: EQconditions.tex's wedges, plus the panels behind the Section 3 base.
%
%  Inputs:  P, V
%  Output:  D (the data)
%  
%  Data used:
%           recovered_constants.csv, recovered_nu.csv, recovered_invshares.csv
%           recovered_parameters.csv, recovered_consumption.csv
%           recovered_friction.csv
%           CountryPanel_2country.csv, CountrySectorPanel_2country.csv
%           ImpExpSectorPanel_2country.csv
%
%==============================================================================

% - time-invariant parameters - %
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

% - country panel - %
T = readtable(fullfile(P.datadir,'CountryPanel_2country.csv'),'TextType','char');
D.years = unique(T.year(:));
D.T = length(D.years);
i = findidx(T.country,V.countries);
t = findidx(T.year,D.years);
D.NX  = fill([V.ncty D.T],T.tot_nx,i,t);
D.L   = fill([V.ncty D.T],T.emp,i,t);
D.gdp = fill([V.ncty D.T],T.gdp,i,t);

	% capital and the investment price, from the recovery rather than PWT %
T = readtable(fullfile(P.datadir,'recovered_consumption.csv'),'TextType','char');
i = findidx(T.country,V.countries);
t = findidx(T.year,D.years);
D.PX = fill([V.ncty D.T],T.px_model,i,t);
Kobs = fill([V.ncty D.T],T.k,i,t);

% - country-sector panel - %
T = readtable(fullfile(P.datadir,'CountrySectorPanel_2country.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
t = findidx(T.year,D.years);
D.Y  = fill([V.nsec V.ncty D.T],T.go_wiot,j,i,t);   % Gross output is go_wiot, not go
D.E  = fill([V.nsec V.ncty D.T],T.expend,j,i,t);
D.P0 = fill([V.nsec V.ncty D.T],T.go_lvl,j,i,t);

	% investment, summed over sectors rather than read off the country panel %
D.EX = squeeze(sum(fill([V.nsec V.ncty D.T],T.invest,j,i,t),1));

	% one column past the sample %
D.K = [Kobs, (1-P.d)*Kobs(:,end) + D.EX(:,end)./D.PX(:,end)];

	% the data's own path, kept apart from the array padyears extends %
D.Kdata = D.K;

% - bilateral trade shares - %
T = readtable(fullfile(P.datadir,'ImpExpSectorPanel_2country.csv'),'TextType','char');
j = findidx(T.sector,V.sectors);
i = findidx(T.importer,V.countries);
h = findidx(T.exporter,V.countries);
t = findidx(T.year,D.years);
D.pi = fill([V.nsec V.ncty V.ncty D.T],T.imp_sh,j,i,h,t);
D.pi = D.pi ./ sum(D.pi,3);                         % The file rounds to eight digits

% - recovered disturbances - %
	% the wedges, dated t to t+1 %
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

	% phi, loaded only to check the wedge identity %
	% (note: a period residual, not a slope; it blows up where B crosses Bbar) %
D.phi = fill([V.ncty D.T-1],T.friction,i,t);

	% productivity, unit costs and trade costs, one import direction per row %
T = readtable(fullfile(P.datadir,'recovered_parameters.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
t = findidx(T.year,D.years);
D.T_lvl = fill([V.nsec V.ncty D.T],T.T,j,i,t);
D.c0    = fill([V.nsec V.ncty D.T],T.unit_cost,j,i,t);
D.muc   = fill([V.nsec V.ncty D.T],T.mu,j,i,t);
tauimp  = fill([V.nsec V.ncty D.T],T.tau,j,i,t);
D.tau = ones(V.nsec,V.ncty,V.ncty,D.T);
for ii = 1:V.ncty
    for hh = 1:V.ncty
        if ii ~= hh, D.tau(:,ii,hh,:) = tauimp(:,ii,:); end
    end
end

% - check: market clearing for output must hold in the data - %
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

% - last data year - %
D.Tdata = D.T;


function A = fill(siz,vals,varargin)

% fill: long-format values into an array, erroring on any cell left empty
%  Inputs:  siz, vals, varargin (one index per dimension)
%  Output:  A
A = NaN(siz);
A(sub2ind(siz,varargin{:})) = vals;
if any(isnan(A(:)))
    error('loaddata: %d cells unfilled',sum(isnan(A(:))))
end

function idx = findidx(col,names)

% findidx: where each entry of a column sits in a reference list
%  Inputs:  col, names
%  Output:  idx
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

% findji: sector and country indices for a country-sector table
%  Inputs:  seccol, ctycol, V
%  Outputs: j, i
j = findidx(seccol,V.sectors);
i = findidx(ctycol,V.countries);

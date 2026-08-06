function D = loaddata(P,V)

% loaddata: Reads the panel into arrays indexed by sector, country and year
% Input:
%   P : Structure of parameters
%   V : Structure of variables
% Output:
%   D : Structure of data arrays

% Constants: value added shares, investment shares, capital share
T = readtable(fullfile(P.datadir,'recovered_constants.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
D.beta    = fill([V.nsec V.ncty],T.beta,j,i);
D.upsilon = fill([V.nsec V.ncty],T.upsilon,j,i);
D.varphi  = fill([V.nsec V.ncty],T.phi,j,i);
D.varphi  = D.varphi(1,:)';

% Input-output coefficients: sector j's spending share on good m
T = readtable(fullfile(P.datadir,'recovered_nu.csv'),'TextType','char');
j = findidx(T.using_sector,V.sectors);
m = findidx(T.source_sector,V.sectors);
i = findidx(T.country,V.countries);
D.nu = fill([V.nsec V.nsec V.ncty],T.nu,j,m,i);

% Country panel: investment, net exports, employment, GDP
T = readtable(fullfile(P.datadir,'CountryPanel_2country.csv'),'TextType','char');
D.years = unique(T.year(:));
D.T = length(D.years);
i = findidx(T.country,V.countries);
t = findidx(T.year,D.years);
D.EX  = fill([V.ncty D.T],T.tot_invest,i,t);
D.NX  = fill([V.ncty D.T],T.tot_nx,i,t);
D.L   = fill([V.ncty D.T],T.emp,i,t);
D.gdp = fill([V.ncty D.T],T.gdp,i,t);

% Country-sector panel: gross output and sectoral expenditure
% Gross output is go_wiot, not go
T = readtable(fullfile(P.datadir,'CountrySectorPanel_2country.csv'),'TextType','char');
[j,i] = findji(T.sector,T.country,V);
t = findidx(T.year,D.years);
D.Y = fill([V.nsec V.ncty D.T],T.go_wiot,j,i,t);
D.E = fill([V.nsec V.ncty D.T],T.expend,j,i,t);

% Bilateral trade shares: buyer i, seller h
T = readtable(fullfile(P.datadir,'ImpExpSectorPanel_2country.csv'),'TextType','char');
j = findidx(T.sector,V.sectors);
i = findidx(T.importer,V.countries);
h = findidx(T.exporter,V.countries);
t = findidx(T.year,D.years);
D.pi = fill([V.nsec V.ncty V.ncty D.T],T.imp_sh,j,i,h,t);
D.pi = D.pi ./ sum(D.pi,3);     % the file rounds to eight digits

% Recovered series, for comparison only. Row t is the gap from t to t+1.
T = readtable(fullfile(P.datadir,'recovered_friction.csv'),'TextType','char');
i = findidx(T.country,V.countries);
t = findidx(T.year,D.years(1:end-1));
D.wedge0 = fill([V.ncty D.T-1],T.wedge,i,t);
D.bond0  = fill([V.ncty D.T-1],T.bonds,i,t);
T = readtable(fullfile(P.datadir,'recovered_world_rate.csv'),'TextType','char');
t = findidx(T.year,D.years(1:end-1));
D.R0 = fill([D.T-1 1],T.R_world,t);

% The data must satisfy Y = Pi*E, or the gross output column is wrong
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
%   Reshaping helpers
%---------------------------------------------
function A = fill(siz,vals,varargin)
% Place long-format values into an array, one index vector per dimension
A = NaN(siz);
A(sub2ind(siz,varargin{:})) = vals;
if any(isnan(A(:)))
    error('loaddata: %d cells unfilled',sum(isnan(A(:))))
end

function idx = findidx(col,list)
% Turn a column of labels into positions in a canonical list
[tf,idx] = ismember(col,list);
if ~all(tf), error('loaddata: unknown label in the panel'), end
idx = idx(:);

function [j,i] = findji(seccol,ctycol,V)
j = findidx(seccol,V.sectors);
i = findidx(ctycol,V.countries);

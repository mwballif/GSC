%==============================================================================
% extract_data_LR.m
%
% Purpose: Process one year of the Long Run WIOT into year-level CSV files.
% Reads:   data/raw/LR WIOT <year> tables
% Writes:  per-year CSV files in data/processed/intermediate
%
% NOTE: called with a year argument by createpanels.m, not directly.
%
% Data layout. Columns are interleaved by country. Each country block holds
% J_o intermediate columns followed by F_o final demand columns. The four
% final demand columns are household consumption, government consumption,
% gross fixed capital formation and changes in inventories, in that order.
% xROW is country 26. HKG is country 14 and is folded into ROW.
%
% Output covers 25 countries matching the R16 release:
%   AUS AUT BEL BRA CAN CHN DEU DNK ESP FIN FRA GBR GRC
%   IND IRL ITA JPN KOR MEX NLD PRT SWE TWN USA ROW
%
% ROW is built by summing across its constituent source regions (here HKG
% and xROW), as in a consolidated world IO table, for every quantity in
% this file. A slot with a single constituent region is unaffected.
%
% This file also writes ioMat_LR_<year>.csv, a country by using-sector by
% source-sector table of intermediate input spending (summed across every
% source country), which recover_parameters.m turns into the IO
% coefficients nu. Every other output here collapses the using-sector
% dimension when summing intermediate columns; this one preserves it.
%
% All monetary values are nominal and reported in millions of USD.
%==============================================================================
function extract_data_LR(year)

%% Dimensions
I_o = 26;            % source countries including xROW
I_n = 25;            % output countries after folding HKG into ROW
J_o = 23;            % sectors
F_o = 4;             % final demand categories
C_o = J_o + F_o;     % columns per country block
J_n = 3;             % aggregated sectors

outpath = '../../../data/processed/intermediate/';

%% Load WIOT
WIOT_o = load(strcat('../../../data/processed/intermediate/WIOTLR_', ...
              num2str(year)), 'WIOT_o');
WIOT_o = WIOT_o.WIOT_o;

% Gross output sits in the last column of each producing row. The first
% I_o*J_o rows are the producing country sectors, so G reads directly.
G   = WIOT_o(1:I_o*J_o, end);

% Value added is an accounting row read across the using industry
% columns. Those columns are interleaved, so each country block mixes
% J_o sector columns with F_o final demand columns. sec_cols selects only
% the sector columns from each block and places them in the country major
% order the rest of the function expects.
sec_cols = zeros(1, I_o*J_o);
for i = 1:I_o
    sec_cols((i-1)*J_o + (1:J_o)) = (i-1)*C_o + (1:J_o);
end
VA  = WIOT_o(I_o*J_o + 2, sec_cols)';

%% Sector descriptions
wiotDescription = readtable('../../../data/crosswalks/wiot_sector_description_rev3.csv');

%% Bilateral flows
% For each destination country, sum its intermediate columns and its final
% demand columns to get the flow it buys from every producing row.
M_int = zeros(I_o*J_o, I_o);
M_fin = zeros(I_o*J_o, I_o);

for i = 1:I_o
    lb = (i-1)*C_o + 1;
    ub = (i-1)*C_o + J_o;
    M_int(:,i) = sum(WIOT_o(1:I_o*J_o, lb:ub), 2);

    lf = (i-1)*C_o + J_o + 1;
    uf = i*C_o;
    M_fin(:,i) = sum(WIOT_o(1:I_o*J_o, lf:uf), 2);
end

M_tot = M_int + M_fin;

%% Sector-by-sector intermediate use (for input-output shares nu)
% M_int above sums each buying country's J_o using-sector columns
% together, discarding which sector did the buying. IO_raw(k,l,i) keeps
% that dimension: total spending by buying country i's using sector l on
% goods from producing sector k, summed over every source country.
IO_raw = zeros(J_o, J_o, I_o);
for i = 1:I_o
    lb    = (i-1)*C_o + 1;
    ub    = (i-1)*C_o + J_o;
    block = WIOT_o(1:I_o*J_o, lb:ub);     %(I_o*J_o) rows by J_o using-sector cols
    for h = 1:I_o
        rows_h = (h-1)*J_o + (1:J_o);
        IO_raw(:,:,i) = IO_raw(:,:,i) + block(rows_h,:);
    end
end

%% Sector level trade matrices
% One I_o by I_o matrix per sector. E_temp{j}(d,o) is spending by importer d
% on sector j goods produced by exporter o.
E_temp  = cell(J_o, 1);
GO_temp = cell(J_o, 1);
VA_temp = cell(J_o, 1);

E_aux  = zeros(I_o, I_o);
G_aux  = zeros(I_o, 1);
VA_aux = zeros(I_o, 1);

for j = 1:J_o
    for i = 1:I_o
        E_aux(i,:)  = M_tot(j + (i-1)*J_o, :);
        G_aux(i,1)  = G(j + (i-1)*J_o, 1);
        VA_aux(i,1) = VA(j + (i-1)*J_o, 1);
    end
    E_temp{j}  = E_aux';
    GO_temp{j} = G_aux;
    VA_temp{j} = VA_aux;
end

E  = E_temp;
Y  = GO_temp;
VA = VA_temp;

%% Sector aggregation to 3 sectors (ISIC Rev. 3)
% Sector 1 is agriculture. Sectors 2 to 15 are manufacturing. Sectors 16 to
% 23 are services.
A_sectors = [1];
M_sectors = [2 3 4 5 6 7 8 9 10 11 12 13 14 15];
S_sectors = [16 17 18 19 20 21 22 23];

sectorAggregator    = cell(J_n, 1);
sectorAggregator{1} = A_sectors;
sectorAggregator{2} = M_sectors;
sectorAggregator{3} = S_sectors;

wiotAggregationCodes = zeros(J_o, 1);
for j = 1:J_n
    wiotAggregationCodes(sectorAggregator{j}) = j;
end

E_n  = cell(J_n, 1);
Y_n  = cell(J_n, 1);
VA_n = cell(J_n, 1);

for j = 1:J_n
    tempList = sectorAggregator{j};
    E_n{j}   = zeros(I_o);
    Y_n{j}   = zeros(I_o, 1);
    VA_n{j}  = zeros(I_o, 1);
    for k = 1:length(tempList)
        E_n{j}  = E_n{j}  + E{tempList(k)};
        Y_n{j}  = Y_n{j}  + Y{tempList(k)};
        VA_n{j} = VA_n{j} + VA{tempList(k)};
    end
end

%% Country aggregation to 25 countries
% HKG and xROW both map to output slot 25. Every other country maps once.
% Every output slot is the sum across its constituent source regions, as
% in a consolidated world IO table.
%
% Output order: AUS AUT BEL BRA CAN CHN DEU DNK ESP FIN FRA GBR GRC
%               IND IRL ITA JPN KOR MEX NLD PRT SWE TWN USA ROW
countryAggregator = [ 1  2  3  4  5  6  7  8  9 10 ...
                     11 12 13 25 14 15 16 17 18 19 ...
                     20 21 22 23 24 25];

E_n_agg  = cell(J_n, 1);
Y_n_agg  = cell(J_n, 1);
VA_n_agg = cell(J_n, 1);

for j = 1:J_n
    E_out  = zeros(I_n, I_n);
    Y_out  = zeros(I_n, 1);
    VA_out = zeros(I_n, 1);
    for n = 1:I_n
        rows_n    = find(countryAggregator == n);
        Y_out(n)  = sum(Y_n{j}(rows_n));
        VA_out(n) = sum(VA_n{j}(rows_n));
        for m = 1:I_n
            cols_m = find(countryAggregator == m);
            E_out(n,m) = sum(sum(E_n{j}(rows_n, cols_m)));
        end
    end
    E_n_agg{j}  = E_out;
    Y_n_agg{j}  = Y_out;
    VA_n_agg{j} = VA_out;
end

E_n  = E_n_agg;
Y_n  = Y_n_agg;
VA_n = VA_n_agg;

%% Sector and country aggregation of the IO cube
% Aggregate IO_raw's producing sector k and using sector l to the 3 broad
% sectors, then aggregate its buying country dimension to the 25 output
% countries, both by summing, matching every other quantity in this file.
IO_n3 = zeros(J_n, J_n, I_o);
for m = 1:J_n
    for j = 1:J_n
        IO_n3(m,j,:) = sum(sum(IO_raw(sectorAggregator{m}, sectorAggregator{j}, :), 1), 2);
    end
end

IO_n = zeros(J_n, J_n, I_n);
for n = 1:I_n
    rows_n = find(countryAggregator == n);
    IO_n(:,:,n) = sum(IO_n3(:,:,rows_n), 3);
end

%% Row index
% Maps each producing row to its country and sector over all 26 source
% countries. Used by the final demand based measures below.
dex = 0;
Bindex = zeros(I_o*J_o, 2);
for i = 1:I_o
    for j = 1:J_o
        dex = dex + 1;
        Bindex(dex,:) = [i j];
    end
end

%% Import shares (Eqs 27 and 28)
% Pi_n{j}(i,o) is the share of country i sector j expenditure sourced from o.
% Each row sums to one.
Pi_n = E_n;
for j = 1:J_n
    Pi_n{j} = Pi_n{j} ./ repmat(sum(Pi_n{j}, 2), 1, I_n);
end

piMat = zeros(I_n*I_n*J_n, 5);
dex = 0;
for o = 1:I_n
    for d = 1:I_n
        for k = 1:J_n
            dex = dex + 1;
            piMat(dex,:) = [o d k year Pi_n{k}(d,o)];
        end
    end
end

Tpi = array2table(piMat);
Tpi.Properties.VariableNames = {'Exporter','Importer','Sector','Year','Import_Share'};

%% Bilateral trade flows
% Flow from exporter o to importer d in sector k. The expenditure base is the
% row sum of E_n, equal to total spending by the importer in that sector.
EflowMat = zeros(I_n*I_n*J_n, 5);
dex = 0;
for o = 1:I_n
    for d = 1:I_n
        for k = 1:J_n
            dex = dex + 1;
            EflowMat(dex,:) = [o d k year E_n{k}(d,o)];
        end
    end
end

TEflow = array2table(EflowMat);
TEflow.Properties.VariableNames = {'Exporter','Importer','Sector','Year','Trade_Flow'};

%% Sectoral expenditure, imports and exports (Eq 30)
% Expenditure is total spending by a country in a sector, the row sum of the
% trade matrix. Imports are the part sourced from other countries and exports
% the part sold to other countries, both excluding the domestic diagonal.
EX = zeros(I_n*J_n, 6);
dex = 0;
for i = 1:I_n
    for j = 1:J_n
        dex = dex + 1;
        expend  = sum(E_n{j}(i,:));
        imports = sum(E_n{j}(i,:)) - E_n{j}(i,i);
        exports = sum(E_n{j}(:,i)) - E_n{j}(i,i);
        EX(dex,:) = [i j year expend imports exports];
    end
end

TE = array2table(EX);
TE.Properties.VariableNames = {'Country','Sector','Year','Expenditure','Imports','Exports'};

%% Gross output and value added
GOmat = zeros(I_n*J_n, 4);
VAmat = zeros(I_n*J_n, 4);

dex = 0;
for i = 1:I_n
    for j = 1:J_n
        dex = dex + 1;
        GOmat(dex,:) = [i j year Y_n{j}(i)];
        VAmat(dex,:) = [i j year VA_n{j}(i)];
    end
end

TGO = array2table(GOmat);
TGO.Properties.VariableNames = {'Country','Sector','Year','Gross_Output'};

TVA = array2table(VAmat);
TVA.Properties.VariableNames = {'Country','Sector','Year','Value_Added'};

%% Input-output flows (for IO coefficients nu)
% IO_n(m,j,i) is spending by country i's sector j (buying/using) on goods
% from sector m (source), summed over every source country.
IOmat = zeros(I_n*J_n*J_n, 5);
dex = 0;
for i = 1:I_n
    for j = 1:J_n
        for m = 1:J_n
            dex = dex + 1;
            IOmat(dex,:) = [i j m year IO_n(m,j,i)];
        end
    end
end

TIO = array2table(IOmat);
TIO.Properties.VariableNames = {'Country','Sector','Source_Sector','Year','IO_Flow'};

%% Consumption expenditure (budget constraint, Eq 2)
% Consumption is the sum of the household and government columns, final
% demand columns 1 and 2.
CE_aux1 = zeros(J_o, I_o);
for ii = 1:I_o
    lf      = (ii-1)*C_o + J_o + 1;
    F_block = WIOT_o(1:I_o*J_o, lf:lf+F_o-1);
    CE_aux1(:,ii) = accumarray(Bindex(:,2), sum(F_block(:, 1:2), 2));
end

CE_aux2 = zeros(J_n, I_o);
for j = 1:J_n
    CE_aux2(j,:) = sum(CE_aux1(sectorAggregator{j},:), 1);
end

CE_aux3 = zeros(J_n, I_n);
for j = 1:J_n
    for n = 1:I_n
        cols_n        = find(countryAggregator == n);
        CE_aux3(j,n)  = sum(CE_aux2(j,cols_n));
    end
end

CEMat = zeros(I_n*J_n, 4);
dex = 0;
for i = 1:I_n
    for j = 1:J_n
        dex = dex + 1;
        CEMat(dex,:) = [i j year CE_aux3(j,i)];
    end
end

TCE = array2table(CEMat);
TCE.Properties.VariableNames = {'Country','Sector','Year','Consumption_Expenditure'};

%% Investment expenditure (budget constraint, Eq 2)
% Investment is the sum of the GFCF and inventories columns, final demand
% columns 3 and 4. Flows are grouped by sector and then by output country.
XE_aux1 = zeros(J_o, I_o);
for ii = 1:I_o
    lf      = (ii-1)*C_o + J_o + 1;
    F_block = WIOT_o(1:I_o*J_o, lf:lf+F_o-1);
    XE_aux1(:,ii) = accumarray(Bindex(:,2), sum(F_block(:, 3:4), 2));
end

XE_aux2 = zeros(J_n, I_o);
for j = 1:J_n
    XE_aux2(j,:) = sum(XE_aux1(sectorAggregator{j},:), 1);
end

XE_aux3 = zeros(J_n, I_n);
for j = 1:J_n
    for n = 1:I_n
        cols_n        = find(countryAggregator == n);
        XE_aux3(j,n)  = sum(XE_aux2(j,cols_n));
    end
end

XEMat = zeros(I_n*J_n, 4);
dex = 0;
for i = 1:I_n
    for j = 1:J_n
        dex = dex + 1;
        XEMat(dex,:) = [i j year XE_aux3(j,i)];
    end
end

TXE = array2table(XEMat);
TXE.Properties.VariableNames = {'Country','Sector','Year','Investment_Expenditure'};

%% Country year aggregates
% GDP is value added summed across sectors. Consumption and investment are
% summed across sectors. Exports and imports cover all three sectors,
% since services are treated as tradable, and exclude domestic sales. Net
% exports is exports minus imports; because both totals come from the
% same trade matrix, world exports equal world imports exactly, so world
% net exports sum to zero with no residual forcing needed.
tradable_sectors = [1 2 3];

GDP_agg  = zeros(I_n, 1);
C_agg    = zeros(I_n, 1);
X_agg    = zeros(I_n, 1);
EXP_agg  = zeros(I_n, 1);
IMP_agg  = zeros(I_n, 1);

for i = 1:I_n
    for j = 1:J_n
        GDP_agg(i) = GDP_agg(i) + VA_n{j}(i);
    end
    C_agg(i) = sum(CE_aux3(:, i));
    X_agg(i) = sum(XE_aux3(:, i));
    for j = tradable_sectors
        EXP_agg(i) = EXP_agg(i) + sum(E_n{j}(:, i)) - E_n{j}(i, i);
        IMP_agg(i) = IMP_agg(i) + sum(E_n{j}(i, :)) - E_n{j}(i, i);
    end
end

NX = EXP_agg - IMP_agg;

aggMat = [(1:I_n)', repmat(year, I_n, 1), ...
          GDP_agg, C_agg, X_agg, EXP_agg, IMP_agg];
Tagg = array2table(aggMat);
Tagg.Properties.VariableNames = {'Country','Year','GDP','Total_Consumption', ...
                                  'Total_Investment','Total_Exports','Total_Imports'};

NXmat = [(1:I_n)' repmat(year, I_n, 1) NX];
TNX   = array2table(NXmat);
TNX.Properties.VariableNames = {'Country','Year','NX'};

%% Country and sector metadata
c_names = {'AUS','AUT','BEL','BRA','CAN','CHN','DEU','DNK','ESP','FIN', ...
           'FRA','GBR','GRC','IND','IRL','ITA','JPN','KOR','MEX','NLD', ...
           'PRT','SWE','TWN','USA','ROW'};

CountryName = c_names';
CountryCode = (1:I_n)';
countryAggregation = table(CountryName, CountryCode);
countryAggregation.Properties.VariableNames = {'CountryName','CountryCode'};

wiotDescription = addvars(wiotDescription, wiotAggregationCodes);

%% Write CSVs
ysuf = num2str(year);
writetable(Tpi,               strcat(outpath, 'piMat_LR_',    ysuf, '.csv'))
writetable(TEflow,            strcat(outpath, 'eflowMat_LR_', ysuf, '.csv'))
writetable(TXE,               strcat(outpath, 'xeMat_LR_',    ysuf, '.csv'))
writetable(TCE,               strcat(outpath, 'ceMat_LR_',    ysuf, '.csv'))
writetable(TE,                strcat(outpath, 'exMat_LR_',    ysuf, '.csv'))
writetable(TGO,               strcat(outpath, 'goMat_LR_',    ysuf, '.csv'))
writetable(TVA,               strcat(outpath, 'vaMat_LR_',    ysuf, '.csv'))
writetable(TIO,               strcat(outpath, 'ioMat_LR_',    ysuf, '.csv'))
writetable(TNX,               strcat(outpath, 'nxMat_LR_',    ysuf, '.csv'))
writetable(Tagg,              strcat(outpath, 'aggMat_LR_',   ysuf, '.csv'))
writetable(countryAggregation,strcat(outpath, 'countryAggregation_LR.csv'))
writetable(wiotDescription,   strcat(outpath, 'sectorAggregation_LR.csv'))

end

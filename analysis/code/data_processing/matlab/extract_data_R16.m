%==============================================================================
% extract_data_R16.m
%
% Purpose: Process one year of the 2016 release WIOT into year-level CSV files.
% Reads:   data/raw/WIOT <year> 2016 release tables
% Writes:  per-year CSV files in data/processed/intermediate
%
% NOTE: called with a year argument by createpanels.m, not directly.
%
% Data layout. Intermediates and final demand are stored in separate blocks,
% not interleaved by country.
%   B  intermediate flows,  I_o*J_o by I_o*J_o
%   F  final demand flows,  I_o*J_o by F_o*I_o
%   G  gross output,        I_o*J_o by 1
% Value added is in a trailing accounting row.
%
% The five final demand columns per country are household consumption, NPISH
% consumption, government consumption, gross fixed capital formation and
% changes in inventories, in that order. Consumption is columns 1 to 3 and
% investment is columns 4 to 5.
%
% R16 has 44 regions and 56 sectors. Regions are aggregated to the 25 LR
% countries. The 24 countries common to both releases keep their own slot.
% The remaining regions and the R16 ROW collapse into slot 25.
%
% ROW is built by summing across its constituent source regions, as in a
% consolidated world IO table, for every quantity in this file. A slot
% with a single constituent region is unaffected.
%
% This file also writes ioMat_R16_<year>.csv, a country by using-sector by
% source-sector table of intermediate input spending (summed across every
% source country), which recover_parameters.m turns into the IO
% coefficients nu. Every other output here collapses the using-sector
% dimension when summing intermediate columns; this one preserves it.
%
% All monetary values are nominal and reported in millions of USD.
%==============================================================================
function extract_data_R16(year)

%% Dimensions
I_o = 44;    % source regions
I_n = 25;    % output countries after aggregation
J_o = 56;    % sectors
F_o = 5;     % final demand categories per country
J_n = 3;     % aggregated sectors

outpath = '../../../data/processed/intermediate/';

%% Load WIOT
WIOT_o = load(strcat('../../../data/processed/intermediate/WIOT_', ...
              num2str(year)), 'WIOT_o');
WIOT_o = WIOT_o.WIOT_o;

% B is the intermediate block, F the final demand block, G the gross output
% column. Value added is the third to last row.
B   = WIOT_o(1:I_o*J_o, 1:I_o*J_o);
F   = WIOT_o(1:I_o*J_o, I_o*J_o+1:I_o*J_o+F_o*I_o);
G   = WIOT_o(1:I_o*J_o, I_o*J_o+F_o*I_o+1);
VA  = WIOT_o(end-2, 1:I_o*J_o)';

%% Sector descriptions
wiotDescription = readtable('../../../data/crosswalks/wiot_sector_description_rev4.csv');

%% Bilateral flows
% Intermediate columns come in J_o wide blocks and final demand columns in
% F_o wide blocks. Sum each block to get the flow each country buys.
M_int = zeros(I_o*J_o, I_o);
M_fin = zeros(I_o*J_o, I_o);

for i = 1:I_o
    lb = (i-1)*J_o + 1;
    ub = i*J_o;
    M_int(:,i) = sum(B(:,lb:ub), 2);

    lf = (i-1)*F_o + 1;
    uf = i*F_o;
    M_fin(:,i) = sum(F(:,lf:uf), 2);
end

M_tot = M_int + M_fin;

%% Sector-by-sector intermediate use (for input-output shares nu)
% M_int above sums each buying country's J_o using-sector columns
% together, discarding which sector did the buying. IO_raw(k,l,i) keeps
% that dimension: total spending by buying country i's using sector l on
% goods from producing sector k, summed over every source country.
IO_raw = zeros(J_o, J_o, I_o);
for i = 1:I_o
    lb    = (i-1)*J_o + 1;
    ub    = i*J_o;
    block = B(1:I_o*J_o, lb:ub);          %(I_o*J_o) rows by J_o using-sector cols
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

%% Sector aggregation to 3 sectors (ISIC Rev. 4)
% Sectors 1 to 3 are agriculture, forestry and fishing. Sectors 4 to 26 are
% mining, manufacturing and utilities. Sectors 27 to 56 are construction and
% services. This matches the LR grouping.
A_sectors = [1 2 3];
M_sectors = [4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
S_sectors = [27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 ...
             47 48 49 50 51 52 53 54 55 56];

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
% The source order is AUS AUT BEL BGR BRA CAN CHE CHN CYP CZE DEU DNK ESP EST
% FIN FRA GBR GRC HRV HUN IDN IND IRL ITA JPN KOR LTU LUX LVA MEX MLT NLD NOR
% POL PRT ROU RUS SVK SVN SWE TUR TWN USA ROW. Regions not in LR and the R16
% ROW map to slot 25.
%
% Every output slot is the sum across its constituent source regions, as
% in a consolidated world IO table.
%
% Output order: AUS AUT BEL BRA CAN CHN DEU DNK ESP FIN
%               FRA GBR GRC IND IRL ITA JPN KOR MEX NLD
%               PRT SWE TWN USA ROW
countryAggregator = [ 1  2  3 25  4  5 25  6 25 25 ...
                      7  8  9 25 10 11 12 13 25 25 ...
                     25 14 15 16 17 18 25 25 25 19 ...
                     25 20 25 25 21 25 25 25 25 22 ...
                     25 23 24 25 ];

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
% Maps each source row to its region and sector over all 44 regions. Used by
% the final demand based measures below.
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
% Consumption is the sum of the household, NPISH and government columns, final
% demand columns 1 to 3.
CE = zeros(I_o*J_o, I_o);
for ii = 1:I_o
    lf      = (ii-1)*F_o + 1;
    F_block = F(:, lf:lf+F_o-1);
    CE(:,ii) = sum(F_block(:, 1:3), 2);
end

CE_aux1 = zeros(J_o, I_o);
for ii = 1:I_o
    CE_aux1(:,ii) = accumarray(Bindex(:,2), CE(:,ii));
end

CE_aux2 = zeros(J_n, I_o);
for j = 1:J_n
    CE_aux2(j,:) = sum(CE_aux1(sectorAggregator{j},:));
end

CE_aux3 = zeros(J_n, I_n);
for j = 1:J_n
    for n = 1:I_n
        cols_n       = find(countryAggregator == n);
        CE_aux3(j,n) = sum(CE_aux2(j,cols_n));
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
% columns 4 and 5. Flows are grouped by sector and then by output country.
X = zeros(I_o*J_o, I_o);
for ii = 1:I_o
    lf      = (ii-1)*F_o + 1;
    F_block = F(:, lf:lf+F_o-1);
    X(:,ii) = sum(F_block(:, 4:5), 2);
end

XE_aux1 = zeros(J_o, I_o);
for ii = 1:I_o
    XE_aux1(:,ii) = accumarray(Bindex(:,2), X(:,ii));
end

XE_aux2 = zeros(J_n, I_o);
for j = 1:J_n
    XE_aux2(j,:) = sum(XE_aux1(sectorAggregator{j},:));
end

XE_aux3 = zeros(J_n, I_n);
for j = 1:J_n
    for n = 1:I_n
        cols_n       = find(countryAggregator == n);
        XE_aux3(j,n) = sum(XE_aux2(j,cols_n));
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
           'FRA','GBR','GRC','IND','IRL','ITA','JPN','KOR','MEX', ...
           'NLD','PRT','SWE','TWN','USA','ROW'};

CountryName = c_names';
CountryCode = (1:I_n)';
countryAggregation = table(CountryName, CountryCode);
countryAggregation.Properties.VariableNames = {'CountryName','CountryCode'};

wiotDescription = addvars(wiotDescription, wiotAggregationCodes);

%% Write CSVs
ysuf = num2str(year);
writetable(Tpi,               strcat(outpath, 'piMat_R16_',    ysuf, '.csv'))
writetable(TEflow,            strcat(outpath, 'eflowMat_R16_', ysuf, '.csv'))
writetable(TXE,               strcat(outpath, 'xeMat_R16_',    ysuf, '.csv'))
writetable(TCE,               strcat(outpath, 'ceMat_R16_',    ysuf, '.csv'))
writetable(TE,                strcat(outpath, 'exMat_R16_',    ysuf, '.csv'))
writetable(TGO,               strcat(outpath, 'goMat_R16_',    ysuf, '.csv'))
writetable(TVA,               strcat(outpath, 'vaMat_R16_',    ysuf, '.csv'))
writetable(TIO,               strcat(outpath, 'ioMat_R16_',    ysuf, '.csv'))
writetable(TNX,               strcat(outpath, 'nxMat_R16_',    ysuf, '.csv'))
writetable(Tagg,              strcat(outpath, 'aggMat_R16_',   ysuf, '.csv'))
writetable(countryAggregation,strcat(outpath, 'countryAggregation_R16.csv'))
writetable(wiotDescription,   strcat(outpath, 'sectorAggregation_R16.csv'))

end

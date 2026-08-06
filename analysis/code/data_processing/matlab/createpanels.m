%==============================================================================
% createpanels.m
%
% Purpose: Build the four panels spanning 1965-2014. Runs the two extract
%          functions for every year, then stacks the year files.
% Reads:   data/processed/intermediate/WIOT*.mat
% Writes:  data/processed/panel_A.csv through panel_D.csv
%
% Sources:
%   LR  Long Run release,  1965 to 2000, ISIC Rev.3
%   R16 2016 release,      2000 to 2014, ISIC Rev.4
%
% The year 2000 appears in both releases, so each panel has two rows for
% 2000 distinguished by the source flag. The source flag is 0 for LR rows
% and 1 for R16 rows.
%
% Output panels:
%   panel_A.csv  country by year aggregates.
%   panel_B.csv  country by sector by year variables.
%   panel_C.csv  importer by exporter by sector by year shares and flows.
%   panel_D.csv  country by using-sector by source-sector by year
%                intermediate input spending, for the IO coefficients nu.
%==============================================================================

outpath_data   = '../../../data/processed/intermediate/';
outpath_panels = '../../../data/processed/';

%% Run the extract functions for every year
fprintf('--- Extracting LR years (1965 to 2000) ---\n')
for t = 1965:2000
    fprintf('  LR  year %d\n', t)
    extract_data_LR(t)
end

fprintf('--- Extracting R16 years (2000 to 2014) ---\n')
for t = 2000:2014
    fprintf('  R16 year %d\n', t)
    extract_data_R16(t)
end

fprintf('--- Stacking panels ---\n')

%% Panel A: country by year aggregates
% Columns: country, year, gdp, tot_consump, tot_invest, tot_exp, tot_imp,
%          source.
aggMat_LR  = stack_years('aggMat_LR_',  1965, 2000, outpath_data, 0);
aggMat_R16 = stack_years('aggMat_R16_', 2000, 2014, outpath_data, 1);
aggMat_panel = [aggMat_LR; aggMat_R16];

T_A = array2table(aggMat_panel);
T_A.Properties.VariableNames = {'country','year','gdp','tot_consump', ...
                                  'tot_invest','tot_exp','tot_imp', ...
                                  'source'};
writetable(T_A, strcat(outpath_panels, 'panel_A.csv'))
fprintf('  panel_A.csv written  (%d rows)\n', height(T_A))

%% Panel B: country by sector by year
% Columns: country, sector, year, go, va, expend, imports, exports,
%          consump, invest, nx, source.
% Net exports are a country by year series, joined on country and year so
% every panel B row carries the value.
goMat_LR  = stack_years('goMat_LR_',  1965, 2000, outpath_data, 0);
goMat_R16 = stack_years('goMat_R16_', 2000, 2014, outpath_data, 1);

vaMat_LR  = stack_years('vaMat_LR_',  1965, 2000, outpath_data, 0);
vaMat_R16 = stack_years('vaMat_R16_', 2000, 2014, outpath_data, 1);

exMat_LR  = stack_years('exMat_LR_',  1965, 2000, outpath_data, 0);
exMat_R16 = stack_years('exMat_R16_', 2000, 2014, outpath_data, 1);

ceMat_LR  = stack_years('ceMat_LR_',  1965, 2000, outpath_data, 0);
ceMat_R16 = stack_years('ceMat_R16_', 2000, 2014, outpath_data, 1);

xeMat_LR  = stack_years('xeMat_LR_',  1965, 2000, outpath_data, 0);
xeMat_R16 = stack_years('xeMat_R16_', 2000, 2014, outpath_data, 1);

nxMat_LR  = stack_years('nxMat_LR_',  1965, 2000, outpath_data, 0);
nxMat_R16 = stack_years('nxMat_R16_', 2000, 2014, outpath_data, 1);

go_panel   = [goMat_LR;    goMat_R16];
va_panel   = [vaMat_LR;    vaMat_R16];
ex_panel   = [exMat_LR;    exMat_R16];
ce_panel   = [ceMat_LR;    ceMat_R16];
xe_panel   = [xeMat_LR;    xeMat_R16];
nx_panel   = [nxMat_LR;    nxMat_R16];

% Look up net exports for each row by matching country, year and source.
% Matching the source flag matters because year 2000 appears in both
% releases; without it every R16 year 2000 row picks up the LR value.
n_B  = size(go_panel, 1);
NX_B = zeros(n_B, 1);
for r = 1:n_B
    ctry = go_panel(r, 1);
    yr   = go_panel(r, 3);
    src  = go_panel(r, 5);
    idx  = find(nx_panel(:,1) == ctry & nx_panel(:,2) == yr & nx_panel(:,4) == src, 1);
    if ~isempty(idx)
        NX_B(r) = nx_panel(idx, 3);
    end
end

B_mat = [go_panel(:,1:3), go_panel(:,4), va_panel(:,4), ...
         ex_panel(:,4),   ex_panel(:,5), ex_panel(:,6), ...
         ce_panel(:,4),   xe_panel(:,4), NX_B, go_panel(:,5)];

T_B = array2table(B_mat);
T_B.Properties.VariableNames = {'country','sector','year', ...
    'go','va', ...
    'expend','imports','exports','consump','invest', ...
    'nx','source'};
writetable(T_B, strcat(outpath_panels, 'panel_B.csv'))
fprintf('  panel_B.csv written  (%d rows)\n', height(T_B))

%% Panel C: importer by exporter by sector by year
% Columns: exporter, importer, sector, year, imp_sh, trade_flow, source.
piMat_LR  = stack_years('piMat_LR_',     1965, 2000, outpath_data, 0);
piMat_R16 = stack_years('piMat_R16_',    2000, 2014, outpath_data, 1);

eflowMat_LR  = stack_years('eflowMat_LR_',  1965, 2000, outpath_data, 0);
eflowMat_R16 = stack_years('eflowMat_R16_', 2000, 2014, outpath_data, 1);

pi_panel    = [piMat_LR;    piMat_R16];
eflow_panel = [eflowMat_LR; eflowMat_R16];

C_mat = [pi_panel(:,1:5), eflow_panel(:,5), pi_panel(:,6)];

T_C = array2table(C_mat);
T_C.Properties.VariableNames = {'exporter','importer','sector','year', ...
    'imp_sh','trade_flow','source'};
writetable(T_C, strcat(outpath_panels, 'panel_C.csv'))
fprintf('  panel_C.csv written  (%d rows)\n', height(T_C))

%% Panel D: country by using-sector by source-sector by year
% Columns: country, sector, source_sector, year, io_flow, source.
ioMat_LR  = stack_years('ioMat_LR_',  1965, 2000, outpath_data, 0);
ioMat_R16 = stack_years('ioMat_R16_', 2000, 2014, outpath_data, 1);
io_panel  = [ioMat_LR; ioMat_R16];

T_D = array2table(io_panel);
T_D.Properties.VariableNames = {'country','sector','source_sector','year', ...
    'io_flow','source'};
writetable(T_D, strcat(outpath_panels, 'panel_D.csv'))
fprintf('  panel_D.csv written  (%d rows)\n', height(T_D))

fprintf('--- Done. Panels written to %s ---\n', outpath_panels)


%==============================================================================
% stack_years(prefix, yr_start, yr_end, datapath, flag)
%
% Reads the per year CSV files, stacks them into one matrix and appends the
% source flag as a final column.
%
% Inputs:
%   prefix    file name prefix, for example 'piMat_LR_'.
%   yr_start  first year to read.
%   yr_end    last year to read.
%   datapath  folder holding the year files.
%   flag      scalar appended as the last column, 0 for LR and 1 for R16.
%
% Output:
%   M  stacked numeric matrix with the flag column appended.
%==============================================================================
function M = stack_years(prefix, yr_start, yr_end, datapath, flag)

M = [];

for t = yr_start:yr_end
    fname  = strcat(datapath, prefix, num2str(t), '.csv');
    T_year = readtable(fname);
    M_year = table2array(T_year);
    M_year = [M_year, repmat(flag, size(M_year,1), 1)];
    M = [M; M_year];
end

end

%==============================================================================
% createWIOTmat.m
%
% Purpose: Save the 2016 release WIOT spreadsheets (2000-2014) as .mat files.
% Reads:   data/raw/WIOT<year>_Nov16_ROW.xlsx
% Writes:  data/raw/intermediate/WIOT_<year>.mat
%
% NOTE: dead code, superseded by process_raw_data.m. Safe to delete.
%==============================================================================

clearvars

% Read each year's table and save it.
for t = 2000:2014
    strxls = strcat('../../../data/raw/WIOT', num2str(t), '_Nov16_ROW.xlsx');
    WIOT_o = readmatrix(strxls, 'Range', 'e7:cyk2478');
    strmat = strcat('../../../data/raw/intermediate/WIOT_', num2str(t));
    save(strmat, 'WIOT_o');
end

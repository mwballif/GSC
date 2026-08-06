%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% createWIOTmat.m
%
% Reads the 2016 release WIOT spreadsheets (2000 to 2014) and saves each
% one as a .mat file. Superseded by process_raw_data.m, which also handles
% the Long Run tables and non Windows systems.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clearvars
for t = 2000:2014
    strxls = strcat('../../../data/raw/WIOT', num2str(t), '_Nov16_ROW.xlsx');
    WIOT_o = readmatrix(strxls, 'Range', 'e7:cyk2478');
    strmat = strcat('../../../data/raw/intermediate/WIOT_', num2str(t));
    save(strmat, 'WIOT_o');
end

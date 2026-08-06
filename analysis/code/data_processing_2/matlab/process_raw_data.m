%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% process_raw_data.m
%
% Converts the raw WIOT spreadsheets into .mat files used by the extract
% functions. The 2016 release tables (2000 to 2014) are saved as
% WIOT_<year> and the Long Run tables (1965 to 2000) as WIOTLR_<year>,
% both in data/processed_2/intermediate.
%
% Cross platform note. The 2016 release ships as .xlsb workbooks, which
% readmatrix can only open on Windows (it goes through Excel's COM
% interface there). On Mac and Linux this script instead reads an .xlsx
% copy of each workbook, converting the .xlsb once if the copy does not
% exist yet. On Mac the conversion drives Excel through AppleScript, so
% Excel opens briefly per file and macOS may show a one time automation
% permission prompt. LibreOffice (soffice) is the fallback converter if
% Excel is not installed.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create matrices for 2016 Release
clearvars
for t=2000:2014
    strxls = strcat('../../../data/raw/WIOT',num2str(t),'_Nov16_ROW.xlsb');
    if ~ispc
        % readmatrix cannot open .xlsb outside Windows, so read an .xlsx
        % copy instead, converting it from the .xlsb if needed.
        strxls = xlsb_to_xlsx(strxls);
    end
    WIOT_o = readmatrix(strxls,'Range','E7:CYK2478');
    strmat = strcat('../../../data/processed_2/intermediate/WIOT_',num2str(t));
    save(strmat);
end

%%  Create matrices for Long Run Data
rows_per_year = 606
for t = 1965:2000
    yr_idx = t-1965
    row_start = 2 + yr_idx * rows_per_year;
    row_end   = row_start + rows_per_year -1;

    range_str = sprintf('D%d: AAG%d', row_start, row_end);
    WIOT_o = readmatrix('../../../data/raw/lr_wiod_wiot_wide.xlsx', 'Range', range_str);

    strmat = strcat('../../../data/processed_2/intermediate/WIOTLR_',num2str(t));
    save(strmat, 'WIOT_o')
end

%% Read in Long Run WIOT
T = readtable('../../../data/raw/lr_wiod_wiot_wide.xlsx', 'Sheet', 'data')

for t= 1965:2000
    T_year = T(T.year == t, :);
    WIOT_o = table2array(T_year(:, 4:end)) ;
    strmat = strcat('../../../data/processed_2/intermediate/WIOTLR_',num2str(t));
    save(strmat, 'WIOT_o')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% xlsb_to_xlsx(strxlsb)
%
% Returns the path of an .xlsx copy of the given .xlsb workbook, creating
% it if it does not exist yet. On Mac it drives Excel through AppleScript,
% falling back to LibreOffice (soffice) if Excel is not installed.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function strxlsx = xlsb_to_xlsx(strxlsb)

[fdir, fname, ~] = fileparts(strxlsb);
strxlsx = fullfile(fdir, strcat(fname, '.xlsx'));

if isfile(strxlsx)
    return
end

if ~isfile(strxlsb)
    error('Raw file not found: %s', strxlsb)
end

fprintf('Converting %s to xlsx ...\n', strxlsb)

% Excel and LibreOffice need absolute paths without .. segments, which
% AppleScript's POSIX file does not resolve.
absxlsb = char(java.io.File(strxlsb).getCanonicalPath());
absxlsx = char(java.io.File(strxlsx).getCanonicalPath());
absdir  = char(java.io.File(fdir).getCanonicalPath());

if ismac && isfolder('/Applications/Microsoft Excel.app')
    script = sprintf([ ...
        'with timeout of 600 seconds\n' ...
        'tell application "Microsoft Excel"\n' ...
        '    set display alerts to false\n' ...
        '    open workbook workbook file name (POSIX file "%s")\n' ...
        '    set wb to active workbook\n' ...
        '    save workbook as wb filename (POSIX file "%s") ' ...
                 'file format Excel XML file format with overwrite\n' ...
        '    close wb saving no\n' ...
        'end tell\n' ...
        'end timeout'], absxlsb, absxlsx);
    [status, out] = system(sprintf('osascript -e ''%s''', script));
else
    soffice = find_soffice();
    [status, out] = system(sprintf( ...
        '"%s" --headless --convert-to xlsx --outdir "%s" "%s"', ...
        soffice, absdir, absxlsb));
end

if status ~= 0 || ~isfile(strxlsx)
    error(['Conversion of %s failed:\n%s\n' ...
           'Convert the file to .xlsx manually in Excel and rerun.'], ...
          strxlsb, out)
end

end

function soffice = find_soffice()

candidates = {'/Applications/LibreOffice.app/Contents/MacOS/soffice', ...
              '/usr/bin/soffice', '/usr/local/bin/soffice', ...
              '/opt/homebrew/bin/soffice'};
for k = 1:numel(candidates)
    if isfile(candidates{k})
        soffice = candidates{k};
        return
    end
end

[status, out] = system('which soffice');
if status == 0
    soffice = strtrim(out);
    return
end

error(['No converter found for .xlsb files. Install Microsoft Excel or ' ...
       'LibreOffice (brew install --cask libreoffice), or convert the ' ...
       'WIOT .xlsb files to .xlsx manually.'])
end
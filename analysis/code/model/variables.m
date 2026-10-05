function V = variables

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Names the countries and sectors and fixes their index positions.
%  Every other file refers to them by name, never by number.
%
%  Inputs:  none
%  Output:  V
%
%==============================================================================

% - countries and sectors - %
V.countries = {'USA'         %1  United States
               'ROW'         %2  Rest of world
               };
V.ncty = length(V.countries);

V.sectors = { 'AGR'          %1  Agriculture
              'MAN'          %2  Manufacturing
              'SER'          %3  Services
              };             % All three are tradable
V.nsec = length(V.sectors);

% - index for each name, so the code says V.USA and V.MAN, not 1 and 2 - %
for i = 1:V.ncty
    V.(V.countries{i}) = i;
end
for j = 1:V.nsec
    V.(V.sectors{j}) = j;
end

% - slots for the market clearing system, step 9 of static.m - %
	% country-sector pairs in one vector, sector major %
V.nslot = V.nsec*V.ncty;
V.slot = zeros(V.nsec,V.ncty);
for j = 1:V.nsec
    for i = 1:V.ncty
        V.slot(j,i) = (j-1)*V.ncty + i;
    end
end

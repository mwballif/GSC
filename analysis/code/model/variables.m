function V = variables

% variables: Names the countries and sectors and fixes their index positions.
% Every other file refers to them through this structure, never by number.
% Inputs:  none.
% Output:  V (structure of names and index locations).

%---------------------------------------------
%   1. Countries and sectors
%---------------------------------------------
V.countries = {'USA'         %1  United States
               'ROW'         %2  Rest of world
               };
V.ncty = length(V.countries);

V.sectors = { 'AGR'          %1  Agriculture
              'MAN'          %2  Manufacturing
              'SER'          %3  Services
              };             % All three are tradable
V.nsec = length(V.sectors);

%---------------------------------------------
%   2. Index for each name
%---------------------------------------------
% So the code can say V.USA and V.MAN instead of 1 and 2.
for i = 1:V.ncty
    V.(V.countries{i}) = i;
end
for j = 1:V.nsec
    V.(V.sectors{j}) = j;
end

%---------------------------------------------
%   3. Slots for the market clearing system
%---------------------------------------------
% Six country-sector pairs in one vector, sector major and country minor.
V.nslot = V.nsec*V.ncty;
V.slot = zeros(V.nsec,V.ncty);
for j = 1:V.nsec
    for i = 1:V.ncty
        V.slot(j,i) = (j-1)*V.ncty + i;
    end
end

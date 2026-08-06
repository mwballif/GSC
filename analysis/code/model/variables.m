function V = variables

% Variables: Names countries, sectors and slots, and assigns locations
% Output:
%     V     :   Structure of variable locations and names

% Countries
V.countries = {'USA'        %1  United States
               'ROW'        %2  Rest of world
               };
V.ncty = length(V.countries);

% Sectors, all tradable
V.sectors = { 'AGR'         %1  Agriculture
              'MAN'         %2  Manufacturing
              'SER'         %3  Services
              };
V.nsec = length(V.sectors);

% The outcome variable
V.outsec = 'MAN';
V.outcty = 'USA';

% Establish country and sector index
for i = 1:V.ncty
    V.(V.countries{i}) = i;
end
for j = 1:V.nsec
    V.(V.sectors{j}) = j;
end

% Shocked country, and the country whose income is the numeraire
V.ihome = V.(V.outcty);
V.iforeign = 3 - V.ihome;

% Six slots, sector major and country minor: (a,US) (a,R) (m,US) (m,R) (s,US) (s,R)
V.nslot = V.nsec*V.ncty;
V.slot = zeros(V.nsec,V.ncty);
for j = 1:V.nsec
    for i = 1:V.ncty
        V.slot(j,i) = (j-1)*V.ncty + i;
    end
end

function D = padyears(P,V,D)

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Extends the data to the horizon, the T >> T^W assumption of Section 1.
%  Every padded year repeats the last data year, with an Euler wedge of one and
%  no growth in the investment tax, which is what the steady state needs.
%  (note: what repeats is the base year the hats are taken against, not the
%  solution)
%
%  Inputs:  P, V, D
%  Output:  D (extended through P.ssyear)
%
%==============================================================================

td = D.Tdata;
H  = P.ssyear - D.years(td);
if H < 0
    error('padyears: the steady state year %d is before the last data year %d', ...
          P.ssyear,D.years(td))
end
if H == 0, return, end

% - fundamentals, held at the last data year - %
D.years = [D.years(:); D.years(end)+(1:H)'];
D.NX    = [D.NX,  repmat(D.NX(:,td), 1,H)];
D.L     = [D.L,   repmat(D.L(:,td),  1,H)];
D.gdp   = [D.gdp, repmat(D.gdp(:,td),1,H)];
D.PX    = [D.PX,  repmat(D.PX(:,td), 1,H)];
D.EX    = [D.EX,  repmat(D.EX(:,td), 1,H)];

D.Y     = cat(3,D.Y,    repmat(D.Y(:,:,td),    [1 1 H]));
D.E     = cat(3,D.E,    repmat(D.E(:,:,td),    [1 1 H]));
D.P0    = cat(3,D.P0,   repmat(D.P0(:,:,td),   [1 1 H]));
D.mux   = cat(3,D.mux,  repmat(D.mux(:,:,td),  [1 1 H]));
D.T_lvl = cat(3,D.T_lvl,repmat(D.T_lvl(:,:,td),[1 1 H]));
D.c0    = cat(3,D.c0,   repmat(D.c0(:,:,td),   [1 1 H]));
D.muc   = cat(3,D.muc,  repmat(D.muc(:,:,td),  [1 1 H]));

D.pi    = cat(4,D.pi, repmat(D.pi(:,:,:,td), [1 1 1 H]));
D.tau   = cat(4,D.tau,repmat(D.tau(:,:,:,td),[1 1 1 H]));

	% the base stock too %
D.K = [D.K(:,1:td), repmat(D.K(:,td),1,H+1)];

% - wedges, at their steady state values - %
	% wedge one and no growth in chi %
D.wedge  = [D.wedge,  ones(V.ncty,H)];
D.chirat = [D.chirat, ones(V.ncty,H)];

	% no data behind these, so leave them empty %
D.bond0 = [D.bond0, NaN(V.ncty,H)];
D.phi   = [D.phi,   NaN(V.ncty,H)];

% - horizon - %
D.T = td + H;

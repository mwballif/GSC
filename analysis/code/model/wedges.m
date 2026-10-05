function W = wedges(D,P,varargin)

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  The wedge paths one run is solved at. Section 1 takes these as given and
%  holds them unchanged after the last data year. Default is the data; any
%  named wedge is frozen at P.freezeyear instead, which is what a
%  counterfactual is.
%
%  Names: tau (trade costs), T (productivity), muc (consumption shifters),
%         mux (investment shifters), friction (the Euler wedge), chi (the
%         investment tax)
%
%  Inputs:  D (the data, padded), P, varargin (wedges to freeze)
%  Output:  W (the run's wedge paths)
%
%==============================================================================

% - the data path - %
W.tau      = D.tau;
W.T_lvl    = D.T_lvl;
W.muc      = D.muc;
W.mux      = D.mux;
W.friction = D.wedge;
W.chirat   = D.chirat;
W.name     = 'data';

if isempty(varargin), return, end

% - freeze the named ones at the freeze year - %
	% the wedge is held at its freeze-year value for every later year %
k0 = find(D.years == P.freezeyear,1);
if isempty(k0)
    error('wedges: %d is not in the sample',P.freezeyear)
end

for q = 1:numel(varargin)
    switch varargin{q}
        case 'tau'
            W.tau   = repmat(D.tau(:,:,:,k0),[1 1 1 D.T]);
        case 'T'
            W.T_lvl = repmat(D.T_lvl(:,:,k0),[1 1 D.T]);
        case 'muc'
            W.muc   = repmat(D.muc(:,:,k0),[1 1 D.T]);
        case 'mux'
            W.mux   = repmat(D.mux(:,:,k0),[1 1 D.T]);

	% these two are dated t to t+1, so neutral means one %
        case 'friction'
            W.friction = ones(size(D.wedge));
        case 'chi'
            W.chirat   = ones(size(D.chirat));
        otherwise
            error('wedges: %s is not a wedge',varargin{q})
    end
end

W.name = sprintf('%s frozen at %d',strjoin(varargin,', '),P.freezeyear);

function B = baseline(P,V,D)

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  What the data implies, read off the Section 3 equations.
%  These are the levels the hats in static.m are taken against.
%
%  Inputs:  P, V, D (padded)
%  Output:  B (baseline series)
%
%==============================================================================

% - value added and its uses - %
	% consumption, from the budget constraint %
B.VA = squeeze(sum(bsxfun(@times,D.beta,D.Y),1));
B.EC = B.VA - D.EX - D.NX;

% - final demand shares - %
	% investment shares at the data, consumption as the residual %
B.xs = zeros(V.nsec,V.ncty,D.T);
B.s  = zeros(V.nsec,V.ncty,D.T);
for t = 1:D.T
    for i = 1:V.ncty
        B.xs(:,i,t) = D.mux(:,i,t).*(D.P0(:,i,t)/D.PX(i,t)).^(1-P.zeta);
        interm = D.nu(:,:,i)'*((1-D.beta(:,i)).*D.Y(:,i,t));
        B.s(:,i,t) = (D.E(:,i,t) - interm - B.xs(:,i,t)*D.EX(i,t))/B.EC(i,t);
    end
end

% - capital; X is local, only the check below uses it - %
X   = D.K(:,2:end) - (1-P.d)*D.K(:,1:end-1);

	% (note: r K = varphi VA; see static.m step 1) %
B.r = bsxfun(@times,D.varphi,B.VA)./D.K(:,1:end-1);

% - the price normalization, sum_i E^C_i = 1 - %
	% B.lam takes a data level into model units, B.eUS is the model's E^C_US %
B.lam = 1./sum(B.EC,1);
B.eUS = B.EC(V.USA,:).*B.lam;

% - bonds - %
	% W_0 = R_0 B_0, the wealth step 2 takes as given %
B.W0 = (D.bond0(:,1) - D.NX(:,1))*B.lam(1);

% - checks, on the data years only - %
	% data years only %
d = 1:D.Tdata;
B.chks = max(abs(sum(B.s(:,:,d),1)-1),[],'all');
B.chkx = max(abs(sum(B.xs(:,:,d),1)-1),[],'all');
tmp = abs(D.PX(:,d(1:end-1)).*X(:,d(1:end-1))./D.EX(:,d(1:end-1)) - 1);
B.chkX = max(tmp(:));

	% (note: an identity, since phi is a residual) %
d = 1:D.Tdata-1;
B.chkw = max(abs(1 + D.phi(:,d).*(D.bond0(:,d)-P.Bbar) - D.wedge(:,d)),[],'all');

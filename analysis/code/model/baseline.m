function B = baseline(P,V,D)

% baseline: Computes what the data implies.
% Reads value added, its uses and the final demand shares off the static
% problem's own equations. These are the levels the solve starts from.
% Inputs:  P (parameters), V (variable locations), D (the data).
% Output:  B (structure of baseline series).

%---------------------------------------------
%   1. Value added and its uses
%---------------------------------------------
% Consumption is what is left of value added after investment and net exports.
B.VA = squeeze(sum(bsxfun(@times,D.beta,D.Y),1));
B.EC = B.VA - D.EX - D.NX;

%---------------------------------------------
%   2. Final demand shares
%---------------------------------------------
% The investment share is the demand system at the data. Consumption is the
% residual use of each sector's output.
B.xs = zeros(V.nsec,V.ncty,D.T);
B.s  = zeros(V.nsec,V.ncty,D.T);
for t = 1:D.T
    for i = 1:V.ncty
        B.xs(:,i,t) = D.mux(:,i,t).*(D.P0(:,i,t)/D.PX(i,t)).^(1-P.zeta);
        interm = D.nu(:,:,i)'*((1-D.beta(:,i)).*D.Y(:,i,t));
        B.s(:,i,t) = (D.E(:,i,t) - interm - B.xs(:,i,t)*D.EX(i,t))/B.EC(i,t);
    end
end

% How much consumption a dollar buys, the term the consumption Euler needs.
B.phitilde = 1./squeeze(sum(bsxfun(@times,P.eps,B.s),1));

%---------------------------------------------
%   3. Capital
%---------------------------------------------
B.X = D.K(:,2:end) - (1-P.d)*D.K(:,1:end-1);
B.r = bsxfun(@times,D.varphi,B.VA)./D.K(:,1:end-1);

%---------------------------------------------
%   4. Checks
%---------------------------------------------
% Shares add to one, and investment is its price times its quantity. The last
% column is left out: no investment series stands behind it.
B.chks = max(abs(sum(B.s,1)-1),[],'all');
B.chkx = max(abs(sum(B.xs,1)-1),[],'all');
tmp = abs(D.PX(:,1:end-1).*B.X(:,1:end-1)./D.EX(:,1:end-1) - 1);
B.chkX = max(tmp(:));

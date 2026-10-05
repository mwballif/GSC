function out = dynamic(W,S,P,V,D,B)

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Equilibrium transition, in the steps of Section 1, Step 2.
% 
%
%  Inputs:  W (the run's wedges, from wedges.m), S (terminal steady state),
%           P, V, D, B
%  Output:  out (the solved paths)
%
%==============================================================================

T  = D.T;
nK = V.ncty*(T-2);
n  = nK + (T-1);

% - step 2.1: - %

	% the data over the sample, a line onto the steady state after it %
td = D.Tdata;
Kg = D.K(:,1:T);
eg = B.eUS(1:T)';
for i = 1:V.ncty
    Kg(i,td:T) = linspace(D.K(i,td),S.K(i),T-td+1);
end
eg(td:T) = linspace(B.eUS(td),S.eUS,T-td+1);

	% pack, and one scale per unknown in its own units %
z  = pack(Kg,eg,D);
sc = abs(z);  sc(sc == 0) = 1;

	% which years each unknown moves %
tof = cell(n,1);
for c = 1:T-2
    for i = 1:V.ncty
        tof{(c-1)*V.ncty+i} = [c c+1];
    end
end
for m = 1:T-1, tof{nK+m} = m; end

% - step 2.4c: Newton on the two Euler equations - %

	% solve every year at the guess, and score it %
Y   = years(z,[],[],W,S,P,V,D,B);
res = check(z,Y,W,S,P,V,D,B);
for iter = 1:P.maxpath
    fprintf('  iteration %d, max residual %.2e\n',iter-1,max(abs(res)));
    if max(abs(res)) < P.tolpath, break, end

    % Jacobian a column at a time %
    J = zeros(n);
    for k = 1:n
        zk = z;  zk(k) = z(k) + P.fdstep*sc(k);
        Yk = years(zk,Y,tof{k},W,S,P,V,D,B);   % only tof{k} is re-solved
        J(:,k) = (check(zk,Yk,W,S,P,V,D,B) - res)/P.fdstep;
    end

    % Newton step, then a backtracking line search on the norm %
    dz = -(J\res);
    lam = 1;  ok = false;
    for ls = 1:25
        ztry = z + lam*sc.*dz;
        Ytry = years(ztry,[],[],W,S,P,V,D,B);
        rtry = check(ztry,Ytry,W,S,P,V,D,B);
        if norm(rtry) < norm(res), ok = true; break, end
        lam = lam/2;
    end
    if ~ok, fprintf('  no downhill step found; stopping\n'); break, end
    z = ztry;  res = rtry;  Y = Ytry;
    fprintf('  step %.4f\n',lam);
end

[~,out] = check(z,Y,W,S,P,V,D,B);
out.iter = iter;

end


function z = pack(K,e,D)

% pack: the free part of the paths, in one vector
%  Inputs:  K, e (US share of world consumption expenditure), D
%  Output:  z (the unknowns)
T = D.T;
z = [reshape(K(:,2:T-1),[],1); e(1:T-1)];

end


function [K,e] = unpack(z,S,V,D)

% unpack: splits z back into the paths and adds what step 2.1 pins, K_0 from the
% data and K_T, E^C_T from the steady state. K gets an extra column so that
% investment is defined in the last period.
%  Inputs:  z, S, V, D
%  Outputs: K (ncty by T+1), e (T by 1)
T = D.T;
K = [D.K(:,1), reshape(z(1:V.ncty*(T-2)),V.ncty,T-2), S.K, S.K];
e = [z(V.ncty*(T-2)+1:end); S.eUS];

end


function Y = years(z,Y,tlist,W,S,P,V,D,B)

% years: step 2.2, the static block year by year. Re-solves only tlist when a
% previous Y is passed, warm-starting each wage search from its last solution.
%  Inputs:  z, Y (previous, or empty), tlist, W, S, P, V, D, B
%  Output:  Y (each year)

[K,e] = unpack(z,S,V,D);
if isempty(Y)
    Y.NX = zeros(V.ncty,D.T);   Y.EC = zeros(V.ncty,D.T);
    Y.PX = zeros(V.ncty,D.T);   Y.r  = zeros(V.ncty,D.T);
    Y.VA = zeros(V.ncty,D.T);   Y.w  = zeros(V.ncty,D.T);
    Y.phitilde = zeros(V.ncty,D.T);
    Y.lw = zeros(D.T,1);        Y.g  = zeros(D.T,1);
    Y.Y  = zeros(V.nsec,V.ncty,D.T);
    Y.s  = zeros(V.nsec,V.ncty,D.T);
    tlist = 1:D.T;
end
for t = tlist(:)'
    o = static(t,struct('EC',e(t)),K(:,t:t+1),W,P,V,D,B,Y.lw(t));
    Y.lw(t)       = o.lw;
    Y.g(t)        = o.g;
    Y.NX(:,t)     = o.NX;
    Y.EC(:,t)     = o.EC;
    Y.PX(:,t)     = o.PX;
    Y.r(:,t)      = o.r;
    Y.VA(:,t)     = o.VA;
    Y.w(:,t)      = o.w;
    Y.phitilde(:,t) = o.phitilde;
    Y.Y(:,:,t)    = o.Y;
    Y.s(:,:,t)    = o.snew;
end

end


function [res,out] = check(z,Y,W,S,P,V,D,B)

% check: steps 2.3 to 2.4c. Net exports, bonds and the interest rate, then the
% two Euler residuals. One bond Euler and two capital Eulers a year, less the two
% the terminal capital stock replaces, so residuals match unknowns.
%  Inputs:  z, Y (each year), W, S, P, V, D, B
%  Outputs: res, out (the paths)

T = D.T;
[K,e] = unpack(z,S,V,D);

% - the Euler wedge, recovered through the sample and one after it - %
wdg = W.friction;

% - what E^C grows by per unit of delta*R, per worker - %
	% (note: EQconditions.tex writes the bond Euler in totals) %
Lr = D.L(:,2:T)./D.L(:,1:T-1);
a  = Lr.*(Y.phitilde(:,2:T)./Y.phitilde(:,1:T-1))./wdg;

% - E^C by country, adding to one - %
eall = zeros(V.ncty,T);
eall(V.USA,:) = e(:)';
eall(V.ROW,:) = 1-e(:)';

% - step 2.4b: the interest rate - %
R = nan(T,1);
R(2:T) = 1./(P.delta*sum(a.*eall(:,1:T-1),1)');   % the two Eulers, added

% - step 2.4c: bond Euler, for the US - %
resB = log(e(2:T)./e(1:T-1)) - log(a(V.USA,:)') - log(P.delta*R(2:T));

% - step 2.4c: capital Euler, over P^X to make the residual a rate - %
resK = ( bsxfun(@times,R(2:T-1)',1./wdg(:,1:T-2)).*Y.PX(:,1:T-2) ...
       - W.chirat(:,1:T-2).*(Y.r(:,2:T-1) + (1-P.d)*Y.PX(:,2:T-1)) ) ...
       ./ Y.PX(:,1:T-2);

res = [resK(:); resB];

% - the paths the guess implies - %
if nargout < 2, return, end

out = Y;

% - step 2.4a: bonds, rolled forward from W_0 - %
	% (note: the wedge carries no bond information, so this feeds nothing) %
bnd = nan(V.ncty,T+1);
wlt = nan(V.ncty,T);
wlt(:,1) = B.W0;
for t = 1:T
    bnd(:,t+1) = Y.NX(:,t) + wlt(:,t);
    if t < T, wlt(:,t+1) = R(t+1)*bnd(:,t+1); end
end

out.R    = R;
out.K    = K;
out.e    = e;
out.eall = eall;
out.bond = bnd;
out.wlth = wlt;
out.wedge = wdg;
out.res  = res;
out.resK = resK;
out.resB = resB;
out.bondgap = bnd(V.USA,T+1) - P.Bbar;

end

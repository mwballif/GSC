function out = dynamic(tau,S,P,V,D,B)

% dynamic: Solves the transition path.
% Solves the static problem in every year, then Newton on the interest rate, net
% export and capital paths until both Eulers and the terminal conditions hold.
% Inputs:  tau ((nsec,ncty,ncty,T) trade costs the run uses), S (terminal steady
%           state from steadystate), P, V, D, B.
% Output:  out (structure of solved paths).

T = D.T;
n = 4*T-1;

%---------------------------------------------
%   1. Guess: the observed path
%---------------------------------------------
% The unknowns, in one vector: T-1 interest rates, T US net exports, and the
% 2T capital stocks from the second year on. The first year's stock is data.
z = [D.R0(:); D.NX(V.USA,:)'; reshape(D.K(:,2:T+1)',[],1)];

% One scale per block, so each Newton step is taken in that unknown's own units.
sc = [ones(T-1,1); B.VA(V.USA,:)'; reshape(D.K(:,2:T+1)',[],1)];

% Which years each unknown moves, so a Jacobian column costs one or two year
% solves instead of a whole path.
tof = cell(n,1);
for k = 1:T, tof{T-1+k} = k; end
for i = 1:V.ncty
    for k = 1:T
        tof{2*T-1+(i-1)*T+k} = intersect([k k+1],1:T);
    end
end

%---------------------------------------------
%   2. Newton
%---------------------------------------------
Y = years(z,[],[],tau,P,V,D,B);
res = check(z,Y,S,P,V,D,B);
for iter = 1:P.maxpath
    fprintf('  iteration %d, max residual %.2e\n',iter-1,max(abs(res)));
    if max(abs(res)) < P.tolpath, break, end

    J = zeros(n);
    for k = 1:n
        zk = z;  zk(k) = z(k) + P.fdstep*sc(k);
        Yk = years(zk,Y,tof{k},tau,P,V,D,B);
        J(:,k) = (check(zk,Yk,S,P,V,D,B) - res)/P.fdstep;
    end

    % Step halved until the residual falls. Tested on the norm, so one stubborn
    % year cannot veto a step that helps the rest.
    dz = -(J\res);
    lam = 1;  ok = false;
    for ls = 1:25
        ztry = z + lam*sc.*dz;
        Ytry = years(ztry,[],[],tau,P,V,D,B);
        rtry = check(ztry,Ytry,S,P,V,D,B);
        if norm(rtry) < norm(res), ok = true; break, end
        lam = lam/2;
    end
    if ~ok, fprintf('  no downhill step found; stopping\n'); break, end
    z = ztry;  res = rtry;  Y = Ytry;
    fprintf('  step %.4f\n',lam);
end

[~,out] = check(z,Y,S,P,V,D,B);


function Y = years(z,Y,tlist,tau,P,V,D,B)

% years: Solves the static problem year by year.
% Re-solves only the years in tlist when a previous solution Y is passed.
% Inputs:  z (the guessed path), Y (previous solution, or empty), tlist (years to
%           re-solve), tau, P, V, D, B.
% Output:  Y (each year's solution).

[~,NX,K] = unpack(z,V,D);
if isempty(Y)
    Y.EC = zeros(V.ncty,D.T);   Y.PX = zeros(V.ncty,D.T);
    Y.r  = zeros(V.ncty,D.T);   Y.wagehat = zeros(D.T,1);
    Y.Y  = zeros(V.nsec,V.ncty,D.T);
    Y.snew = zeros(V.nsec,V.ncty,D.T);
    tlist = 1:D.T;
end
for t = tlist(:)'
    o = static(t,NX(t),K(:,t:t+1),tau(:,:,:,t),P,V,D,B);
    Y.wagehat(t) = o.wagehat;
    Y.EC(:,t)    = o.EC;
    Y.PX(:,t)    = o.PX;
    Y.r(:,t)     = o.r;
    Y.Y(:,:,t)   = o.Y;
    Y.snew(:,:,t)= o.snew;
end


function [res,out] = check(z,Y,S,P,V,D,B)

% check: Returns the residuals the path has to zero out.
% Accumulates bonds, then checks both Eulers and the terminal conditions: 4T-1
% residuals against the 4T-1 unknowns in z.
% Inputs:  z (the guessed path), Y (each year's solution), S, P, V, D, B.
% Outputs: res (the residuals), out (the solved paths).

T = D.T;
[R,NX,K] = unpack(z,V,D);
NXall = [NX(:)'; -NX(:)'];

out = Y;
out.phitilde = 1./squeeze(sum(bsxfun(@times,P.eps,out.snew),1));

% Bonds accumulate out of net exports and the interest they earn.
out.bond = zeros(V.ncty,T);
out.bond(:,1) = NXall(:,1);
for t = 2:T
    out.bond(:,t) = R(t-1)*out.bond(:,t-1) + NXall(:,t);
end

% Consumption Euler, in logs. The wedge is imposed, so phi never enters.
resB = log(out.EC(:,2:end)      ./out.EC(:,1:end-1)) ...
     - log(D.L(:,2:end)         ./D.L(:,1:end-1)) ...
     - log(out.phitilde(:,2:end)./out.phitilde(:,1:end-1)) ...
     - log(bsxfun(@rdivide,P.delta*R(:)',D.wedge));

% Capital Euler at the recovered tax. Only its growth enters, and dividing by
% the investment price makes the residual a rate.
resK = ( bsxfun(@rdivide,R(:)',D.wedge).*out.PX(:,1:end-1) ...
       - D.chirat.*(out.r(:,2:end) + (1-P.d)*out.PX(:,2:end)) ) ./ out.PX(:,1:end-1);

% Terminal conditions: capital ends at the steady state stock and bonds end at
% their target.
resT = [ (K(:,T+1) - S.K)./S.K
         (out.bond(V.USA,T) - P.Bbar)/B.VA(V.USA,T) ];

res = [resB(:); resK(:); resT];
out.R = R;  out.NX = NX(:);  out.K = K;  out.res = res;


function [R,NX,K] = unpack(z,V,D)

% unpack: Splits the guess back into its three paths.
% Capital comes back with T+1 columns, the first taken from the data.
% Inputs:  z (the guessed path), V, D.
% Outputs: R (interest rates), NX (US net exports), K (capital).
T  = D.T;
R  = z(1:T-1);
NX = z(T:2*T-1);
K  = [D.K(:,1), reshape(z(2*T:end),T,V.ncty)'];

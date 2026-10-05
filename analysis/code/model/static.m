
% OUTER LOOP %
function out = static(t,tgt,Kt,W,P,V,D,B,lw0)

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Static equilibrium of one period.
%
%  Inputs:  t (base year), Kt (K_t and K_t+1), tau, P, V, D, B,
%           lw0 (optional start, log wage ratio)
%  Output:  out (the period, nominal terms normalized)
%
%==============================================================================

if nargin < 9, lw0 = 0; end

% - find the wage ratio that clears the period - %
f  = @(lw) resid(exp(lw),t,tgt,Kt,W,P,V,D,B);
lw = solvew(f,lw0,P);

% - re-solve the ten steps at that ratio - %
[g,out]     = resid(exp(lw),t,tgt,Kt,W,P,V,D,B);
out.g       = g;
out.wagehat = exp(lw);
out.lw      = lw;

end

% INNER LOOP % 
function lw = solvew(f,lw0,P)

% solvew:  Section 2, Steps 2 and 3, the loop over wages.
%  Inputs:  f (the inner loop error given the log wage ratio), lw0, P
%  Output:  lw (log wage ratio)

lw = lw0;
for k = 1:P.maxw
    epsw = f(lw);
    if abs(epsw) < P.tolw, return, end
    lw = lw + log(1-epsw) - log(1+epsw);
end
error('solvew: no convergence after %d steps, error %.2e',P.maxw,epsw)

end

% FORWARD SOLVE OF EQUILIBRIUM CONDITIONS IN INNER LOOOP %

function [g,out] = resid(wagehat,t,tgt,Kt,W,P,V,D,B)

% resid: Steps 1-10 of Inner loop at a guess for the wage ratio
%  Inputs:  wagehat (US wage over ROW, base year units), 
%  Outputs:  out (the period)

% - wages, with ROW as the numeraire - %
wht = zeros(V.ncty,1);  wht(V.USA) = wagehat;  wht(V.ROW) = 1;

% - year t's base - %
beta = D.beta;  nu = D.nu;  varphi = D.varphi;
theta = P.theta;  psi = P.psi;  zeta = P.zeta;  eps = P.eps;
c0 = D.c0(:,:,t);  P0 = D.P0(:,:,t);

	% the base shares carry the data's demand shifters, so put the run's on %
s0 = B.s(:,:,t) .*(W.muc(:,:,t)./D.muc(:,:,t));
x0 = B.xs(:,:,t).*(W.mux(:,:,t)./D.mux(:,:,t));


% - step 1: rental rate on capital - %

Khat = Kt(:,1)./D.K(:,t);
rhat = wht./Khat;
logf = varphi.*log(rhat) + (1-varphi).*log(wht);   % log value added bundle cost % XX

% - step 2: unit costs and sectoral prices - %

	% Read in intermediate, trade cost and productivity data and wedges %
Nu = cell(V.ncty,1);  Ab = cell(V.ncty,1);  An = cell(V.ncty,1);
PhiData = zeros(V.nsec,V.ncty);
for i = 1:V.ncty
    Nu{i} = bsxfun(@times,nu(:,:,i),1-beta(:,i));
    Ab{i} = reshape(D.tau(:,i,:,t),V.nsec,V.ncty).^(-theta).*D.T_lvl(:,:,t);
    An{i} = reshape(W.tau(:,i,:,t),V.nsec,V.ncty).^(-theta).*W.T_lvl(:,:,t);
    PhiData(:,i) = sum(Ab{i}.*c0.^(-theta),2);
end

	% iterate costs and prices to a fixed point %
logP = zeros(V.nsec,V.ncty);
logc = zeros(V.nsec,V.ncty);
cnew = c0;  PhiNew = PhiData;
for iter = 1:1000
    logP0 = logP;
    for i = 1:V.ncty
        logc(:,i) = beta(:,i)*logf(i) + Nu{i}*logP(:,i);
    end
    cnew = c0.*exp(logc);
    cpow = cnew.^(-theta);
    for i = 1:V.ncty
        PhiNew(:,i) = sum(An{i}.*cpow,2);
    end
    logP = -(1/theta)*log(PhiNew./PhiData);
    if max(abs(logP(:)-logP0(:))) < P.tolprice, break, end
end
Phat = exp(logP);

% - step 3: trade shares - %
pinew = zeros(V.nsec,V.ncty,V.ncty);
for i = 1:V.ncty
    pinew(:,i,:) = bsxfun(@rdivide,An{i}.*cpow,PhiNew(:,i));
end

% - step 4: price of investment - %
	% the shifter moves the index through the base prices as well as the
    % hats %  XX
xb = B.xs(:,:,t);
if abs(zeta-1) < 1e-10
    PXhat = (prod(Phat.^x0,1).*prod(P0.^(x0-xb),1))';  
else
    PXhat = (sum(x0.*(Phat.*P0).^(1-zeta),1)./sum(xb.*P0.^(1-zeta),1))'.^(1/(1-zeta));
end
PXu = D.PX(:,t).*PXhat;

% - step 5: investment and its cost - %
Xp  = Kt(:,2) - (1-P.d)*Kt(:,1);    % law of motion for capital
EXu = PXu.*Xp;

	% value added, and the world total the price level is set by % %XX
VAu   = B.VA(:,t).*wht;
Omega = sum(VAu - EXu);
if Omega <= 0
    error('static: world consumption expenditure is not positive at this wage')
end
lam = 1/Omega;

% - step 6: consumption expenditure and net exports - %
ECu = zeros(V.ncty,1);  NXu = zeros(V.ncty,1);
if isfield(tgt,'EC')
    ECu(V.USA) = tgt.EC;  ECu(V.ROW) = 1-tgt.EC;
    ECu = ECu*Omega;
    NXu = VAu - EXu - ECu;
else
    NXu(V.USA) = tgt.NX;  NXu(V.ROW) = -tgt.NX;
    NXu = NXu*Omega;
    ECu = VAu - EXu - NXu;
end
EChat = ECu./B.EC(:,t);            

% - step 7: price of consumption and real consumption - %

	% Newton on log real consumption, country by country %
Chat = zeros(V.ncty,1);  PChat = zeros(V.ncty,1);
for i = 1:V.ncty
    a  = s0(:,i).*Phat(:,i).^(1-psi);      % Price part of each term
    b  = (1-psi)*(eps-1);                  % Exponent on real consumption
    lE = log(EChat(i));
    lc = 0;
    for iter = 1:50
        wt = a.*exp(b*lc);                 
        S  = sum(wt);
        fc = lc + log(S)/(1-psi) - lE;     
        lc = lc - fc/(sum(wt.*eps)/S);     
        if abs(fc) < P.tolcons, break, end
    end
    Chat(i)  = exp(lc);
    PChat(i) = sum(a.*exp(b*lc))^(1/(1-psi));
end

% - step 8: sector split of consumption and investment - %

	% consumption shares %
snew = zeros(V.nsec,V.ncty);
for i = 1:V.ncty
    snew(:,i) = s0(:,i).*(Phat(:,i)/PChat(i)).^(1-psi).*Chat(i).^((1-psi)*(eps-1));
end

	% investment shares %
xnew = x0.*bsxfun(@rdivide,Phat,PXhat').^(1-zeta);

% - step 9: sectoral expenditure and output - %

	% final demand, intermediate and trade matrices %
	% (note: two index corrections against EQconditions.tex) % %XX
F   = zeros(V.nslot,1);
Gam = zeros(V.nslot);
Pi  = zeros(V.nslot);
for j = 1:V.nsec
    for i = 1:V.ncty
        F(V.slot(j,i)) = snew(j,i)*ECu(i) + xnew(j,i)*EXu(i);
        for m = 1:V.nsec
            Gam(V.slot(j,i),V.slot(m,i)) = nu(m,j,i)*(1-beta(m,i));
        end
        for h = 1:V.ncty
            Pi(V.slot(j,i),V.slot(j,h)) = pinew(j,h,i);
        end
    end
end

	% solve both at once, each being linear in expenditure %
Ep = (eye(V.nslot) - Gam*Pi)\F;     % Leontief inverse %XX
Yp = Pi*Ep;                         % expenditure routed through the trade shares
E2 = Ep(V.slot);
Y2 = Yp(V.slot);

% - step 10: net exports from the trade flows - %
NXbar = sum(Y2-E2,1)';

	% EQconditions.tex Section 2, Step 3's error, in the normalized units %
g     = lam*(NXu(V.USA) - NXbar(V.USA));

% - output - %
out.EC = lam*ECu;  out.NX = lam*NXu;  out.NXbar = lam*NXbar;
out.EX = lam*EXu;  out.PX = lam*PXu;  out.X = Xp;
out.r  = lam*B.r(:,t).*rhat;
out.w  = lam*wht.*((1-varphi).*B.VA(:,t)./D.L(:,t));
out.E  = lam*E2;   out.Y = lam*Y2;   out.VA = lam*sum(beta.*Y2,1)';
out.P  = lam*Phat.*P0;
out.snew = snew;   out.xnew = xnew;  out.pinew = pinew;
out.Chat = Chat;   out.Phat = Phat;  out.PChat = PChat;
out.c  = lam*cnew;
out.lam  = lam;

	% phitilde, for the bond Euler % XX
out.phitilde = 1./sum(bsxfun(@times,eps,snew),1)';

end

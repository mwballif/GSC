function out = static(t,NX,Kt,tau,P,V,D,B)

% Search over the US wage until net exports hit their target
f       = @(lw) resid(exp(lw),t,NX,Kt,tau,P,V,D,B);
wagehat = exp(fzero(f,P.brkw,optimset('TolX',P.tolyear)));

% Re-solve the year at the wage that worked
[g,out]     = resid(wagehat,t,NX,Kt,tau,P,V,D,B);
out.g       = g;
out.wagehat = wagehat;

end


function [g,out] = resid(wagehat,t,NX,Kt,tau,P,V,D,B)

% Wages and net exports for both countries, ROW's wage the numeraire
wht = zeros(V.ncty,1);  wht(V.USA) = wagehat;  wht(V.ROW) = 1;
NXt = zeros(V.ncty,1);  NXt(V.USA) = NX;       NXt(V.ROW) = -NX;

% Everything this year needs, pulled out for readability
beta = D.beta;  nu = D.nu;  varphi = D.varphi;
theta = P.theta;  psi = P.psi;  zeta = P.zeta;  eps = P.eps;
s0 = B.s(:,:,t);  x0 = B.xs(:,:,t);
Tlvl = D.T_lvl(:,:,t);  c0 = D.c0(:,:,t);

% Capital is in place, so the rental rate takes the value added the wage leaves
Khat = Kt(:,1)./D.K(:,t);
rhat = wht./Khat;
logf = varphi.*log(rhat) + (1-varphi).*log(wht);

% Costs depend on prices and prices on costs, so iterate the two
W = cell(V.ncty,1);
PhiData = zeros(V.nsec,V.ncty);
for i = 1:V.ncty
    W{i} = bsxfun(@times,nu(:,:,i),1-beta(:,i));
    PhiData(:,i) = sum(squeeze(D.tau(:,i,:,t)).^(-theta).*Tlvl.*c0.^(-theta),2);
end
logP = zeros(V.nsec,V.ncty);
logc = zeros(V.nsec,V.ncty);
cnew = c0;  PhiNew = PhiData;
for iter = 1:1000
    logP0 = logP;
    for i = 1:V.ncty
        logc(:,i) = beta(:,i)*logf(i) + W{i}*logP(:,i);
    end
    cnew = c0.*exp(logc);
    for i = 1:V.ncty
        PhiNew(:,i) = sum(squeeze(tau(:,i,:)).^(-theta).*Tlvl.*cnew.^(-theta),2);
    end
    logP = -(1/theta)*log(PhiNew./PhiData);
    if max(abs(logP(:)-logP0(:))) < P.tolprice, break, end
end
Phat = exp(logP);

% Trade shares at the new costs
pinew = zeros(V.nsec,V.ncty,V.ncty);
for i = 1:V.ncty
    pinew(:,i,:) = bsxfun(@rdivide, ...
        squeeze(tau(:,i,:)).^(-theta).*Tlvl.*cnew.^(-theta), PhiNew(:,i));
end

% Investment quantity from the capital stocks, its price from the shifters
if abs(zeta-1) < 1e-10
    PXhat = prod(Phat.^x0,1)';
else
    PXhat = sum(x0.*Phat.^(1-zeta),1)'.^(1/(1-zeta));
end
xnew = x0.*bsxfun(@rdivide,Phat,PXhat').^(1-zeta);
Xp   = Kt(:,2) - (1-P.d)*Kt(:,1);
PXp  = D.PX(:,t).*PXhat;
EXp  = PXp.*Xp;

% Consumption is the value added left after investment and net exports
VAp = B.VA(:,t).*wht;
ECp = VAp - EXp - NXt;

% Real consumption, implicit because its price index depends on it
Chat = zeros(V.ncty,1);  PChat = zeros(V.ncty,1);
for i = 1:V.ncty
    a  = s0(:,i).*Phat(:,i).^(1-psi);      % Price part of each term
    b  = (1-psi)*(eps-1);                  % Exponent on real consumption
    lE = log(ECp(i)/B.EC(i,t));
    lc = 0;
    for iter = 1:50
        wt = a.*exp(b*lc);                 % Weight of each term
        S  = sum(wt);
        fc = lc + log(S)/(1-psi) - lE;
        lc = lc - fc/(sum(wt.*eps)/S);
        if abs(fc) < P.tolcons, break, end
    end
    Chat(i)  = exp(lc);
    PChat(i) = sum(a.*exp(b*lc))^(1/(1-psi));
end

% Consumption shares at the new prices and the new real consumption
snew = zeros(V.nsec,V.ncty);
for i = 1:V.ncty
    snew(:,i) = s0(:,i).*(Phat(:,i)/PChat(i)).^(1-psi).*Chat(i).^((1-psi)*(eps-1));
end

% Final demand, the intermediate matrix, and the trade matrix
F   = zeros(V.nslot,1);
Gam = zeros(V.nslot);
Pi  = zeros(V.nslot);
for j = 1:V.nsec
    for i = 1:V.ncty
        F(V.slot(j,i)) = snew(j,i)*ECp(i) + xnew(j,i)*EXp(i);
        for m = 1:V.nsec
            Gam(V.slot(j,i),V.slot(m,i)) = nu(m,j,i)*(1-beta(m,i));
        end
        for h = 1:V.ncty
            Pi(V.slot(j,i),V.slot(j,h)) = pinew(j,h,i);
        end
    end
end

% Expenditure and output in one solve, since both are linear in expenditure
Ep = (eye(V.nslot) - Gam*Pi)\F;
Yp = Pi*Ep;
E2 = Ep(V.slot);
Y2 = Yp(V.slot);

% Gap between the net exports this wage delivers and the target
NXnew = sum(Y2-E2,1)';
g     = (NXnew(V.USA) - NXt(V.USA))/VAp(V.USA);

% Everything the year computed
out.EC = ECp;  out.EX = EXp;  out.PX = PXp;  out.X = Xp;
out.VA = sum(beta.*Y2,1)';  out.NX = NXnew;
out.r  = B.r(:,t).*rhat;
out.E  = E2;  out.Y = Y2;  out.snew = snew;  out.xnew = xnew;
out.Phat = Phat;  out.c = cnew;  out.pinew = pinew;
out.Chat = Chat;  out.PChat = PChat;

end

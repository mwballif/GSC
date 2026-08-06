function [g,out] = yearmodel(wagehat,t,NX,P,V,D,B)

% yearmodel: Steps 9 to 15 of model.pdf. The model, one year.
%
% input:  wagehat is the guessed change in the US wage, NX is US net exports
% output: g is the income residual, out holds everything the year computed

wht = zeros(V.ncty,1);  wht(V.USA) = wagehat;  wht(V.ROW) = 1;   % Numeraire
NXt = zeros(V.ncty,1);  NXt(V.USA) = NX;       NXt(V.ROW) = -NX;

beta = D.beta;  nu = D.nu;  ups = D.upsilon;
pi0 = D.pi(:,:,:,t);  s0 = B.s(:,:,t);
theta = P.theta;  psi = P.psi;  eps = P.eps;

%---------------------------------------------
%   9. Unit costs and prices
%---------------------------------------------
% Done in logs: the cost equation is then a matrix times a vector
W  = cell(V.ncty,1);  PIb = cell(V.ncty,1);
for i = 1:V.ncty
    W{i}   = bsxfun(@times,nu(:,:,i),1-beta(:,i));   % (j,m)
    PIb{i} = squeeze(pi0(:,i,:));                    % (j,h)
end
logw = log(wht);
logP = zeros(V.nsec,V.ncty);
logc = zeros(V.nsec,V.ncty);
for iter = 1:1000
    logP0 = logP;
    for i = 1:V.ncty
        logc(:,i) = beta(:,i)*logw(i) + W{i}*logP(:,i);
    end
    ct = exp(-theta*logc);
    for i = 1:V.ncty
        logP(:,i) = -(1/theta)*log(sum(PIb{i}.*ct,2));
    end
    if max(abs(logP(:)-logP0(:))) < P.tolprice, break, end
end
Phat = exp(logP);
chat = exp(logc);

%---------------------------------------------
%   10. Trade shares
%---------------------------------------------
pinew = zeros(V.nsec,V.ncty,V.ncty);
for i = 1:V.ncty
    pinew(:,i,:) = squeeze(pi0(:,i,:)).*bsxfun(@rdivide,chat,Phat(:,i)).^(-theta);
end

%---------------------------------------------
%   11. Income and spending
%---------------------------------------------
VAp = B.VA(:,t).*wht;
EXp = B.x(:,t).*VAp;
ECp = (1-B.x(:,t)).*VAp - NXt;

%---------------------------------------------
%   12. Real consumption
%---------------------------------------------
% Newton in logs.

Chat = zeros(V.ncty,1);  PChat = zeros(V.ncty,1);
for i = 1:V.ncty
    a  = s0(:,i).*Phat(:,i).^(1-psi);       % the price part of each term
    b  = (1-psi)*(eps-1);                   % the exponent on Chat
    lE = log(ECp(i)/B.EC(i,t));
    lc = 0;
    for iter = 1:50
        w  = a.*exp(b*lc);
        S  = sum(w);
        f  = lc + log(S)/(1-psi) - lE;
        fp = sum(w.*eps)/S;                 % = 1/phitilde
        lc = lc - f/fp;
        if abs(f) < P.tolcons, break, end
    end
    Chat(i)  = exp(lc);
    PChat(i) = sum(a.*exp(b*lc))^(1/(1-psi));
end

%---------------------------------------------
%   13. New consumption shares
%---------------------------------------------
snew = zeros(V.nsec,V.ncty);
for i = 1:V.ncty
    snew(:,i) = s0(:,i).*(Phat(:,i)/PChat(i)).^(1-psi).*Chat(i).^((1-psi)*(eps-1));
end

%---------------------------------------------
%   14. Market clearing
%---------------------------------------------
F   = zeros(V.nslot,1);
Gam = zeros(V.nslot);
Pi  = zeros(V.nslot);
for j = 1:V.nsec
    for i = 1:V.ncty
        F(V.slot(j,i)) = snew(j,i)*ECp(i) + ups(j,i)*EXp(i);
        for m = 1:V.nsec
            Gam(V.slot(j,i),V.slot(m,i)) = nu(m,j,i)*(1-beta(m,i));
        end
        for h = 1:V.ncty
            Pi(V.slot(j,i),V.slot(j,h)) = pinew(j,h,i);
        end
    end
end
Ep = (eye(V.nslot) - Gam*Pi)\F;
Yp = Pi*Ep;

%---------------------------------------------
%   15. Income residual
%---------------------------------------------
E2 = zeros(V.nsec,V.ncty);  Y2 = zeros(V.nsec,V.ncty);
for j = 1:V.nsec
    for i = 1:V.ncty
        E2(j,i) = Ep(V.slot(j,i));
        Y2(j,i) = Yp(V.slot(j,i));
    end
end
VAnew = sum(beta.*Y2,1)';
g = VAnew(V.USA)/(B.VA(V.USA,t)*wagehat) - 1;

out.gforeign = VAnew(V.ROW)/B.VA(V.ROW,t) - 1;
out.EC = ECp;  out.EX = EXp;  out.VA = VAnew;
out.snew = snew;  out.E = E2;  out.Y = Y2;
out.Phat = Phat;  out.chat = chat;  out.Chat = Chat;  out.PChat = PChat;
out.pinew = pinew;

function B = baseline(P,V,D)

% baseline: Steps 1 to 7 of model.pdf. Everything the data implies.
% Input:
%   P : Structure of parameters
%   V : Structure of variables
%   D : Structure of data
% Output:
%   B : Structure of baseline series

%---------------------------------------------
%   1. Value added
%---------------------------------------------
B.VA = squeeze(sum(bsxfun(@times,D.beta,D.Y),1));

%---------------------------------------------
%   2. Consumption expenditure and the investment rate
%---------------------------------------------
B.EC = B.VA - D.EX - D.NX;
B.x  = D.EX./B.VA;

%---------------------------------------------
%   3. Consumption shares
%---------------------------------------------
for t = 1:D.T
    for i = 1:V.ncty
        interm = D.nu(:,:,i)'*((1-D.beta(:,i)).*D.Y(:,i,t));
        B.s(:,i,t) = (D.E(:,i,t) - interm - D.upsilon(:,i)*D.EX(i,t))/B.EC(i,t);
    end
end

%---------------------------------------------
%   4. Phitilde  (how much consumption a dollar buys )
%---------------------------------------------
B.phitilde = 1./squeeze(sum(bsxfun(@times,P.eps,B.s),1));

%---------------------------------------------
%   5. World interest rate
%---------------------------------------------
B.R = ( (1/P.delta) ...
      .*(B.EC(V.ROW,2:end)  ./B.EC(V.ROW,1:end-1)) ...
      .*(D.L(V.ROW,1:end-1) ./D.L(V.ROW,2:end)) ...
      .*(B.phitilde(V.ROW,1:end-1)./B.phitilde(V.ROW,2:end)) )';

%---------------------------------------------
%   6. The wedge
%---------------------------------------------
B.omega = ones(V.ncty,D.T-1);
B.omega(V.USA,:) = (D.L(V.USA,2:end)   ./D.L(V.USA,1:end-1)) ...
                .* (B.phitilde(V.USA,2:end) ./B.phitilde(V.USA,1:end-1)) ...
                .* (P.delta*B.R') ...
                .* (B.EC(V.USA,1:end-1)./B.EC(V.USA,2:end));

%---------------------------------------------
%   7. Bonds
%---------------------------------------------
B.bond = zeros(V.ncty,D.T);
B.bond(:,1) = D.NX(:,1);
for t = 2:D.T
    B.bond(:,t) = B.R(t-1)*B.bond(:,t-1) + D.NX(:,t);
end

%---------------------------------------------
%   Check: the shares add to one
%---------------------------------------------
tmp = abs(sum(B.s,1)-1);
B.chks = max(tmp(:));

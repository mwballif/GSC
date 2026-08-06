function [res,out] = pathmodel(NX,omega,P,V,D,B,S)

% pathmodel: Steps 17 to 21 of model.pdf.
%
% input:  NX is the guessed path of US net exports, omega the imposed wedge.
%         S is an optional set of year solutions from solveyears; pass it when
%         only a few years have changed.
% output: res is T residuals, out holds the solved path

T = D.T;
NXall = zeros(V.ncty,T);
NXall(V.USA,:) =  NX(:)';
NXall(V.ROW,:) = -NX(:)';

%---------------------------------------------
%   17. Every year
%---------------------------------------------
if nargin < 7, S = solveyears(NX,P,V,D,B); end
out = S;
out.phitilde = 1./squeeze(sum(bsxfun(@times,P.eps,out.snew),1));

%---------------------------------------------
%   18. World interest rate
%---------------------------------------------
out.R = ( (1/P.delta) ...
        .*(out.EC(V.ROW,2:end)  ./out.EC(V.ROW,1:end-1)) ...
        .*(D.L(V.ROW,1:end-1)   ./D.L(V.ROW,2:end)) ...
        .*(out.phitilde(V.ROW,1:end-1)./out.phitilde(V.ROW,2:end)) )';

%---------------------------------------------
%   19. Bonds
%---------------------------------------------
out.bond = zeros(V.ncty,T);
out.bond(:,1) = NXall(:,1);
for t = 2:T
    out.bond(:,t) = out.R(t-1)*out.bond(:,t-1) + NXall(:,t);
end

%---------------------------------------------
%   20. US saving equation
%---------------------------------------------
res = zeros(T,1);
res(1:T-1) = log(out.EC(V.USA,2:end) ./out.EC(V.USA,1:end-1))' ...
           - log(D.L(V.USA,2:end)    ./D.L(V.USA,1:end-1))' ...
           - log(out.phitilde(V.USA,2:end)./out.phitilde(V.USA,1:end-1))' ...
           - log(P.delta*out.R./omega(:));

%---------------------------------------------
%   21. Terminal condition
%---------------------------------------------
res(T) = (out.bond(V.USA,T) - B.bond(V.USA,T))/B.VA(V.USA,T);

out.NX = NX(:);
out.res = res;

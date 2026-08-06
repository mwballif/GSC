function S = solveyears(NX,P,V,D,B,S,tlist)

% solveyears: Step 17 of model.pdf. Runs the static block year by year.
%
% Years do not interact: year t sees only NX(t). Pass S and tlist to re-solve
% just those years and leave the rest of S alone, which is what makes the
% Jacobian in solvepath cheap.
%
% input:  NX is the path of US net exports
% output: S holds each year's solution

if nargin < 6
    S.EC      = zeros(V.ncty,D.T);
    S.Y       = zeros(V.nsec,V.ncty,D.T);
    S.snew    = zeros(V.nsec,V.ncty,D.T);
    S.wagehat = zeros(D.T,1);
    tlist     = 1:D.T;
end

for t = tlist(:)'
    [wagehat,o] = solveyear(t,NX(t),P,V,D,B);
    S.wagehat(t)  = wagehat;
    S.EC(:,t)     = o.EC;
    S.Y(:,:,t)    = o.Y;
    S.snew(:,:,t) = o.snew;
end

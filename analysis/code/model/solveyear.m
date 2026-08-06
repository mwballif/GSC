function [wagehat,out] = solveyear(t,NX,P,V,D,B)

% solveyear: Steps 8 and 15 of model.pdf.
% Input:  t is the year, NX is US net exports for that year
% Output: wagehat is the wage change, out is the year's solution

f = @(lw) yearmodel(exp(lw),t,NX,P,V,D,B);
wagehat = exp(fzero(f,P.brkw,optimset('TolX',P.tolyear)));

[~,out] = yearmodel(wagehat,t,NX,P,V,D,B);

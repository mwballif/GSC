function [man,gds,agr,ser] = vashares(Y,D,V)

% vashares: US value added shares by sector, from a solved path.
%   va^j_t = beta^j Y^j_t / sum_m beta^m Y^m_t

va  = bsxfun(@times, D.beta(:,V.USA), squeeze(Y(:,V.USA,:)));
tot = sum(va,1);
agr = va(V.AGR,:)./tot;
man = va(V.MAN,:)./tot;
ser = va(V.SER,:)./tot;
gds = agr + man;

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Checks the solved path against every equation in EQconditions.tex.
%  Re-solves each period, then evaluates each condition on the solution.
%  (note: a condition the solver imposes only reports convergence; one nothing
%  imposes is a real test of the model and the data agreeing)
%
%  Output:  a table of residuals, printed to screen
%  
%  Data used:
%           results/solution.mat
%
%==============================================================================

clear; clc; close all;

L = load('results/solution.mat');
V = L.V;  P = L.P;  D = L.D;  B = L.B;  o = L.o;
S   = L.r(1).S;                      % the baseline's own steady state
pth  = L.r(1).o;                     % the baseline transition
T = D.T;  td = D.Tdata;

% - re-solve every period of the path - %
q = cell(T,1);
for t = 1:T
    q{t} = static(t,struct('EC',pth.e(t)),pth.K(:,t:t+1),L.r(1).W,P,V,D,B);
end

n = 0;  nm = {};  gp = [];  kd = {};

% - Section 3, the static conditions - %
g = zeros(T,1);

% eq:KLratio, with varphi as capital's share
for t = 1:T
    lhs = (q{t}.w.*D.L(:,t))./(q{t}.r.*pth.K(:,t));
    g(t) = max(abs(lhs./((1-D.varphi)./D.varphi) - 1));
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:KLratio  w L /(r K) = (1-varphi)/varphi',g,'level');

% eq:UnitCosts in levels, from EQconditions.tex's own kappa
for t = 1:T
    e = zeros(V.nsec,V.ncty);
    for i = 1:V.ncty
        for j = 1:V.nsec
            nuj = D.nu(j,:,i)';  bj = D.beta(j,i);  vp = D.varphi(i);
            kap = (vp^vp*(1-vp)^(1-vp))^(-bj) * bj^(-bj) * (1-bj)^(-(1-bj)) ...
                  * prod(nuj.^(-(1-bj)*nuj));
            rhs = kap * ((q{t}.r(i)^vp*q{t}.w(i)^(1-vp))^bj) ...
                      * (prod(q{t}.P(:,i).^nuj)^(1-bj));
            e(j,i) = rhs/q{t}.c(j,i) - 1;
        end
    end
    g(t) = max(abs(e(:)));
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:UnitCosts  c = kappa (r^vp w^(1-vp))^b (prod P^nu)^(1-b)',g,'level');

% Why the line above misses. The recovered costs sit on the cost function when
% the factor prices come from the country panel's GDP, which is what
% recover_parameters.m used, and miss by 7 per cent when they come from the
% model's sum(beta.*Y). The constant value added share is the whole gap.
rg = bsxfun(@times,D.varphi,D.gdp)./D.K(:,1:T);
wg = bsxfun(@times,1-D.varphi,D.gdp)./D.L;
e  = zeros(V.nsec,V.ncty,td);
for t = 1:td
    for i = 1:V.ncty
        for j = 1:V.nsec
            nuj = D.nu(j,:,i)';  bj = D.beta(j,i);  vp = D.varphi(i);
            kap = (vp^vp*(1-vp)^(1-vp))^(-bj) * bj^(-bj) * (1-bj)^(-(1-bj)) ...
                  * prod(nuj.^(-(1-bj)*nuj));
            e(j,i,t) = kap*((rg(i,t)^vp*wg(i,t)^(1-vp))^bj) ...
                       *(prod(D.P0(:,i,t).^nuj)^(1-bj))/D.c0(j,i,t) - 1;
        end
    end
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'              same, factor prices from the country panel GDP',e,'level');
[n,nm,gp,kd] = add(n,nm,gp,kd,'              sum(beta.*Y) against the country panel GDP', ...
                   B.VA(:,1:td)./D.gdp(:,1:td)-1,'level');

% eq:SecPrices. Gamma is unnamed in EQconditions.tex, so the test is that one number
% reproduces every price in every country, sector and year.
Gam = zeros(V.nsec,V.ncty,T);
for t = 1:T
    for i = 1:V.ncty
        Phi = sum(reshape(D.tau(:,i,:,t),V.nsec,V.ncty).^(-P.theta) ...
                  .*D.T_lvl(:,:,t).*q{t}.c.^(-P.theta),2);
        Gam(:,i,t) = q{t}.P(:,i)./Phi.^(-1/P.theta);
    end
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:SecPrices  implied Gamma is one constant', ...
                   abs(Gam(:)/mean(Gam(:))-1),'level');

% eq:piShares from the levels
for t = 1:T
    e = zeros(V.nsec,V.ncty,V.ncty);
    for i = 1:V.ncty
        Phi = sum(reshape(D.tau(:,i,:,t),V.nsec,V.ncty).^(-P.theta) ...
                  .*D.T_lvl(:,:,t).*q{t}.c.^(-P.theta),2);
        for h = 1:V.ncty
            num = D.T_lvl(:,h,t).*(q{t}.c(:,h).*D.tau(:,i,h,t)).^(-P.theta);
            e(:,i,h) = num./Phi./q{t}.pinew(:,i,h) - 1;
        end
    end
    g(t) = max(abs(e(:)));
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:piShares  pi = T (c tau)^-theta / Phi',g,'level');
for t = 1:T, g(t) = max(abs(sum(q{t}.pinew,3)-1),[],'all'); end
[n,nm,gp,kd] = add(n,nm,gp,kd,'             trade shares add to one',g,'level');

% eq:PriceX and eq:SharesX
for t = 1:T
    if abs(P.zeta-1) < 1e-10
        PX = prod(q{t}.P.^D.mux(:,:,t),1)';
    else
        PX = sum(D.mux(:,:,t).*q{t}.P.^(1-P.zeta),1)'.^(1/(1-P.zeta));
    end
    g(t) = max(abs(PX./q{t}.PX-1));
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:PriceX  P^X from the sectoral prices and mu^x',g,'level');
for t = 1:T
    x = D.mux(:,:,t).*bsxfun(@rdivide,q{t}.P,q{t}.PX').^(1-P.zeta);
    g(t) = max([max(abs(x./q{t}.xnew-1),[],'all'), max(abs(sum(q{t}.xnew,1)-1))]);
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:SharesX  x = mu^x (P/P^X)^(1-zeta), adds to one',g,'level');
for t = 1:T
    g(t) = max(abs(q{t}.EX./(q{t}.PX.*(pth.K(:,t+1)-(1-P.d)*pth.K(:,t)))-1));
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:SharesX  E^X = P^X (K_{t+1} - (1-d) K_t)',g,'imposed');

% eq:PriceC, eq:AggC, eq:SharesC. mu^c rides in the base year, so the test is
% that the shares add to one and C = E^C / P^C holds.
for t = 1:T, g(t) = max(abs(sum(q{t}.snew,1)-1)); end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:SharesC  consumption shares add to one',g,'level');
for t = 1:T
    % The hats predate the normalization, so take it back out of E^C
    ECh = (q{t}.EC/q{t}.lam)./B.EC(:,t);
    g(t) = max(abs(q{t}.Chat.*q{t}.PChat./ECh-1));
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:AggC  C = E^C / P^C',g,'imposed');

% eq:MCExp and eq:MCOut, with the two index corrections
for t = 1:T
    e = zeros(V.nsec,V.ncty);  f = zeros(V.nsec,V.ncty);
    for i = 1:V.ncty
        interm = D.nu(:,:,i)'*((1-D.beta(:,i)).*q{t}.Y(:,i));
        e(:,i) = (q{t}.snew(:,i)*q{t}.EC(i) + q{t}.xnew(:,i)*q{t}.EX(i) ...
                  + interm)./q{t}.E(:,i) - 1;
        for j = 1:V.nsec
            f(j,i) = sum(squeeze(q{t}.pinew(j,:,i))'.*q{t}.E(j,:)')/q{t}.Y(j,i) - 1;
        end
    end
    g(t) = max([max(abs(e(:))) max(abs(f(:)))]);
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:MCExp and eq:MCOut  market clearing',g,'imposed');

% eq:NXTrade against the budget constraint, and the normalization
for t = 1:T
    nxb = (q{t}.w.*D.L(:,t) + q{t}.r.*pth.K(:,t)) ...
          - (q{t}.EC + q{t}.PX.*(pth.K(:,t+1)-(1-P.d)*pth.K(:,t)));
    g(t) = max(abs(q{t}.NXbar - nxb)./q{t}.VA);
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'eq:NXTrade  trade flows match the budget constraint',g,'solved');
for t = 1:T, g(t) = abs(sum(q{t}.EC)-1); end
[n,nm,gp,kd] = add(n,nm,gp,kd,'normalization  sum_i E^C = 1',g,'imposed');

% - Section 2, the steady state - %
ss = [ abs(S.R - 1/P.delta)
       max(abs(S.NX + (S.R-1)*[S.Bbar;-S.Bbar]))
       max(abs(S.X - P.d*S.K))
       max(abs(S.EC - (S.w.*D.L(:,T) + S.r.*S.K - S.PX.*S.X - S.NX)))
       max(abs(1/P.delta - (S.r./S.PX + (1-P.d))))
       abs(sum(S.EC)-1) ];
sn = {'R_ss = 1/delta','NX_ss = -(R_ss-1) B_ss','X_ss = d K_ss', ...
      'E^C_ss = w L + r K - P^X X - NX','outer loop error is zero', ...
      'sum_i E^C_ss = 1'};
sk = {'imposed','imposed','imposed','imposed','solved','imposed'};
for k = 1:numel(ss)
    [n,nm,gp,kd] = add(n,nm,gp,kd,['steady state  ' sn{k}],ss(k),sk{k});
end

% - Section 1, the transition - %
% Wedges known through the last data year, unchanged after
wg = [ max(abs(D.wedge(:,td:end)-1),[],'all')
       max(abs(D.chirat(:,td:end)-1),[],'all') ];
[n,nm,gp,kd] = add(n,nm,gp,kd,'wedges are unchanged after the last data year',max(wg),'imposed');

% Step 2.1, the ends of the guess
[n,nm,gp,kd] = add(n,nm,gp,kd,'K_0 is the data, K_T is the steady state', ...
    max([abs(pth.K(:,1)./D.Kdata(:,1)-1); abs(pth.K(:,T)./S.K-1)]),'imposed');
[n,nm,gp,kd] = add(n,nm,gp,kd,'E^C_T and w_T are the steady state', ...
    max([abs(q{T}.EC./S.EC-1); abs(q{T}.w./S.w-1)]),'imposed');

% Step 2.4a, bonds, built again from scratch
bnd = nan(V.ncty,T+1);  wlt = nan(V.ncty,T);  wlt(:,1) = B.W0;
for t = 1:T
    bnd(:,t+1) = pth.NX(:,t) + wlt(:,t);
    if t < T, wlt(:,t+1) = pth.R(t+1)*bnd(:,t+1); end
end
sc = max(abs(bnd(V.USA,2:end)));
[n,nm,gp,kd] = add(n,nm,gp,kd,'Step 2.4a  B_{t+1} = NX_t + R_t B_t', ...
    max(abs(bnd(:)-pth.bond(:)))/sc,'imposed');
[n,nm,gp,kd] = add(n,nm,gp,kd,'             bonds are in zero net supply', ...
    max(abs(sum(bnd(:,2:end),1)))/sc,'level');

% Step 2.4b, R, built again from EQconditions.tex's formula
pt = zeros(V.ncty,T);
for t = 1:T, pt(:,t) = q{t}.phitilde; end
ea = zeros(V.ncty,T);
ea(V.USA,:) = pth.e(:)';  ea(V.ROW,:) = 1-pth.e(:)';
% Employment growth is the per worker form of eq:EEbonds; see dynamic.m
Lr = D.L(:,2:T)./D.L(:,1:T-1);
Rn = nan(T,1);
for t = 1:T-1
    Rn(t+1) = 1/(P.delta*sum(Lr(:,t).*(pt(:,t+1)./pt(:,t)).*ea(:,t)./D.wedge(:,t)));
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'Step 2.4b  R_{t+1} from the two bond Eulers', ...
    max(abs(Rn(2:T)./pth.R(2:T)-1)),'imposed');

% Step 2.4c, the two conditions the path must satisfy
e1 = zeros(V.ncty,T-2);
for t = 1:T-2
    e1(:,t) = (Rn(t+1)./D.wedge(:,t)).*q{t}.PX ...
              - D.chirat(:,t).*(q{t+1}.r + (1-P.d)*q{t+1}.PX);
    e1(:,t) = e1(:,t)./q{t}.PX;
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'Step 2.4c  Euler equation for capital',max(abs(e1(:))),'solved');
e2 = zeros(V.ncty,T-1);
for t = 1:T-1
    e2(:,t) = (ea(:,t+1)./ea(:,t)) ...
              - Lr(:,t).*(pt(:,t+1)./pt(:,t))*P.delta*Rn(t+1)./D.wedge(:,t);
end
[n,nm,gp,kd] = add(n,nm,gp,kd,'Step 2.4c  Euler equation for bonds',max(abs(e2(:))),'solved');

% - report - %
fprintf('\nThe solved path against EQconditions.tex\n\n');
fprintf('  %-55s %10s   %s\n','condition','max miss','what it tests');
for k = 1:n
    switch kd{k}
        case 'imposed', wh = 'the solver imposes it';
        case 'solved',  wh = 'the solver drives it to zero';
        otherwise,      wh = 'nothing imposes it';
    end
    fprintf('  %-55s %10.1e   %s\n',nm{k},gp(k),wh);
end
fprintf('\n  worst miss anywhere  %.1e\n\n',max(gp));


function [n,nm,gp,kd] = add(n,nm,gp,kd,name,gap,kind)
% add: Records one check.
n = n+1;  nm{n} = name;  gp(n) = max(abs(gap(:)));  kd{n} = kind;
end

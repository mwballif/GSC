function S = steadystate(W,P,V,D,B)

%==============================================================================
%
%  "GSC," by Ballif and Reyes-Heroles. Algorithm in EQconditions.tex.
%
%  Steady state of the model, Section 2.
%
%  Inputs:  W (the run's wedges, from wedges.m), P, V, D, B
%  Output:  S (the steady state)
%
%==============================================================================

% - fundamentals of the last year, which the padded years repeat - %
t = D.T;
S.year = D.years(t);

% - R, net exports and the required return - %
	% R_ss, from the bond Euler at constant E^C and B = Bbar %
S.R    = 1/P.delta;
S.Bbar = P.Bbar;

	% net exports, the interest bill on the target %
S.NX        = zeros(V.ncty,1);
S.NX(V.USA) = -(S.R-1)*S.Bbar;
S.NX(V.ROW) = -S.NX(V.USA);

	% the rent capital must earn %
S.rPX = S.R - (1-P.d);

% - steps 1 and 4: the outer loop over capital - %
	% start at the data capital stock %
K  = D.K(:,t);
lw = 0;
for iter = 1:P.maxss

    % steps 2 and 3, the inner loop, at K constant so X = d K %
    out = static(t,struct('NX',S.NX(V.USA)),[K K],W,P,V,D,B,lw);
    lw  = out.lw;

    % step 4's error %
    epsK = S.rPX - out.r./out.PX;

    % the stock that delivers that rent %
    Knew = K.*(out.r./out.PX)/S.rPX;

    % stop when the guess stops moving %
    gap = max(abs(Knew./K - 1));
    if gap < P.tolss, break, end

    % move part way towards it %
    K = (1-P.ssdamp)*K + P.ssdamp*Knew;
end

% - stop if it never settled - %
if gap >= P.tolss
    error('steadystate: no convergence, gap %.2e',gap)
end

% - the steady state at the answer - %
S.K    = K;
S.X    = P.d*S.K;
S.iter = iter;

S.out  = static(t,struct('NX',S.NX(V.USA)),[S.K S.K],W,P,V,D,B,lw);
S.r    = S.out.r;
S.PX   = S.out.PX;
S.w    = S.out.w;
S.EC   = S.out.EC;
S.EX   = S.out.EX;
S.eUS  = S.out.EC(V.USA);
S.phitilde = S.out.phitilde;

	% Euler residual, as a check %
S.resid = S.r./S.PX - S.rPX;
S.epsK  = epsK;

% - observed capital against the level it settles at - %
yr = D.years(1:D.Tdata);
figure('Position',[100,100,900,380],'Color','w');
for i = 1:V.ncty
    subplot(1,V.ncty,i); hold on; box on; grid on;
    h1 = plot(yr,D.K(i,1:D.Tdata),'k-','LineWidth',1.5);
    h2 = yline(S.K(i),'b--','LineWidth',1.5);
    title(V.countries{i});
    xlabel('Year'); xlim([yr(1) yr(end)]);
    if i == 1
        ylabel('Capital stock');
        legend([h1 h2],{'Data',sprintf('%d steady state',S.year)}, ...
               'Location','northwest','Box','off');
    end
end
sgtitle('Capital steady state');

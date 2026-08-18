function S = steadystate(tau,P,V,D,B)

% Freeze all shocks at one year
t = D.Tdata;
S.shockyear = D.years(t);
S.year      = P.ssyear;

% World interest rate from the consumption Euler
S.R = 1/P.delta;

% Net exports from the bond position
S.NX        = zeros(V.ncty,1);
S.NX(V.USA) = (1-S.R)*P.Bbar;
S.NX(V.ROW) = -S.NX(V.USA);

% Required return on capital
S.rPX = S.R - (1-P.d);

% Start the guess at the data capital stock
K = D.K(:,t);

for iter = 1:P.maxss

    % Solve the static block holding capital constant, so X = dK
    out = static(t,S.NX(V.USA),[K K],tau(:,:,:,t),P,V,D,B);

    % Capital the Euler implies at these prices
    Knew = K .* (out.r./out.PX) / S.rPX;

    % Stop when the guess stops moving
    gap = max(abs(Knew./K - 1));
    if gap < P.tolss, break, end

    % Move part way towards it
    K = (1-P.ssdamp)*K + P.ssdamp*Knew;
end

% Stop if it never settled
if gap >= P.tolss
    error('steadystate: no convergence, gap %.2e',gap)
end

% Store the solved capital stock
S.K    = K;
S.X    = P.d*S.K;
S.iter = iter;

% Re-solve the static block at the answer
S.out   = static(t,S.NX(V.USA),[S.K S.K],tau(:,:,:,t),P,V,D,B);
S.r     = S.out.r;
S.PX    = S.out.PX;
S.EC    = S.out.EC;
S.EX    = S.out.EX;

% Euler residual at the answer, as a check
S.resid = S.r./S.PX - S.rPX;

% Plot the observed capital stock against the level it settles at
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
sgtitle(sprintf('Capital Steady State',S.year));

end
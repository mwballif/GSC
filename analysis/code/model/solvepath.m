function out = solvepath(omega,P,V,D,B)

% solvepath: Steps 16 and 22 of model.pdf. 
% Input:  omega is the imposed wedge path
% Output: out holds net exports, consumption, output, the interest rate and bonds

% Start at the observed path. 
NX = D.NX(V.USA,:)';
T  = D.T;

% Step for the numerical derivatives, scaled to income. It has to be this
% coarse: the data satisfies its own accounting only to 2e-8, so a smaller
% step measures rounding noise instead of the derivative.
h = P.fdstep*B.VA(V.USA,:)';

res = pathmodel(NX,omega,P,V,D,B);
for iter = 1:P.maxpath
    fprintf('  iteration %d, max residual %.2e\n',iter-1,max(abs(res)));
    if max(abs(res)) < P.tolpath, break, end

    J = zeros(T);
    for k = 1:T
        step = zeros(T,1);  step(k) = h(k);
        J(:,k) = (pathmodel(NX+step,omega,P,V,D,B) - res)/h(k);
    end

    % Newton step, halved until the residual actually falls
    dNX = -(J\res);
    lam = 1;  ok = false;
    for ls = 1:25
        NXtry  = NX + lam*dNX;
        restry = pathmodel(NXtry,omega,P,V,D,B);
        if max(abs(restry)) < max(abs(res)), ok = true; break, end
        lam = lam/2;
    end
    if ~ok, fprintf('  no downhill step found; stopping\n'); break, end
    NX = NXtry;  res = restry;
    fprintf('  step %.4f\n',lam);
end

[~,out] = pathmodel(NX,omega,P,V,D,B);

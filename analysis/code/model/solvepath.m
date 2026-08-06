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

S   = solveyears(NX,P,V,D,B);
res = pathmodel(NX,omega,P,V,D,B,S);
for iter = 1:P.maxpath
    fprintf('  iteration %d, max residual %.2e\n',iter-1,max(abs(res)));
    if max(abs(res)) < P.tolpath, break, end

    % Jacobian. NX(k) moves year k and no other, so each column costs one
    % year solve rather than a whole path.
    J = zeros(T);
    for k = 1:T
        NXk = NX;  NXk(k) = NX(k) + h(k);
        Sk  = solveyears(NXk,P,V,D,B,S,k);
        J(:,k) = (pathmodel(NXk,omega,P,V,D,B,Sk) - res)/h(k);
    end

    % Newton step, halved until the residual actually falls. The test is on
    % the norm, not the largest element: one stubborn year would otherwise
    % veto a step that improves the other sixty-nine.
    dNX = -(J\res);
    lam = 1;  ok = false;
    for ls = 1:25
        NXtry  = NX + lam*dNX;
        Stry   = solveyears(NXtry,P,V,D,B);
        restry = pathmodel(NXtry,omega,P,V,D,B,Stry);
        if norm(restry) < norm(res), ok = true; break, end
        lam = lam/2;
    end
    if ~ok, fprintf('  no downhill step found; stopping\n'); break, end
    NX = NXtry;  res = restry;  S = Stry;
    fprintf('  step %.4f\n',lam);
end

[~,out] = pathmodel(NX,omega,P,V,D,B,S);

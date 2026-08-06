function [D,B] = padyears(H,P,V,D,B)

% padyears: Repeats the last year H times.
%
% The terminal condition pins the counterfactual's net foreign assets. Applied
% at 2014 it forces the counterfactual to end the sample with the debt the data
% has, which is the thing the friction is supposed to have caused. Padding
% moves that constraint H years past the sample, so it no longer binds inside
% the window that gets reported.
%
% Fundamentals and net exports are held at their 2014 values. A repeat of the
% last year implies R = 1/delta and a wedge of one, in every scenario, so the
% padded years add nothing to the difference between runs.

if H <= 0, return, end
T = D.T;

%---------------------------------------------
%   Data
%---------------------------------------------
D.years = [D.years(:); D.years(end)+(1:H)'];
D.pi    = cat(4, D.pi, repmat(D.pi(:,:,:,T),[1 1 1 H]));
D.Y     = cat(3, D.Y,  repmat(D.Y(:,:,T),  [1 1 H]));
D.E     = cat(3, D.E,  repmat(D.E(:,:,T),  [1 1 H]));
D.L     = [D.L,  repmat(D.L(:,T), 1,H)];
D.EX    = [D.EX, repmat(D.EX(:,T),1,H)];
D.NX    = [D.NX, repmat(D.NX(:,T),1,H)];

%---------------------------------------------
%   Baseline
%---------------------------------------------
B.VA       = [B.VA,       repmat(B.VA(:,T),      1,H)];
B.EC       = [B.EC,       repmat(B.EC(:,T),      1,H)];
B.x        = [B.x,        repmat(B.x(:,T),       1,H)];
B.phitilde = [B.phitilde, repmat(B.phitilde(:,T),1,H)];
B.s        = cat(3, B.s,  repmat(B.s(:,:,T),[1 1 H]));

% constant fundamentals imply a constant return and no wedge
B.R     = [B.R; (1/P.delta)*ones(H,1)];
B.omega = [B.omega, ones(V.ncty,H)];

% bonds keep accumulating
B.bond = [B.bond, zeros(V.ncty,H)];
for k = 1:H
    B.bond(:,T+k) = B.R(T+k-1)*B.bond(:,T+k-1) + D.NX(:,T+k);
end

D.T = T + H;

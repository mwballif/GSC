%% One Country Test of Chi Recovery (simplified)
clear; clc; close all;

% Parameters
alpha = 0.3;    % Capital share
beta  = 0.95;   % Discount factor
delta = 0.1;    % Depreciation rate

% Data (fixed, not guessed)
k0 = 3.0;
c0 = 1.2;

% Algorithm parameters
T        = 100;
tol      = 1e-6;
max_iter = 1000;
chi_low  = 0.01;
chi_high = 10;

best_error     = Inf;
best_chi       = NaN;
best_k         = zeros(T,1);
best_c         = zeros(T,1);
path_converged = false;

for iter = 1:max_iter
    chi  = (chi_low + chi_high) / 2;
    k_ss = ( alpha / (chi * (1/beta - (1-delta))) ) ^ (1/(1-alpha));

    k = zeros(T,1); c = zeros(T,1); x = zeros(T,1);
    k(1) = k0; c(1) = c0;
    exploded = false;

    for t = 1:T-1
        x(t)   = (k(t)^alpha - c(t)) / chi;
        k(t+1) = x(t) + (1 - delta) * k(t);
        c(t+1) = c(t) * beta * ( (alpha/chi) * k(t+1)^(alpha-1) + (1 - delta) );

        if x(t) <= 0 || c(t+1) <= 0 || ~isfinite(c(t+1))
            exploded = true; chi_high = chi; break   % consumption collapsed -> chi too high
        elseif k(t+1) > 3*k_ss || k(t+1) < 0
            exploded = true; chi_low = chi; break    % capital overaccumulated -> chi too low
        end
    end

    if exploded, continue, end

    error_term = k(end) - k_ss;
    if abs(error_term) < best_error
        best_error = abs(error_term);
        best_k = k; best_c = c; best_chi = chi;
    end

    if abs(error_term) < tol
        path_converged = true;
        break
    elseif error_term > 0
        chi_high = chi;
    else
        chi_low = chi;
    end
end

if ~path_converged
    warning('Shooting algorithm reached max_iter without hitting strict tolerance. Plotting closest non-exploded path (final error = %.2e).', best_error);
else
    fprintf('Converged (%d iterations)\n', iter);
    fprintf('Recovered chi = %.6f\n', best_chi);
end

%% Plot Results
k_ss_final = ( alpha / (best_chi * (1/beta - (1-delta))) ) ^ (1/(1-alpha));
x_ss_final = delta * k_ss_final;
c_ss_final = k_ss_final^alpha - best_chi * x_ss_final;

figure('Color', 'white', 'Position', [100, 100, 1000, 450]);

subplot(1,2,1);
plot(1:T, best_k, 'LineWidth', 2); hold on;
yline(k_ss_final, '--r', 'Steady State', 'LineWidth', 1.5);
xlabel('Time (t)'); ylabel('Capital (K_t)');
title('Capital Dynamics', 'FontWeight', 'bold'); grid on;

subplot(1,2,2);
plot(1:T, best_c, 'LineWidth', 2, 'Color', 'm'); hold on;
yline(c_ss_final, '--r', 'Steady State', 'LineWidth', 1.5);
xlabel('Time (t)'); ylabel('Consumption (C_t)');
title('Consumption Dynamics', 'FontWeight', 'bold'); grid on;
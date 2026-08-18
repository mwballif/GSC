%% One Country Test of Chi recovery
clear; clc; close all;

% Parameters
alpha = 0.3;   % Capital share
beta  = 0.95;   % Discount factor
delta = 0.1;   % Depreciation rate

% Analytical Steady State
k_ss = ( (1/beta - 1 + delta) / alpha ) ^ ( 1 / (alpha - 1) );
x_ss = delta * k_ss;
c_ss = (k_ss^alpha) - x_ss;


%  Algorithm Parameters
T = 100;            % Time horizon
tol = 1e-6;         % Tolerance for convergence
max_iter = 1000;    % Maximum bisection iterations
k0 = 0.5 * k_ss;    % Start below steady state

% Bisection bracket for initial consumption C_0
c_low = 0.0;
c_high = k0^alpha;   % Upper bound: consume ALL output in period 1

path_converged = false;

% intiate vectors to save within tolerance paths
best_k = zeros(T, 1);
best_c = zeros(T, 1);
best_error = Inf;

% Shooting Loop
for iter = 1:max_iter
    c0 = (c_low + c_high) / 2;

    k = zeros(T, 1);
    c = zeros(T, 1);
    x = zeros(T, 1);
    k(1) = k0;
    c(1) = c0;

    exploded = false;
    explode_type = '';  % 'collapse' or 'overaccumulate'

    for t = 1:T-1
        % Resource constraint: X_t = K_t^alpha - C_t
        x(t) = (k(t)^alpha) - c(t);

        if x(t) <= 0 || c(t) <= 0 || isnan(x(t))
            exploded = true;
            explode_type = 'collapse';
            break;
        end

        % Capital law of motion
        k(t+1) = x(t) + (1 - delta) * k(t);

        % Euler equation for next period consumption
        c(t+1) = c(t) * beta * (alpha * (k(t+1)^(alpha - 1)) + (1 - delta));

        if c(t+1) <= 0 || isnan(c(t+1))
            exploded = true;
            explode_type = 'collapse';
            break;
        end

        if k(t+1) > 3 * k_ss || k(t+1) < 0
            exploded = true;
            explode_type = 'overaccumulate';
            break;
        end
    end

    if exploded
        if strcmp(explode_type, 'overaccumulate')
            c_low = c0;   % consumption too low -> capital exploded upward
        else
            c_high = c0;  % consumption too high -> capital/consumption collapsed
        end
    else
        error_term = k(end) - k_ss;

        % Track the best non-exploded path seen so far
        if abs(error_term) < best_error
            best_error = abs(error_term);
            best_k = k;
            best_c = c;
        end

        if abs(error_term) < tol
            path_converged = true;
            break;
        elseif error_term > 0
            c_low = c0;   % k(T) too HIGH -> c0 was too LOW -> raise lower bound
        else
            c_high = c0;  % k(T) too LOW -> c0 was too HIGH -> lower upper bound
        end
    end
end

if ~path_converged
    warning('Shooting algorithm reached max_iter without hitting strict tolerance. Plotting closest non-exploded path (final error = %.2e).', best_error);
else
    fprintf('Converged ( %d iterations)\n', iter);
    fprintf(' C_0 = %.6f\n', best_c(1));
end

%% 5. Plot Results
figure('Color', 'white', 'Position', [100, 100, 1000, 450]);

subplot(1, 2, 1);
plot(1:T, best_k, 'LineWidth', 2);
hold on;
yline(k_ss, '--r', 'Steady State', 'LineWidth', 1.5);
xlabel('Time (t)', 'FontSize', 11);
ylabel('Capital (K_t)', 'FontSize', 11);
title('Capital Dynamics', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(1, 2, 2);
plot(1:T, best_c, 'LineWidth', 2, 'Color', 'm');
hold on;
yline(c_ss, '--r', 'Steady State', 'LineWidth', 1.5);
xlabel('Time (t)', 'FontSize', 11);
ylabel('Consumption (C_t)', 'FontSize', 11);
title('Consumption Dynamics', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
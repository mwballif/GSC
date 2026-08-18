%% One Country Test of Chi recovery
clear; clc; close all;
% Parameters
alpha = 0.3;   % Capital share
beta  = 0.95;  % Discount factor
delta = 0.1;   % Depreciation rate

% Initial Conditions
k0 = 0.7356;      
c0 = 0.637769;    

%  Algorithm Parameters
T = 100;           
tol = 1e-10;        
max_iter = 1000;    

% Bisection bounds for chi
chi_low  = 0.5;
chi_high = 5.0;

path_converged = false;
% initiate vectors to save within tolerance paths
best_k = zeros(T, 1);
best_c = zeros(T, 1);
best_error = Inf;
best_chi = NaN;

% Shooting Loop
for iter = 1:max_iter
    chi = (chi_low + chi_high) / 2;

    % Steady state depends on the current chi guess
    k_ss = ( alpha / (chi * (1/beta - (1-delta))) ) ^ ( 1 / (1-alpha) );

    k = zeros(T, 1);
    c = zeros(T, 1);
    x = zeros(T, 1);
    k(1) = k0;
    c(1) = c0;
    exploded = false;
    explode_type = '';  % 'collapse' or 'overaccumulate'

    for t = 1:T-1
        % Resource constraint: C_t + chi*X_t = K_t^alpha
        x(t) = (k(t)^alpha - c(t)) / chi;
        if x(t) <= 0 || c(t) <= 0 || isnan(x(t))
            exploded = true;
            explode_type = 'collapse';
            break;
        end
        % Capital law of motion
        k(t+1) = x(t) + (1 - delta) * k(t);
        % Euler equation for next period consumption
        c(t+1) = c(t) * beta * ((alpha/chi) * (k(t+1)^(alpha - 1)) + (1 - delta));
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
            chi_high = chi;   % chi too HIGH -> capital exploded upward
        else
            chi_low = chi;    % chi too LOW  -> collapsed
        end
    else
        error_term = k(end) - k_ss;
        % Track the best non-exploded path seen so far
        if abs(error_term) < best_error
            best_error = abs(error_term);
            best_k = k;
            best_c = c;
            best_chi = chi;
        end
        if error_term > 0
            chi_high = chi;
        else
            chi_low = chi;
        end
    end

    % Converged once the bracket is tight enough
    if (chi_high - chi_low) < tol
        path_converged = true;
        break;
    end
end

if ~path_converged
    warning('Shooting algorithm reached max_iter without narrowing the chi bracket to tolerance.');
else
    fprintf('Converged ( %d iterations)\n', iter);
end
fprintf(' chi = %.8f\n', (chi_low + chi_high)/2);

%% 5. Plot Results
chi_hat = (chi_low + chi_high)/2;
k_ss = ( alpha / (chi_hat * (1/beta - (1-delta))) ) ^ ( 1 / (1-alpha) );
x_ss = delta * k_ss;
c_ss = (k_ss^alpha) - chi_hat * x_ss;

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
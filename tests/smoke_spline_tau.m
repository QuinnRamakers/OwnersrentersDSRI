% PROTO_SPLINE_STRATEGY  Local verification of strategy.spline_tau.
%
%   Checks, for a set of representative 4-knot parameterizations:
%     1. the path passes through every knot exactly,
%     2. all values lie in [0, 1],
%     3. the path is monotone between consecutive knots (no overshoot --
%        the property that motivates PCHIP over a natural cubic spline),
%     4. extrapolation beyond the outermost knots is flat,
%     5. a monotone knot sequence yields a globally monotone path,
%     6. invalid inputs (unsorted ages, fracs outside [0,1], ages outside
%        the model horizon) are rejected.
%   Saves a comparison figure: fig_spline_strategies.png
%
%   Pure construction check -- no solver, runs in seconds.

clear; clc;
p    = config.params();
ages = (p.age0 : p.age0 + p.T - 2).';
n_fail = 0;

%% Representative 4-knot strategies {name, knot_ages, knot_fracs}
CASES = {
    'aggressive_glide', [25 45 60 65], [1.00 0.90 0.30 0.00];
    'classic_glide',    [20 40 55 65], [0.90 0.70 0.40 0.20];
    'flat_ish',         [20 40 60 80], [0.50 0.50 0.50 0.50];
    'late_derisk',      [20 55 62 67], [1.00 1.00 0.50 0.00];
    'hump',             [25 40 55 70], [0.40 0.90 0.60 0.10];  % non-monotone knots
    'edge_knots',       [20 35 50 99], [0.80 0.60 0.30 0.00];  % full horizon span
};

fprintf('=== strategy.spline_tau verification ===\n\n');
for k = 1:size(CASES,1)
    name = CASES{k,1};  ka = CASES{k,2};  kf = CASES{k,3};
    tau  = strategy.spline_tau(p, ka, kf);

    ok = true;
    % 1. hits knots exactly (knot ages are integers on the age grid)
    ki = ka - p.age0 + 1;
    if max(abs(tau(ki) - kf(:))) > 1e-12
        ok = false; fprintf('  FAIL %-16s knots not interpolated\n', name);
    end
    % 2. bounds
    if any(tau < 0) || any(tau > 1)
        ok = false; fprintf('  FAIL %-16s values outside [0,1]\n', name);
    end
    % 3. monotone between consecutive knots
    for j = 1:numel(ka)-1
        seg = tau(ages >= ka(j) & ages <= ka(j+1));
        d   = diff(seg);
        if any(d > 1e-12) && any(d < -1e-12)
            ok = false; fprintf('  FAIL %-16s non-monotone on [%d,%d]\n', name, ka(j), ka(j+1));
        end
    end
    % 4. flat outside knot span
    pre  = tau(ages <= ka(1));   post = tau(ages >= ka(end));
    if any(abs(pre - kf(1)) > 1e-12) || any(abs(post - kf(end)) > 1e-12)
        ok = false; fprintf('  FAIL %-16s extrapolation not flat\n', name);
    end
    % 5. globally monotone if knots are monotone
    if all(diff(kf) <= 0) && any(diff(tau) > 1e-12)
        ok = false; fprintf('  FAIL %-16s knots decreasing but path increases\n', name);
    end

    if ok, fprintf('  PASS %-16s  tau(20)=%.3f  tau(45)=%.3f  tau(64)=%.3f  tau(75)=%.3f\n', ...
            name, tau(1), tau(45-p.age0+1), tau(64-p.age0+1), tau(75-p.age0+1));
    else,  n_fail = n_fail + 1;
    end
end

%% 6. invalid inputs must error
BAD = {
    'unsorted ages',   {[40 25 60 65], [1 .8 .4 0]};
    'frac > 1',        {[25 45 60 65], [1.2 .8 .4 0]};
    'frac < 0',        {[25 45 60 65], [1 .8 .4 -.1]};
    'age past horizon',{[25 45 60 101],[1 .8 .4 0]};
    'age before age0', {[19 45 60 65], [1 .8 .4 0]};
    'single knot',     {50, 0.5};
};
for k = 1:size(BAD,1)
    try
        strategy.spline_tau(p, BAD{k,2}{1}, BAD{k,2}{2});
        n_fail = n_fail + 1;
        fprintf('  FAIL invalid input accepted: %s\n', BAD{k,1});
    catch
        fprintf('  PASS rejects %s\n', BAD{k,1});
    end
end

%% 7. strategy.make_grid / strategy.menu generation (production collection)
M = strategy.menu();                          % 3 knots x 5 levels, monotone
if numel(M) ~= 35                             % multisets: C(5+3-1, 3) = 35
    n_fail = n_fail + 1; fprintf('  FAIL menu default count = %d (want 35)\n', numel(M));
else, fprintf('  PASS menu default -> 35 monotone strategies\n');
end
if numel(strategy.menu([0 .5 1])) ~= 10       % C(3+3-1, 3) = 10
    n_fail = n_fail + 1; fprintf('  FAIL menu 3-level count != 10\n');
else, fprintf('  PASS menu 3 levels -> 10\n');
end
if numel(strategy.menu(0:0.25:1, false)) ~= 125
    n_fail = n_fail + 1; fprintf('  FAIL menu non-monotone count != 125\n');
else, fprintf('  PASS menu monotone_only=false -> 125\n');
end
if numel(strategy.make_grid(p, [20 42.5 65 99], 0:0.25:1, true)) ~= 70  % C(8,4)
    n_fail = n_fail + 1; fprintf('  FAIL make_grid 4-knot count != 70\n');
else, fprintf('  PASS make_grid generalises to 4 knots -> 70\n');
end
names = {M.name};
ok7 = numel(unique(names)) == numel(names);                       % unique names
ok7 = ok7 && isequal(M(1).knot_ages, [20 65 99]);                 % the 3 ages
ok7 = ok7 && all(arrayfun(@(g) all(diff(g.knot_fracs) <= 0), M)); % non-increasing
for k = 1:numel(M)                                                % every one builds
    tau = strategy.spline_tau(p, M(k).knot_ages, M(k).knot_fracs);
    ok7 = ok7 && all(tau >= 0 & tau <= 1) && all(diff(tau) <= 1e-12);
end
if ok7, fprintf('  PASS menu names unique, ages [20 65 99], all 35 paths monotone in [0,1]\n');
else,   n_fail = n_fail + 1; fprintf('  FAIL menu structure/path checks\n');
end

%% Figure: strategies + pchip-vs-cubic overshoot demo
fig = figure('Visible','off', 'Position',[100 100 1100 420]);

subplot(1,2,1); hold on;
for k = 1:size(CASES,1)
    tau = strategy.spline_tau(p, CASES{k,2}, CASES{k,3});
    plot(ages, tau, 'LineWidth', 1.4, 'DisplayName', strrep(CASES{k,1},'_','\_'));
    plot(CASES{k,2}, CASES{k,3}, 'k.', 'MarkerSize', 10, 'HandleVisibility','off');
end
xline(p.retirement_age, ':k', 'HandleVisibility','off');
xlabel('age'); ylabel('\tau_S (pension equity share)');
title('4-knot monotone-spline strategies'); legend('Location','southwest');
ylim([-0.05 1.05]); grid on;

subplot(1,2,2); hold on;
ka = [25 45 60 65];  kf = [1.00 0.90 0.30 0.00];
aq = min(max(ages, ka(1)), ka(end));
plot(ages, interp1(ka, kf, aq, 'spline'), '--', 'LineWidth', 1.4, 'DisplayName','natural cubic (overshoots)');
plot(ages, strategy.spline_tau(p, ka, kf), 'LineWidth', 1.6, 'DisplayName','pchip (monotone)');
plot(ka, kf, 'k.', 'MarkerSize', 12, 'HandleVisibility','off');
xlabel('age'); ylabel('\tau_S');
title('Why PCHIP: no overshoot between knots'); legend('Location','southwest');
ylim([-0.15 1.15]); grid on;

print(fig, 'fig_spline_strategies.png', '-dpng', '-r140');
fprintf('\nFigure saved: fig_spline_strategies.png\n');

if n_fail == 0, fprintf('\nALL CHECKS PASSED\n');
else,           fprintf('\n%d CHECK(S) FAILED\n', n_fail);
end

% SMOKE_SPLINE_TAU  Local verification of strategy.spline_tau.
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
%  A_LO / A_HI are the first and last ages strategy.spline_tau accepts. They
%  are read off p, never written as literals: these cases carried a hardcoded
%  20 from when age0 was 20, and the BKV recalibration to age0 = 25 turned the
%  second case into an uncaught "knot ages must lie in [age0, age0+T-2]" that
%  aborted this whole check. Same landmine as the one in run_spline_strategies.
A_LO = p.age0;                  % 25
A_HI = p.age0 + p.T - 2;        % 99, the last age with a transition
CASES = {
    'aggressive_glide', [25   45 60 65], [1.00 0.90 0.30 0.00];
    'classic_glide',    [A_LO 40 55 65], [0.90 0.70 0.40 0.20];
    'flat_ish',         [A_LO 40 60 80], [0.50 0.50 0.50 0.50];
    'late_derisk',      [A_LO 55 62 67], [1.00 1.00 0.50 0.00];
    'hump',             [25   40 55 70], [0.40 0.90 0.60 0.10];  % non-monotone knots
    'edge_knots',       [A_LO 35 50 A_HI], [0.80 0.60 0.30 0.00];  % full horizon span
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

    if ok, fprintf('  PASS %-16s  tau(%d)=%.3f  tau(45)=%.3f  tau(64)=%.3f  tau(75)=%.3f\n', ...
            name, A_LO, tau(1), tau(45-p.age0+1), tau(64-p.age0+1), tau(75-p.age0+1));
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
% Four knots on the default 9-level fraction grid, monotone: C(9+4-1, 4) = 495.
M = strategy.menu();                          % 4 knots x 9 levels, monotone
N_MENU = 495;                                 % multisets: C(9+4-1, 4) = 495
if numel(M) ~= N_MENU
    n_fail = n_fail + 1; fprintf('  FAIL menu default count = %d (want %d)\n', numel(M), N_MENU);
else, fprintf('  PASS menu default -> %d monotone strategies\n', N_MENU);
end
if numel(strategy.menu([0 .5 1])) ~= 15       % C(3+4-1, 4) = 15
    n_fail = n_fail + 1; fprintf('  FAIL menu 3-level count != 15\n');
else, fprintf('  PASS menu 3 levels -> 15\n');
end
if numel(strategy.menu(0:0.25:1, false)) ~= 625   % 5 levels ^ 4 knots
    n_fail = n_fail + 1; fprintf('  FAIL menu non-monotone count != 625\n');
else, fprintf('  PASS menu monotone_only=false -> 625\n');
end
MENU_AGES = [A_LO, round((A_LO + p.retirement_age)/2), p.retirement_age, A_HI];  % what menu builds
names = {M.name};
ok7 = numel(unique(names)) == numel(names);                       % unique names
ok7 = ok7 && isequal(M(1).knot_ages, MENU_AGES);                  % the 4 ages
ok7 = ok7 && all(arrayfun(@(g) all(diff(g.knot_fracs) <= 0), M)); % non-increasing
for k = 1:numel(M)                                                % every one builds
    tau = strategy.spline_tau(p, M(k).knot_ages, M(k).knot_fracs);
    ok7 = ok7 && all(tau >= 0 & tau <= 1) && all(diff(tau) <= 1e-12);
end
if ok7, fprintf('  PASS menu names unique, ages [%d %d %d %d], all %d paths monotone in [0,1]\n', ...
            MENU_AGES(1), MENU_AGES(2), MENU_AGES(3), MENU_AGES(4), numel(M));
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

% exportgraphics, not print(...,'-dpng',...): print needs a display and hangs
% headless, which is exactly where this now runs from (tests/run_all under
% matlab -batch). Same reasoning as compare_spline_strategies.
fig_file = fullfile(utility.output_dir(), 'fig_spline_strategies.png');
exportgraphics(fig, fig_file, 'Resolution', 140);
fprintf('\nFigure saved: %s\n', fig_file);

if n_fail == 0
    fprintf('\nALL CHECKS PASSED\n');
else
    fprintf('\n%d CHECK(S) FAILED\n', n_fail);
    error('smoke_spline_tau:fail', '%d check(s) failed', n_fail);
end

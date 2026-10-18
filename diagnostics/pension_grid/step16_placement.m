function step16_placement()
%STEP16_PLACEMENT  Step 16 with grid points where households sit: tables and figures.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       step16_placement
%
%   The cases of the placement test (HANDOFF.md, 18 October 2026): u3 evenly
%   spaced instead of at power 2, at 10 and 20 points, with and without a
%   lower top on u1 (lambda_hi 0.3, and 0.2 as a probe) and on q (q_hi 1.3).
%   Prints size_table against u3 at 20 points (power 2 and even) and against
%   the bounded cases, a short life-cycle table per case (consumption,
%   saving, the floored share by age and the off-grid lookups), and draws
%   grid_lifecycles and axis_occupancy for the new cases into the grid
%   study's results folder. Cases not solved yet are skipped.

num = ladder.numerics('standard');
out = fullfile(num.dir, 'pension_grid');
% The trimmed cases put some lookups past the top of u1 and q on purpose;
% lifecycle_points prints the counts once per case instead
w = warning('off', 'paths_lna:offgrid');
cleanup = onCleanup(@() warning(w));

o.p2_10  = 'pow3_24x24_lim_u3p2_qn4';
o.p2_20   = 'pow3_24x24_lim_u3p2_qn4_u3n20';
o.ev_10   = 'pow3_24x24_lim_qn4_u3even';
o.ev_20   = 'pow3_24x24_lim_qn4_u3n20_u3even';
o.ev_10b  = 'pow3_24x24_lim_qn4_u3even_lhi30_qhi13';
o.ev_20b  = 'pow3_24x24_lim_qn4_u3n20_u3even_lhi30_qhi13';
o.probe   = 'pow3_24x24_lim_qn4_u3even_lhi20_qhi13';
r.p2_10   = 'pow3_16x16_lim_u3p2';
r.p2_20   = 'pow3_16x16_lim_u3p2_u3n20';
r.p2_40   = 'pow3_16x16_lim_u3p2_u3n40';
r.ev_10   = 'pow3_16x16_lim_u3even';
r.ev_20   = 'pow3_16x16_lim_u3n20_u3even';
r.ev_10b  = 'pow3_16x16_lim_u3even_lhi30';
r.ev_20b  = 'pow3_16x16_lim_u3n20_u3even_lhi30';

% Placement: against u3 at 20 points, power 2 and even
new_o = string({o.p2_10, o.ev_10, o.ev_10b, o.probe, o.ev_20, o.ev_20b});
size_table(16, 'owner', new_o, o.p2_20);
size_table(16, 'owner', [string(o.p2_10), string(o.p2_20), new_o(2:end)], o.ev_20b);
% Bounds: the same u3 placement with and without the lower tops
size_table(16, 'owner', string({o.ev_10, o.probe}), o.ev_10b);
size_table(16, 'renter', string({r.p2_10, r.ev_10, r.ev_10b, r.p2_20, r.ev_20, r.ev_20b}), r.p2_40);
size_table(16, 'renter', string(r.ev_10), r.ev_10b);
size_table(16, 'renter', string(r.ev_20), r.ev_20b);

lifecycle_points('owner', {o.p2_10, o.ev_10, o.ev_10b, o.probe, o.p2_20, o.ev_20, o.ev_20b});
lifecycle_points('renter', {r.p2_10, r.ev_10, r.ev_10b, r.p2_20, r.ev_20, r.ev_20b, r.p2_40});

rows = struct('name', {'u3 at power 2 (q 4)', 'u3 even (q 4)', 'u3 even, u1 top 0.3, q top 1.3'}, ...
    'cases', {{o.p2_10, o.p2_20}, {o.ev_10, o.ev_20}, {o.ev_10b, o.ev_20b}}, ...
    'labels', {{'u3 10', 'u3 20'}, {'u3 10 even', 'u3 20 even'}, {'u3 10 even, bounds', 'u3 20 even, bounds'}}, ...
    'extra', {'', o.p2_20, o.probe}, ...
    'extra_label', {'', 'u3 20 at power 2', 'u3 10 even, u1 top 0.2, q top 1.3'});
grid_lifecycles(16, 'owner', rows, fullfile(out, 'lifecycles_16_owner_placement.png'), ...
    'Owner, step 16 on bunched 24x24: u3 at power 2 or evenly spaced, and lower tops on u1 and q');
rows = struct('name', {'u3 at power 2', 'u3 even', 'u3 even, u1 top 0.3'}, ...
    'cases', {{r.p2_10, r.p2_20, r.p2_40}, {r.ev_10, r.ev_20}, {r.ev_10b, r.ev_20b}}, ...
    'labels', {{'u3 10', 'u3 20', 'u3 40'}, {'u3 10 even', 'u3 20 even'}, {'u3 10 even, u1 top 0.3', 'u3 20 even, u1 top 0.3'}}, ...
    'extra', {'', r.p2_40, r.p2_40}, ...
    'extra_label', {'', 'u3 40 at power 2', 'u3 40 at power 2'});
grid_lifecycles(16, 'renter', rows, fullfile(out, 'lifecycles_16_renter_placement.png'), ...
    'Renter, step 16 on bunched 16x16: u3 at power 2 or evenly spaced, and a lower top on u1');

% Where households sit, on each new case's own panel, against the old and new grids
g = {o.p2_10, o.ev_10b, o.ev_20b};
lab = {'u3 10 power 2, tops 0.55 / 2.5', 'u3 10 even, tops 0.3 / 1.3', 'u3 20 even, tops 0.3 / 1.3'};
occ('owner', o.ev_10b, g, lab, fullfile(out, 'occupancy_16_owner_even10.png'));
occ('owner', o.ev_20b, g, lab, fullfile(out, 'occupancy_16_owner_even20.png'));
g = {r.p2_10, r.ev_10b, r.ev_20b};
lab = {'u3 10 power 2, top 0.58', 'u3 10 even, top 0.3', 'u3 20 even, top 0.3'};
occ('renter', r.ev_10b, g, lab, fullfile(out, 'occupancy_16_renter_even10.png'));
occ('renter', r.ev_20b, g, lab, fullfile(out, 'occupancy_16_renter_even20.png'));
end

function occ(arm, panel, grids, labels, file)
if isempty(case_load(16, arm, panel)), fprintf('%s (%s) not solved, no %s\n', panel, arm, file); return; end
T = axis_occupancy(16, arm, panel, grids, labels, file);
disp(T);
end

function lifecycle_points(arm, cases)
% A few points of each case's simulated life cycle (multiples of mean income
% at 25), the floored share by age, and the policy lookups off each axis.
ac = [30 40 50 55 60 66 80 90];
af = [40 55 67 80 90 95];
fprintf('\n%s, step 16: mean consumption at %s; median at 55 / 60; mean liquid saving at 50 / 66;\n', ...
    arm, mat2str(ac));
fprintf('floored %% at %s; off-grid lookups (u1 u2 u3 q)\n', mat2str(af));
for i = 1:numel(cases)
    rr = case_load(16, arm, cases{i});
    if isempty(rr), fprintf('%-46s not solved\n', cases{i}); continue; end
    s = figures.panel_data(rr).sim; a = s.ages(:).'; Y0 = mean(s.Y(:, 1));
    at = @(v, x) v(arrayfun(@(y) find(a == y), x));
    C = mean(s.C, 1) / Y0; Cm = median(s.C, 1) / Y0; X = mean(s.X, 1) / Y0; F = 100 * mean(s.floored, 1);
    fprintf('%-46s C %s | med %s | X %s | fl %s | off %s\n', cases{i}, ...
        sprintf('%.3f ', at(C, ac)), sprintf('%.3f ', at(Cm, [55 60])), sprintf('%.1f ', at(X, [50 66])), ...
        sprintf('%.1f ', at(F, af)), mat2str(rr.checks.offgrid));
end
end

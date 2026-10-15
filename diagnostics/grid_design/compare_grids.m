function T = compare_grids(opts)
%COMPARE_GRIDS  How far each step-7 grid's answer is from a dense reference.
%
%   T = compare_grids()                      owner, reference logwealth_64x48
%   T = compare_grids(ref="uniform_64x48")
%   T = compare_grids(owner=false)
%
%   Loads the step-7 solves on the current grid (16x16 as run, the income axis
%   doubled from ladder.robustness(7)) and every solve_grids result, and prints
%   for each the largest gap to the reference over ages 26-95 in the mean
%   liquid equity share, mean consumption (%) and mean liquid savings (years of
%   income), with the bankruptcy share and the value at entry. All means are
%   over the same simulated households (same seed). Draws the robustness page
%   and the overlay dashboard when dashboards=true.
%
%   T = compare_grids(b0=1, out=folder)   every solve simulated from starting
%   savings of 1 year of gross income (restart_sim); figures go to folder.

arguments
    opts.ref (1,:) char = 'logwealth_64x48'
    opts.owner (1,1) logical = true
    opts.dashboards (1,1) logical = true
    opts.b0 double = []
    opts.out (1,:) char = ''
end

repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(repo);
addpath(fullfile(repo, 'diagnostics', 'step07'));
res = fullfile(repo, 'ladder', 'standard_16x16x10_gh5');
gd  = fullfile(res, 'grid_design');
figdir = gd; if ~isempty(opts.out), figdir = opts.out; end
if ~isfolder(figdir), mkdir(figdir); end
ten = 'renter'; if opts.owner, ten = 'owner'; end

R = struct('name', {}, 'r', {});
R(end+1) = struct('name', 'uniform_16x16', 'r', load(fullfile(res, sprintf('07_housing_%s.mat', ten))));
R(end+1) = struct('name', 'uniform_32x16', 'r', load(fullfile(res, 'robustness', sprintf('07_housing_%s_dense_u1.mat', ten))));
f = dir(fullfile(gd, sprintf('%s_*.mat', ten)));
for i = 1:numel(f)
    s = load(fullfile(gd, f(i).name));
    R(end+1) = struct('name', erase(erase(f(i).name, [ten '_']), '.mat'), 'r', s.r); %#ok<AGROW>
end
if ~isempty(opts.b0)
    for i = 1:numel(R), R(i).r = restart_sim(R(i).r, opts.b0); end
end
iref = find(strcmp({R.name}, opts.ref));
assert(~isempty(iref), 'compare_grids:ref', 'no saved solve %s', opts.ref);
s0 = R(iref).r.summary; a = s0.ages; w = a > 25 & a <= 95; w2 = a(1:end-1) > 25;

T = table();
for i = 1:numel(R)
    r = R(i).r; s1 = r.summary;
    dpi = abs(s1.pi(1:end-1) - s0.pi(1:end-1));
    dC  = abs(s1.C.mean ./ s0.C.mean - 1);
    dX  = abs(s1.X.mean - s0.X.mean) ./ s0.Y.mean;
    T = [T; table(string(R(i).name), r.p.N_u1, r.p.N_u2, max(dpi(w2)), 100 * max(dC(w)), max(dX(w)), ...
        100 * r.checks.floored_share, 100 * mean(s1.floored(a >= 85 & a <= 95)), 100 * r.checks.c_bound_25_39, ...
        r.checks.ce_entry, r.timing.solve_sec, 'VariableNames', {'grid', 'N_u1', 'N_u2', 'max_dpi', 'max_dC_pct', ...
        'max_dX_inc', 'floored_pct', 'floored_85_95_pct', 'bound_25_39_pct', 'entry_value', 'solve_s'})]; %#ok<AGROW>
end
T = sortrows(T, {'N_u1', 'grid'});
fprintf('\nStep 7 %s, gaps to %s over ages 26-95\n', ten, opts.ref);
disp(T);

if ~opts.dashboards, return; end
pick = @(names) arrayfun(@(n) R(strcmp({R.name}, n)).r, names, 'UniformOutput', false);
lab  = @(names) cellfun(@(n) strrep(strrep(n, '_', ' '), 'logwealth', 'log-wealth'), cellstr(names), 'UniformOutput', false);
cur = intersect(["uniform_16x16", "uniform_32x16", "uniform_32x32", "uniform_64x48"], string({R.name}), 'stable');
new = setdiff(intersect(["logwealth_16x16", "logwealth_32x32", "logwealth_64x48", "logwealth_128x96"], ...
    string({R.name}), 'stable'), string(opts.ref), 'stable');
edg = intersect(["edge_16x16", "edge_32x32"], string({R.name}), 'stable');
pw  = setdiff(intersect(["power_16x16", "power3_16x16", "power_32x32", "power3_32x32", "power_64x48"], ...
    string({R.name}), 'stable'), string(opts.ref), 'stable');
cur = setdiff(cur, string(opts.ref), 'stable');
groups = struct('name', {'Current grid', 'Log-wealth grid', 'Edge-aligned grid', 'Power grid'}, ...
                'rs', {pick(cur), pick(new), pick(edg), pick(pw)}, 'labels', {lab(cur), lab(new), lab(edg), lab(pw)});
groups = groups(~cellfun(@isempty, {groups.rs}));
ttl = sprintf('Step 7 %s: every grid against the %s solve', ten, strrep(opts.ref, '_', ' '));
figures.robustness(R(iref).r, strrep(opts.ref, '_', ' '), groups, ttl, ...
    fullfile(figdir, sprintf('robustness_%s_vs_%s.png', ten, opts.ref)));
ov = [string(opts.ref), setdiff(intersect(["logwealth_64x48", "power_64x48", "logwealth_32x32", "power_32x32", ...
    "uniform_16x16"], string({R.name}), 'stable'), string(opts.ref), 'stable')];
figures.compare(pick(ov), lab(ov), sprintf('Step 7 %s: current, log-wealth and power grids', ten), ...
    fullfile(figdir, sprintf('compare_%s.png', ten)));
end

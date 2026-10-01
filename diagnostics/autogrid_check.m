function autogrid_check(out_dir, want, tag)
%AUTOGRID_CHECK  Is the automatic grid better than the hand-set one?
%
%   Three placements at the same node count, measured the way the causal
%   experiment measured its arms: simulate each and compare the paths with the
%   8064-node reference already in grid_convergence.mat. Levels of welfare are
%   not comparable across grids, so the comparison is on the decisions.
%
%     baseline      the wide default axes
%     hand-trimmed  lambda_hi 0.26, u2_lo 0.55, grid_pow 2.2, u3_hi 0.95,
%                   the values measured off the production renter
%     automatic     utility.auto_state_grids, no constants
%
%   The automatic arm is the one that has to justify itself: it should land at
%   least as close to the reference as the hand-set arm, without being told
%   anything about this calibration.
%
%   Also reports whether any simulated household fell off an axis, which is the
%   failure the hand-set arm risks when a calibration moves.

%   want names the arms to run and tag names the result file, so several arms
%   can run in separate MATLAB processes without fighting over one .mat; the
%   report gathers every autogrid_check*.mat it finds. An automatic arm can
%   carry its margin in the name, 'automatic m=0.10', which is the share of
%   nodes it spends outside the occupied band.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
if nargin < 2 || isempty(want), want = {'baseline', 'hand-trimmed', 'automatic'}; end
if nargin < 3 || isempty(tag),  tag = ''; end
res = fullfile(out_dir, sprintf('autogrid_check%s.mat', tag));
DIM = [16 16 10];

R = struct('arm', {}, 'N', {}, 'n', {}, 'sec', {}, 'sim', {}, 'offgrid', {});
if isfile(res), L = load(res); R = L.R; end

arms = want;
for i = 1:numel(arms)
    if any(strcmp({R.arm}, arms{i})), continue; end
    fprintf('[%s] %s ...\n', datestr(now, 'HH:MM:SS'), arms{i});          %#ok<TNOW1,DATST>
    [s, N, sec, off] = run_arm(arms{i}, DIM);
    R(end+1).arm = arms{i}; R(end).N = N; R(end).n = prod(N);             %#ok<AGROW>
    R(end).sec = sec; R(end).sim = s; R(end).offgrid = off;
    save(res, 'R', '-v7.3');
    fprintf('   %s = %d nodes | %.0f s | %d off-grid lookups\n', mat2str(N), prod(N), sec, off);
end
report(R, out_dir);
end

% ------------------------------------------------------------------------
function [s, N, sec, off] = run_arm(arm, dim)
p = config.params(); p.is_owner = false;
p.grid_mode = 'none'; p.polish_ver = 2; p.polish_algo = 'active-set';
p.use_refine = true; p.refine_stage = 'pre';
p.refine_pi_global = true; p.refine_c_global = true;

switch arm
    case 'baseline'
        p.lambda_lo = 0.0008; p.lambda_hi = 0.44; p.grid_pow = 1.6;
        p.u2_lo = 0.40; p.grid_pow_u2 = 1; p.u3_lo = 0.02; p.u3_hi = 0.98;
        p = utility.build_state_grids(p, dim, 5);
    case 'hand-trimmed'
        p.lambda_lo = 0.0008; p.lambda_hi = 0.26; p.grid_pow = 2.2;
        p.u2_lo = 0.55; p.grid_pow_u2 = 1; p.u3_lo = 0.02; p.u3_hi = 0.95;
        p = utility.build_state_grids(p, dim, 5);
    otherwise
        assert(startsWith(arm, 'automatic'), 'autogrid_check:arm', 'unknown arm %s.', arm);
        o = struct('verbose', false);
        m = regexp(arm, 'm=([0-9.]+)', 'tokens', 'once');
        if ~isempty(m), o.margin = str2double(m{1}); end
        if contains(arm, 'pad'), o.pad = 0.25; end
        if contains(arm, 'panel')
            % Occupancy from a panel already trusted for this calibration,
            % which is what the pilot is a cheap stand-in for.
            Q = load(fullfile(fileparts(mfilename('fullpath')), 'occupancy_src.mat'));
            o.sim = Q.s;
        end
        p = utility.auto_state_grids(p, dim, 5, o);
end
N = [p.N_u1 p.N_u2 p.N_u3];

[~, mg, sl] = config.income_profile(p);
pf.mu_growth = mg; pf.sigma_l_log = sl; pf.p_surv = config.survival(p);
sk = grids.shock_grid(p); an = pension.annuity_price(p, pf, sk);
tic; sol = solver.solve_lifecycle_lna(p, pf, sk, an); sec = toc;

% count off-grid lookups by catching the simulator's own warning
w = warning('off', 'all'); lastwarn('');
sim = simulate.forward(p, pf, sol, an, 6000, 20260511, p.b0);
[msg, ~] = lastwarn; warning(w);
off = 0;
tok = regexp(msg, '(\d+) of \d+ household-year', 'tokens', 'once');
if ~isempty(tok), off = str2double(tok{1}); end
s = h1_summary(p, sim);
end

% ------------------------------------------------------------------------
function report(~, out_dir)
% Gather every result file, so arms run in separate processes report together.
R = struct('arm', {}, 'N', {}, 'n', {}, 'sec', {}, 'sim', {}, 'offgrid', {});
F = dir(fullfile(out_dir, 'autogrid_check*.mat'));
for i = 1:numel(F)
    L = load(fullfile(out_dir, F(i).name));
    if ~isfield(L, 'R'), continue; end
    for k = 1:numel(L.R)
        if ~any(strcmp({R.arm}, L.R(k).arm)), R(end+1) = L.R(k); end       %#ok<AGROW>
    end
end
if isempty(R), fprintf('nothing solved\n'); return; end
[~, o] = sort({R.arm}); R = R(o);

B = load(fullfile(out_dir, 'grid_convergence.mat')); RB = B.R;
b5 = find([RB.gh] == 5); [~, o] = sort([RB(b5).n]); b5 = b5(o);
ref = RB(b5(end)).sim;
fprintf('\n=== distance from the %d-node reference, all arms at the same node count ===\n', RB(b5(end)).n);
fprintf('%-14s %-14s %6s %8s %12s %12s %12s %10s\n', 'arm', 'cube', 'nodes', 'sec', ...
    'dpi acc', 'dpi ret', 'dC/C', 'off-grid');
for k = 1:numel(R)
    s = R(k).sim;
    acc = s.ages <= 55; ret = s.ages >= 67;
    dpi = s.pi_liq - ref.pi_liq;
    dC  = (s.C - ref.C) ./ max(ref.C, eps);
    fprintf('%-14s %-14s %6d %8.0f %12.4f %12.4f %12.4f %10d\n', R(k).arm, mat2str(R(k).N), ...
        R(k).n, R(k).sec, sqrt(mean(dpi(acc).^2)), sqrt(mean(dpi(ret).^2)), ...
        sqrt(mean(dC.^2)), R(k).offgrid);
end
end

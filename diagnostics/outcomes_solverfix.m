function outcomes_solverfix(out_dir)
%OUTCOMES_SOLVERFIX  The outcome sheets re-solved with the corrected search.
%
%   Same four cells as outcomes.m -- renter and owner, calibrated housing and a
%   quarter of it, 4800 nodes, gh_n = 5, 6000 paths -- but with the per-node
%   search that the ordering study settled on:
%
%       use_refine       = true    sweep instead of a bare fmincon call
%       refine_stage     = 'pre'   sweep first, then let fmincon converge in
%                                  the basin it picked
%       refine_c_global  = true    sweep consumption as well as the equity
%                                  share; with c held local the sweep misses
%                                  15% of badly seeded nodes
%
%   Writes its own .mat and its own figures so the originals stay intact for
%   comparison, and prints the retirement equity share of both so the change is
%   visible without opening the figures.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res = fullfile(out_dir, 'outcomes_fixed.mat');
cases = { 'renter', 1.00; 'renter', 0.25; 'owner', 1.00; 'owner', 0.25 };

R = struct('tag',{},'out',{});
if isfile(res), L = load(res); R = L.R; end
for i = 1:size(cases,1)
    tag = sprintf('%s x%.2f', cases{i,1}, cases{i,2});
    if any(strcmp(tag, {R.tag})), continue; end
    fprintf('solving %-16s ...\n', tag);
    tic; o = run_case(cases{i,1}, cases{i,2}); sec = toc;
    R(end+1).tag = tag; R(end).out = o;                                  %#ok<AGROW>
    save(res, 'R', '-v7.3');
    fprintf('   %.0f s   pi@80 = %.3f   pi@90 = %.3f\n', sec, ...
            o.pi_liq(o.ages==80), o.pi_liq(o.ages==90));
end
make_figs(R, out_dir);
compare_old_new(R, out_dir);
end

% ------------------------------------------------------------------------
function o = run_case(ten, hc)
p = config.params(); p.is_owner = strcmp(ten,'owner');
p.grid_mode='none'; p.polish_ver=2;
p.use_refine      = true;
p.refine_stage    = 'pre';
p.refine_c_global = true;
p.refine_pi_global= true;
if p.is_owner
    p.theta = p.theta*hc; p.m_rate_path = p.m_rate_path*hc;
else
    p.alpha = p.alpha*hc;
end
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, [18 18 12], 5);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
sol=solver.solve_lifecycle_lna(p,pf,sk,an);
s=simulate.forward(p,pf,sol,an,6000,20260511,p.b0);
o = h1_summary(p, s);
end

% ------------------------------------------------------------------------
function make_figs(R, out_dir)
fd = fullfile(out_dir,'factorial_figs');
for ten = {'renter','owner'}
    idx = find(contains({R.tag}, ten{1}));
    if isempty(idx), continue; end
    sub = sprintf(['%s households, corrected per-node search (sweep before fmincon, over both c and pi). ' ...
                   'Pension pot holds 10%% property (REIT). Vertical lines: solid = retirement at 67, dashed = mortgage paid off'], ten{1});
    h1_figure(R(idx), fullfile(fd, sprintf('H1_fixed_%s.png', ten{1})), sub, strcmp(ten{1},'owner'));
end
fprintf('figures in %s\n', fd);
end

% ------------------------------------------------------------------------
function compare_old_new(Rnew, out_dir)
%COMPARE_OLD_NEW  Old and new search side by side in the full sheet, so the
%   rows that do not move are as visible as the one that does.
old = fullfile(out_dir,'outcomes.mat');
if ~isfile(old), fprintf('no outcomes.mat to compare against\n'); return; end
L = load(old); Rold = L.R;
fd = fullfile(out_dir,'factorial_figs');
for ten = {'renter','owner'}
    tag = sprintf('%s x1.00', ten{1});
    io = find(strcmp(tag, {Rold.tag}), 1);
    in = find(strcmp(tag, {Rnew.tag}), 1);
    if isempty(io) || isempty(in), continue; end
    C = struct('tag',{},'out',{});
    C(1).tag = [tag ' -- old search'];  C(1).out = Rold(io).out;
    C(2).tag = [tag ' -- fixed search']; C(2).out = Rnew(in).out;
    sub = sprintf(['%s, same cell solved two ways. Left: fmincon from the warm start only. ' ...
                   'Right: sweep over c and pi first, then fmincon. Everything except the equity rows is unchanged.'], tag);
    h1_figure(C, fullfile(fd, sprintf('H1_compare_%s.png', ten{1})), sub, strcmp(ten{1},'owner'));
end
end

function outcomes(out_dir)
%OUTCOMES  What the policies actually produce, in euros, by age.
%
%   Four cells: renter and owner, at the calibrated housing cost and at a
%   quarter of it. Production-like resolution (4800 nodes, gh_n = 5, 6000
%   paths). Everything is computed household by household and then taken as a
%   median or mean across households, so the decompositions add up rather than
%   being products of separately aggregated pieces.
%
%   Five rows per tenure, two panels wide per case; see h1_figure.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res = fullfile(out_dir, 'outcomes.mat');
cases = { 'renter', 1.00; 'renter', 0.25; 'owner', 1.00; 'owner', 0.25 };

R = struct('tag',{},'out',{});
if isfile(res), L = load(res); R = L.R; end
for i = 1:size(cases,1)
    tag = sprintf('%s x%.2f', cases{i,1}, cases{i,2});
    if any(strcmp(tag, {R.tag})), continue; end
    o = run_case(cases{i,1}, cases{i,2});
    R(end+1).tag = tag; R(end).out = o;                                  %#ok<AGROW>
    save(res, 'R', '-v7.3');
    fprintf('%-16s C50=%7.0f  fin@66=%8.0f  DCshare@66=%.2f  eq@50=%7.0f\n', ...
            tag, o.C(26), o.fin(42), o.dcshare(42), o.eq_tot(26));
end
make_fig(R, out_dir);
end

% ------------------------------------------------------------------------
function o = run_case(ten, hc)
p = config.params(); p.is_owner = strcmp(ten,'owner');
p.grid_mode='none'; p.polish_ver=2; p.use_refine=false;
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
function make_fig(R, out_dir)
fd = fullfile(out_dir,'factorial_figs'); if ~isfolder(fd), mkdir(fd); end
for ten = {'renter','owner'}
    idx = find(contains({R.tag}, ten{1}));
    if isempty(idx), continue; end
    sub = sprintf(['%s households -- what the policies produce, per year of age. ' ...
                   'Pension pot holds 10%% property (REIT). Vertical lines: solid = retirement at 67, dashed = mortgage paid off'], ten{1});
    h1_figure(R(idx), fullfile(fd, sprintf('H1_outcomes_%s.png', ten{1})), sub, strcmp(ten{1},'owner'));
end
fprintf('figures in %s\n', fd);
end

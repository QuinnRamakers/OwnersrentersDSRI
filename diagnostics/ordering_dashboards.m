function ordering_dashboards(out_dir)
%ORDERING_DASHBOARDS  The full outcome sheet, one column per search routine.
%
%   Same renter cell solved four ways, so every panel of the dashboard can be
%   compared across search routines rather than across household types:
%
%     A no sweep              fmincon from the warm start, what ships today
%                             with use_refine off
%     B sweep pi after        the shipped refinement
%     E sweep pi and c before the ordering study's best arm
%     F sweep c before        consumption only, to show pi is not special
%
%   C (sweep pi and c after) and D (sweep pi before) are left out: C lands on
%   E and D lands on B, so they add two columns and no information.
%
%   Reduced cube (12x12x8, gh_n = 3, 2000 paths) so all four fit in one run.
%   Levels are therefore not comparable with the production sheets; the
%   comparison across columns is the point.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res = fullfile(out_dir,'ordering_dash.mat');

V = { 'A no sweep',              0, 'post', 1, 0
      'B sweep pi after',        1, 'post', 1, 0
      'E sweep pi and c before', 1, 'pre',  1, 1
      'F sweep c before',        1, 'pre',  0, 1 };

R = struct('tag',{},'out',{},'sec',{});
if isfile(res), L = load(res); R = L.R; end
for i = 1:size(V,1)
    if any(strcmp(V{i,1}, {R.tag})), continue; end
    fprintf('solving %-26s ...\n', V{i,1});
    tic; o = run_one(V{i,2}, V{i,3}, V{i,4}, V{i,5}); sec = toc;
    R(end+1).tag = V{i,1}; R(end).out = o; R(end).sec = sec;             %#ok<AGROW>
    save(res,'R','-v7.3');
    fprintf('   %.0f s   pi@80 = %.3f   pi@90 = %.3f\n', sec, ...
            o.pi_liq(o.ages==80), o.pi_liq(o.ages==90));
end

% One sheet per routine, single housing cost. Two passes so that separate
% figures share a y-axis and can be compared by flipping between them.
fd = fullfile(out_dir,'factorial_figs');
tmp = tempname; L = [];
for i = 1:numel(R)
    li = h1_figure(R(i), [tmp sprintf('_%d.png',i)], 'scratch', false);
    if isempty(L), L = li; else
        L(:,1) = min(L(:,1), li(:,1));
        L(:,2) = max(L(:,2), li(:,2));
    end
end
delete([tmp '_*.png']);
for i = 1:numel(R)
    nm = regexprep(R(i).tag, '[^A-Za-z0-9]+', '_');
    sub = sprintf(['renter, calibrated housing -- search routine: %s. ' ...
        '12x12x8 cube, gh_n=3, 2000 paths. All four sheets share one y-axis per panel, ' ...
        'so they can be compared directly.'], R(i).tag);
    h1_figure(R(i), fullfile(fd, sprintf('H1_search_%s.png', nm)), sub, false, L);
end
fprintf('figures in %s\n', fd);

fprintf('\n%-26s %7s %9s %9s %9s\n','routine','sec','pi@70','pi@80','pi@90');
for i = 1:numel(R)
    a = R(i).out.ages;
    fprintf('%-26s %7.0f %9.3f %9.3f %9.3f\n', R(i).tag, R(i).sec, ...
        R(i).out.pi_liq(a==70), R(i).out.pi_liq(a==80), R(i).out.pi_liq(a==90));
end
end

% ------------------------------------------------------------------------
function o = run_one(ref, stage, piglob, cglob)
p = config.params(); p.is_owner = false;
p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set';
p.use_refine=ref; p.refine_stage=stage;
p.refine_pi_global=piglob; p.refine_c_global=cglob;
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, [12 12 8], 3);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
sol=solver.solve_lifecycle_lna(p,pf,sk,an);
s=simulate.forward(p,pf,sol,an,2000,20260511,p.b0);
o = h1_summary(p, s);
end

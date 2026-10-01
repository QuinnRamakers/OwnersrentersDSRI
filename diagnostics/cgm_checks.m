function C = cgm_checks(opts)
%CGM_CHECKS  Fidelity and correctness checks on the CGM core (rung 0).
%
%   C = cgm_checks()
%
%   Three solves of rung 0:
%
%     base       the ladder's rung 0 (gamma = 5, the production value).
%     gamma10    the same at CGM's own benchmark risk aversion of 10. CGM
%                report that lowering gamma raises the share but that the
%                effect is muted by the borrowing and short-sale constraints,
%                so the two should differ less than the complete-markets
%                formula mu/(gamma sigma^2) implies.
%     cgm_const  the same as base but with CGM's Table 2 intercept for the
%                high-school group (-2.1700) in place of the repo's 0.530339.
%
%   The third is a CORRECTNESS check, not a calibration variant. The model is
%   homothetic in W and rung 0 has no contributions, so nothing in it depends
%   on the absolute level of income: the franchise is inactive at kappa = 0,
%   the consumption floor is a fraction of income, and the welfare anchors are
%   in years of income. Rescaling income by a constant must therefore leave
%   pi(age) and the consumption FRACTION exactly unchanged, and scale the
%   consumption LEVEL by that constant. If it does not, something in the solver
%   depends on the level of income that should not.
%
%   That check matters here because the repo's 'poly' intercept differs from
%   CGM's by a factor of about 15, and the repo rescales again on top -- so
%   rung 0's income is not in euros and its levels are not comparable with the
%   other rungs.

if nargin < 1 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'dims'),  opts.dims  = [16 12 10]; end
if ~isfield(opts, 'gh_n'),  opts.gh_n  = 5; end
if ~isfield(opts, 'N_sim'), opts.N_sim = 4000; end
if ~isfield(opts, 'seed'),  opts.seed  = 12345; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here);
cd(fileparts(here));
if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('cgm_checks:pool', 'no pool'); end
end

specs = {
    'base',      5,  []
    'gamma10',  10,  []
    'cgm_const', 5, -2.1700
    };

C = struct([]);
for k = 1:size(specs, 1)
    [p, ~] = ablation_config(0, struct('dims', opts.dims, 'gh_n', opts.gh_n, ...
                                       'gamma', specs{k,2}));
    if ~isempty(specs{k,3})
        p.income_coef(1) = specs{k,3};
    end
    fprintf('\n-- %s (gamma=%g, intercept=%.4f) --\n', ...
        specs{k,1}, p.gamma, p.income_coef(1));

    [~, mg, sl] = config.income_profile(p);
    profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
    sh  = grids.shock_grid(p);
    ap  = pension.annuity_price(p, profile, sh);
    sol = solver.solve(p, profile, sh, ap);
    sim = simulate.forward(p, profile, sol, ap, opts.N_sim, opts.seed, p.b0);

    n   = min(size(sim.pi, 2), p.T - 1);
    e = struct('name', specs{k,1}, 'gamma', p.gamma, ...
               'intercept', p.income_coef(1), ...
               'ages', sim.ages(1:n), ...
               'pi', mean(sim.pi(:,1:n), 1, 'omitnan'), ...
               'c_frac', mean(sim.c_frac(:,1:n), 1, 'omitnan'), ...
               'C', mean(sim.C, 1, 'omitnan'), ...
               'Y', mean(sim.Y, 1, 'omitnan'));
    a = e.ages;
    fprintf('   pi: 25-35 %.3f | 45-55 %.3f | 70-85 %.3f | Y(25) %.4g | C(25) %.4g\n', ...
        mean(e.pi(a>=25 & a<35)), mean(e.pi(a>=45 & a<55)), ...
        mean(e.pi(a>=70 & a<85)), e.Y(1), e.C(1));
    if isempty(C), C = e; else, C(end+1) = e; end %#ok<AGROW>
end

% -- homotheticity check: base vs cgm_const --------------------------------
ib = find(strcmp({C.name}, 'base'), 1);
ic = find(strcmp({C.name}, 'cgm_const'), 1);
if ~isempty(ib) && ~isempty(ic)
    dpi = max(abs(C(ib).pi     - C(ic).pi));
    dcf = max(abs(C(ib).c_frac - C(ic).c_frac));
    scale_Y = C(ic).Y(1) / C(ib).Y(1);
    scale_C = C(ic).C(1) / C(ib).C(1);
    fprintf(['\n=== HOMOTHETICITY CHECK (income level rescaled by %.4g) ===\n' ...
             '  max |d pi(age)|      = %.3g   (should be ~0)\n' ...
             '  max |d c_frac(age)|  = %.3g   (should be ~0)\n' ...
             '  C level scale factor = %.6f  (should equal the income scale %.6f)\n'], ...
        scale_Y, dpi, dcf, scale_C, scale_Y);
    if dpi < 1e-6 && dcf < 1e-6
        fprintf('  PASS: policies are invariant to the income level.\n');
    else
        fprintf(['  FAIL: a policy moved when only the income LEVEL changed.\n' ...
                 '        Something in the solve depends on the absolute level of income.\n']);
    end
end

% -- gamma comparison -------------------------------------------------------
ig = find(strcmp({C.name}, 'gamma10'), 1);
if ~isempty(ib) && ~isempty(ig)
    fprintf('\n=== RISK AVERSION (CGM benchmark gamma = 10) ===\n');
    fprintf('  %-10s %8s %8s %8s\n', 'gamma', '25-35', '45-55', '70-85');
    for j = [ib ig]
        a = C(j).ages;
        fprintf('  %-10g %8.3f %8.3f %8.3f\n', C(j).gamma, ...
            mean(C(j).pi(a>=25 & a<35)), mean(C(j).pi(a>=45 & a<55)), ...
            mean(C(j).pi(a>=70 & a<85)));
    end
    fprintf('  complete-markets mu/(gamma sigma^2): gamma 5 -> %.3f, gamma 10 -> %.3f\n', ...
        0.04/(5*0.157^2), 0.04/(10*0.157^2));
end

save(fullfile(here, 'cgm_checks.mat'), 'C', 'opts', '-v7.3');
fprintf('\nSaved %s\n', fullfile(here, 'cgm_checks.mat'));
end

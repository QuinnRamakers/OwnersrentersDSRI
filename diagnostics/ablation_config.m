function [p, meta] = ablation_config(rung, opts)
%ABLATION_CONFIG  CGM-anchored ablation ladder for the pi(age) diagnosis.
%
%   [p, meta] = ablation_config(rung)
%   [p, meta] = ablation_config(rung, opts)
%
%   Builds the p-struct for one rung of a cumulative ablation. Rung 0 strips the
%   model back to a Cocco, Gomes & Maenhout (2005) core; each later rung
%   switches one of this model's own features back on, until rung 6 is the
%   production model. CGM is the anchor because its life-cycle result is known:
%   hump-shaped consumption, and a liquid equity share that starts pinned at the
%   1.0 constraint while human capital is large and then falls SMOOTHLY with
%   age. If rung 0 reproduces that and some later rung does not, the feature
%   switched on at that rung is what makes pi indeterminate.
%
%   rung is an index 0..6 or the matching name:
%     0 'cgm'      CGM core: no taxes, no DC, no housing, no REIT
%     1 'income'   + Dutch income profile and AOW-only replacement
%     2 'housing'  + housing / rent
%     3 'dc'       + DC pension (contributions, glide, annuity)
%     4 'inctax'   + EET income tax on wages, AOW and annuity
%     5 'cgt'      + box-3 capital-gains tax, no loss offset
%     6 'reit'     + DC REIT leg                    == the production model
%
%   opts fields (all optional):
%     gamma      risk aversion held across the ladder      (default 5, the
%                production value; use 10 for CGM's own baseline)
%     is_owner   tenure                                    (default false)
%     dims       [N1 N2 N3] state grid                     (default [20 14 12])
%     gh_n       Gauss-Hermite nodes per shock             (default 5)
%     gh_n_reit  GH nodes for the REIT shock               (default = gh_n)
%     cg_loss_offset  symmetric CGT, losses rebated        (default false)
%     phi_floor  override the consumption floor            (default: params)
%
%   The last two are counterfactual probes rather than rungs. Use them to re-run
%   a rung against the two suspects for an indeterminate pi: the no-loss-offset
%   CGT, which removes most of the after-tax equity premium, and the 1e-6
%   consumption floor, which puts a value cliff at low liquid wealth.
%
%   meta reports what the rung turned on and every deviation from CGM, so a
%   result can be read without re-deriving the configuration.
%
%   HELD FIXED across every rung, deliberately: gamma, beta, chi, age range,
%   retirement age, consumption floor, the state grid and the shock-node counts.
%   A rung-to-rung change in pi(age) is then attributable to the feature that
%   was switched on and to nothing else. The cost is that rung 0 is not a
%   numerical reproduction of CGM's published table -- their horizon (20-100),
%   retirement age (65) and transitory income shock differ -- it is CGM's
%   ECONOMICS inside this model's time structure. meta.deviations lists them.
%
%   The one axis that cannot be held fixed is the lambda = Y/W range. With no
%   housing lambda spans the full [0,1]; with housing it is capped near
%   1/(1+h_mult), because W >= H + Y. So rung 1 -> 2 is the one step where the
%   state grid itself moves; check any roughness change there against a
%   matched-node control before reading it as economics.

if nargin < 2 || isempty(opts), opts = struct(); end
opts = defaults(opts, struct('gamma', 5, 'is_owner', false, ...
                             'dims', [20 14 12], 'gh_n', 5, 'gh_n_reit', [], ...
                             'cg_loss_offset', false, 'phi_floor', []));
if isempty(opts.gh_n_reit), opts.gh_n_reit = opts.gh_n; end

names = {'cgm', 'income', 'housing', 'dc', 'inctax', 'cgt', 'reit'};
if ischar(rung) || isstring(rung)
    idx = find(strcmpi(char(rung), names), 1);
    assert(~isempty(idx), 'ablation_config:rung', ...
        'Unknown rung "%s". Valid: %s.', char(rung), strjoin(names, ', '));
    level = idx - 1;
else
    assert(isnumeric(rung) && isscalar(rung) && rung == round(rung) ...
           && rung >= 0 && rung <= 6, 'ablation_config:rung', ...
        'rung must be an integer 0..6 or one of: %s.', strjoin(names, ', '));
    level = rung;
end

% Cumulative: a feature is on at its own rung and every rung above it.
on = struct('income',  level >= 1, ...
            'housing', level >= 2, ...
            'dc',      level >= 3, ...
            'inctax',  level >= 4, ...
            'cgt',     level >= 5, ...
            'reit',    level >= 6);

p = config.params();

% ---- held fixed across the ladder -------------------------------------------
p.gamma        = opts.gamma;
p.is_owner     = opts.is_owner;
p.choose_tau_S = false;
p.skip_polish  = false;      % the optimiser is not optional; see SESSION_NOTES
p.use_refine   = true;       % without refine pi drifts up to 0.38 on its own
p.polish_algo  = 'active-set';
p.polish_ver   = 2;
p.grid_mode    = 'none';
p.legacy_fill  = false;

% ---- rung 1: income ----------------------------------------------------------
% Off: the CGM (2005) high-school cubic and their 0.68 total replacement, which
% is the whole retirement income when there is no DC pillar.
% On:  the Been-Knoef-Vethaak age table and the AOW-only replacement, which is
% first-pillar only because the DC pillar supplies the rest.
if on.income
    p.income_source = 'table';
    p.replacement   = 0.307;
else
    p.income_source = 'poly';
    p.replacement   = 0.68;
end

% ---- rung 1 also: financial market ------------------------------------------
% CGM's market (r_f 2%, premium 4%, vol 15.7%) vs this model's Dutch
% calibration. mu_S_level is an excess return in both, so only the levels move.
if on.income
    p.r             = 0.011;
    p.mu_S_level    = 0.04;
    p.sigma_S_level = 0.16;
else
    p.r             = 0.02;
    p.mu_S_level    = 0.04;
    p.sigma_S_level = 0.157;
end

% ---- rung 2: housing / rent --------------------------------------------------
% Off: no house and no rent, so H = 0 for life and the (u2, u3) axes collapse.
% h_mult = 0 also frees the lambda cap; see utility.build_state_grids.
if on.housing
    p.h_mult = 4.0;
    p.alpha  = 0.06;
    p.theta  = 0.015;
else
    p.h_mult = 0.0;
    p.alpha  = 0.0;
    p.theta  = 0.0;
    % No lambda_hi override here. utility.build_state_grids already spans the
    % full axis when h_mult = 0, which is what this case needs at BOTH ends:
    % the household enters at lambda = Y/(X+Y) near 1, and returns there in old
    % age as it runs its wealth down. Capping short of 1 puts those households
    % off the grid, where the policy is silently extrapolated from the edge.
end

% ---- rung 3: DC pension ------------------------------------------------------
% Off: kappa = 0, exactly as run_nodc does, so no balance ever accumulates and
% the glide and annuity are inert.
if ~on.dc
    p.kappa = 0;
end

% ---- rung 4: EET income tax --------------------------------------------------
if ~on.inctax
    p.tau_inc = 0.0;
end

% ---- rung 5: box-3 capital-gains tax ----------------------------------------
% The suspect. Asymmetric by construction: full downside, (1 - tau) of the
% upside, which is what flattens the after-tax equity premium.
if ~on.cgt
    p.tau_cg_bond  = 0.0;
    p.tau_cg_stock = 0.0;
end
p.tau_wealth = 0.0;          % off in the production calibration too

% Probe knobs. Neither is part of the ladder: they exist to re-run a rung under
% a counterfactual and see which of its numbers move.
%   cg_loss_offset  make the CGT symmetric (losses rebated), which restores most
%                   of the after-tax equity premium the no-offset rule removes.
%   phi_floor       raise the consumption floor off its 1e-6 default, which is
%                   what creates the value cliff at low liquid wealth.
p.cg_loss_offset = opts.cg_loss_offset;
if ~isempty(opts.phi_floor), p.phi_floor = opts.phi_floor; end

% ---- rung 6: DC REIT leg -----------------------------------------------------
if ~on.reit
    p.tau_REIT = 0.0;
    p.corr_RL  = 0.0;
    p.corr_RS  = 0.0;
    p.corr_RH  = 0.0;
end

% ---- re-derive the cached financial moments ---------------------------------
% params.m caches sigma_S / mu_S / Rf from the level inputs, so changing a level
% after the fact has no effect until they are rebuilt. (The REIT is exempt:
% config.reit_process derives its moments on demand.)
p.Rf      = 1 + p.r;
p.sigma_S = sqrt(log(1 + (p.sigma_S_level / (1 + p.r + p.mu_S_level))^2));
p.mu_S    = log(1 + p.r + p.mu_S_level) - 0.5 * p.sigma_S^2;

% ---- grid --------------------------------------------------------------------
p.gh_n_reit = opts.gh_n_reit;
p = utility.build_state_grids(p, opts.dims, opts.gh_n);

% DC allocation feasibility is asserted in params.m against the production
% shares; re-check it here because tau_REIT may have been zeroed since.
assert(all(config.tau_effective(p) + config.reit_effective(p) <= 1 + 1e-12), ...
    'ablation_config:reit_alloc', 'tau_S + tau_REIT exceeds 1 at some age.');

meta = struct();
meta.level      = level;
meta.name       = names{level + 1};
meta.on         = on;
meta.gamma      = p.gamma;
meta.is_owner   = p.is_owner;
meta.dims       = utility.grid_sizes(p);
meta.gh_n       = p.gh_n;
meta.gh_n_reit  = p.gh_n_reit;
meta.reit_active = config.reit_active(p);
meta.lambda_range = [min(p.u1_grid), max(p.u1_grid)];
meta.cg_loss_offset = p.cg_loss_offset;
meta.phi_floor      = p.phi_floor;
meta.label      = sprintf('%d %s', level, names{level + 1});
if p.cg_loss_offset, meta.label = [meta.label ' +offset']; end
if ~isempty(opts.phi_floor)
    meta.label = sprintf('%s +flr%g', meta.label, p.phi_floor);
end
meta.deviations = {
    'horizon 25-100 and retirement at 67, not CGM 20-100 and 65'
    'permanent income shock only; CGM also has a transitory shock'
    'Dutch unisex mortality, not the CGM life table'
    sprintf('gamma held at %g across the ladder', p.gamma)
    };
end

% =============================================================================
function s = defaults(s, d)
f = fieldnames(d);
for k = 1:numel(f)
    if ~isfield(s, f{k}) || isempty(s.(f{k}))
        s.(f{k}) = d.(f{k});
    end
end
end

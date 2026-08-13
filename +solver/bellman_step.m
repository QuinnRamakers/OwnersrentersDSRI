function [V_t, c_pol, pi_pol, feas, tau_pol] = bellman_step(t, V_next, p, profile, shocks, ann_price, pol_next)
%BELLMAN_STEP  One backward-induction step on (lambda, s_A, s_H).
%
%   State variables:
%       lambda = Y / W
%       s_A    = A / W   (DC pension share)
%       s_H    = H / W   (housing share)
%       s_X    = 1 - lambda - s_A - s_H  (liquid wealth share, derived)
%   Feasibility: lambda + s_A + s_H <= 1.
%
%   Period budget (LW = X-plus-disposable, normalised by W):
%     Working:
%       LW/W = s_X + (1-delta)*(1-kappa)*lambda - h_cost_rate * s_H
%     Retired:
%       LW/W = s_X + (1-delta)*lambda + s_A/ann_price(t) - h_cost_rate * s_H
%
%   h_cost_rate = alpha (renter) or theta + m_rate_t (owner).
%
%   Pension account next-period:
%     Working:  A_next = R_A * (A + kappa*Y)            -> A_next_W = R_A*(s_A + kappa*lam)
%     Retired:  A_next = R_A * (A - A/ann_price(t))     -> A_next_W = R_A*s_A*(1-1/ann_price(t))
%   R_A = ((1 - tau)*Rf + tau*R_S) / p_t   (survival-credit return)
%
%   Bequest base (paid at death; weighted by beta*(1-p_t)*chi):
%     Renter: X_next       (A is annuitised -- not bequeathable)
%     Owner:  X_next + H_next
%
%   Choices:
%     Default (p.choose_tau_S false/absent): (c, pi) -- consumption fraction
%       and liquid equity share; the DC share tau is the fixed tau_S glide
%       path. 41x41 grid search + 2-var fmincon polish.
%     Free DC choice (p.choose_tau_S true): (c, pi, tau), but only while
%       WORKING (t < t_ret). The tau seed grid is linspace(0,1,p.N_tau) with
%       the glide value appended, so the free search always contains the glide
%       slice and cannot lose to it on the grid; the polish then runs from the
%       best grid point and, separately, pinned at the glide value.
%       tau_pol (5th output) is the DC share in force, [] when the option is
%       off. With a single tau slice the tensor collapses to the glide-path
%       grid search bit-identically.
%
%   Retirement (t >= t_ret) is never a tau choice in either regime: the share
%   comes from config.tau_effective(p). That restriction is what keeps the
%   annuity price honest without a fourth state variable, and it means both
%   arms behave identically after t_ret, so the whole free-vs-glide difference
%   is attributable to accumulation. See config.tau_effective.
%
%   The continuation interpolant works on the z-transform of V_next and is
%   built over the whole cube; infeasible nodes are filled from their nearest
%   feasible neighbour (solver.build_fill_map). Every continuation query
%   asserts lambda+sA+sH <= 1. Negative liquid wealth is unreachable in this
%   model, and the assert makes that assumption fail loudly rather than
%   silently if leverage, additive returns, post-return cost deduction or a
%   mortgage stock is ever added.
%
%   pol_next (optional 7th argument) carries the t+1 policies on this grid,
%   struct with fields c / pi / tau ([] allowed), supplied by solve_lifecycle.
%   Under p.polish_ver >= 2 they seed extra fmincon starts -- see below --
%   and the polish objective runs on the certainty-equivalent scale. With
%   polish_ver < 2 (or the field absent) both are off and this function is
%   bit-identical to the original, warm starts ignored.

if nargin < 7, pol_next = []; end

NL = p.N_lambda; NA = p.N_sA; NH = p.N_sH;
V_t    = nan(NL, NA, NH);
c_pol  = nan(NL, NA, NH);
pi_pol = nan(NL, NA, NH);

% choose_tau  : record a tau policy at all (allocates tau_pol, 5th output).
% optimise_tau: treat tau as a choice at this age -- accumulation only. With
%   optimise_tau false the tau grid collapses to one slice and this step is
%   the glide step, bit-identically.
choose_tau = isfield(p, 'choose_tau_S') && p.choose_tau_S;
is_retired_t = (t >= p.t_ret);
optimise_tau = choose_tau && ~is_retired_t;
tau_pol = [];
if choose_tau
    tau_pol = nan(NL, NA, NH);
end

% Solver version, recorded in the fingerprint so files solved under different
% polish versions never rate as welfare-comparable. polish_ver >= 2 turns on
% two things taken from the coauthor's main_jmp.m:
%
%   OBJECTIVE SCALING (their main_jmp.m:403 + the scaling_factor in every
%   obj_*.m). They multiply the objective handed to fmincon by a scalar
%   recomputed each period from the previous period's value function, and
%   divide it back out when storing the result. Same structure here. It
%   matters because at gamma = 5 our raw rhs is O(1e-19) or smaller -- far
%   below fmincon's FunctionTolerance of 1e-10, so the polish declared
%   convergence immediately without moving, while its KKT systems logged
%   hundreds of singular-matrix warnings. Multiplying by a positive scalar is
%   monotone, so every argmax is unchanged; only the optimiser's notion of
%   "small" moves.
%
%   WARM STARTS. The t+1 policy at the same node seeds extra polish starts.
%   Policies are smooth in t, so it is usually a better guess than the grid
%   argmax, and as an ADDITIONAL candidate it can only improve the result.
%
% polish_ver < 2 or absent reproduces the original polish exactly.
polish_ver = 1; if isfield(p, 'polish_ver'), polish_ver = p.polish_ver; end
use_scaling = polish_ver >= 2;
use_warm    = polish_ver >= 2;

[Lam, SA, SH] = ndgrid(p.lambda_grid, p.sA_grid, p.sH_grid);
feas = (Lam + SA + SH) <= 1 + 1e-12;

gamma   = p.gamma;
one_m_g = 1 - gamma;
inv_omg = 1 / one_m_g;

is_owner   = p.is_owner;
is_retired = (t >= p.t_ret);

% Tax parameters (guarded so legacy p-structs without tax fields => no tax).
%   tau_inc : income tax on wages, AOW and annuity payout (EET treatment).
%   tau_b/tau_s : accrual capital-gains tax (no loss offset) on the liquid
%   bond/stock legs. The DC fund return R_A below stays PRE-TAX (sheltered).
%   tau_w : box-3-style wealth tax on the LIQUID account's end-of-period
%   balance (after-CGT return factors scaled by 1-tau_w); housing and the
%   DC fund are exempt.
tau_inc = 0; if isfield(p,'tau_inc'),      tau_inc = p.tau_inc;      end
tau_b   = 0; if isfield(p,'tau_cg_bond'),  tau_b   = p.tau_cg_bond;  end
tau_s   = 0; if isfield(p,'tau_cg_stock'), tau_s   = p.tau_cg_stock; end
tau_w   = 0; if isfield(p,'tau_wealth'),   tau_w   = p.tau_wealth;   end
net_inc = 1 - tau_inc;     % take-home factor on taxed income

% Per-period housing carrying-cost rate (fraction of H_t)
if is_owner
    if t <= numel(p.m_rate_path)
        m_rate_t = p.m_rate_path(t);
    else
        m_rate_t = 0;
    end
    h_cost_rate = p.theta + m_rate_t;
else
    h_cost_rate = p.alpha;
end

% Effective DC contribution rate at this age. p.kappa is a T x 1 franchise-
% based profile (config.params); min() keeps legacy scalar-kappa p-structs
% and the p.kappa = 0 overrides in run_nodc / run_dc_strategies working.
kappa_t = p.kappa(min(t, numel(p.kappa)));

% Bequeathed housing value as a fraction of H: owners' estates sell the
% house and pay p.sell_cost; renters bequeath no housing.
sell_cost = 0; if isfield(p, 'sell_cost'), sell_cost = p.sell_cost; end
h_beq_fac = is_owner * (1 - sell_cost);

% Consumption floor as a share of W. The calibrated floor is a fraction of
% gross income (config.params), and lambda = Y/W, so normalised it is
% phi_floor * lambda -- homothetic, no extra state. Guarded below by
% FLOOR_EPS: lambda = 0 is a grid node but not a reachable state (income is
% strictly positive), and without the guard those nodes would floor at zero
% and carry u = -inf. Absent field => no floor, reproducing the pre-floor
% model exactly.
phi_floor = 0; if isfield(p, 'phi_floor'), phi_floor = p.phi_floor; end
use_floor = phi_floor > 0;
FLOOR_EPS = 1e-12;

% Income contribution factor (take-home wage as fraction of Y)
if is_retired
    contrib_factor = (1 - p.delta) * net_inc;            % AOW, taxed as income
else
    contrib_factor = (1 - p.delta) * (1 - kappa_t) * net_inc;  % deductible contrib; rest taxed
end

% Terminal period: no continuation, consume all liquid wealth (modulo bequest)
if t == p.T
    chi_T = 0; if isfield(p, 'chi'), chi_T = p.chi; end
    for il = 1:NL
        for ia = 1:NA
            for ih = 1:NH
                if ~feas(il, ia, ih), continue; end
                lam = p.lambda_grid(il); sA = p.sA_grid(ia); sH = p.sH_grid(ih);
                sX  = 1 - lam - sA - sH;
                if is_retired
                    LW_W = sX + contrib_factor * lam + net_inc * sA / ann_price(t) ...
                            - h_cost_rate * sH;
                else
                    LW_W = sX + contrib_factor * lam - h_cost_rate * sH;
                end
                if use_floor
                    % Own resources short of the floor: the shortfall is
                    % funded from outside, so LW_W <= 0 is not a sentinel.
                    LW_W = max(LW_W, max(phi_floor * lam, FLOOR_EPS));
                elseif LW_W <= 1e-12
                    V_t(il, ia, ih)    = -1e15;
                    c_pol(il, ia, ih)  = 1e-6;
                    pi_pol(il, ia, ih) = 0;
                    continue
                end
                beq_H = h_beq_fac * sH;
                if chi_T <= 0
                    c_star = 1;
                    V_t(il, ia, ih) = (c_star * LW_W)^one_m_g / one_m_g;
                else
                    c_star = (LW_W + beq_H) / (LW_W * (1 + chi_T^(1/gamma)));
                    c_star = min(max(c_star, 1e-6), 1);
                    beq_part = (1 - c_star) * LW_W + beq_H;
                    V_t(il, ia, ih) = (c_star * LW_W)^one_m_g / one_m_g ...
                                      + chi_T * beq_part^one_m_g / one_m_g;
                end
                c_pol(il, ia, ih)  = c_star;
                pi_pol(il, ia, ih) = 0;
            end
        end
    end
    % No investment decision at T; report tau = 0 on the feasible set.
    if choose_tau
        tau_pol = zeros(size(pi_pol));
        tau_pol(isnan(pi_pol)) = NaN;
    end
    return
end

% --- Non-terminal: build z-space interpolant then optimise per feasible state.
% Effective DC equity share at this age: the accumulation glide before
% retirement, the decumulation strategy (p.tau_decum) after it. Under
% choose_tau_S this is the seed/fallback while working and the FIXED share
% once retired -- see optimise_tau below.
tau_eff_path = config.tau_effective(p);
tau      = tau_eff_path(t);
pt       = profile.p_surv(t);
beta_eff = p.beta * pt;
chi = 0; if isfield(p, 'chi'), chi = p.chi; end
beq_eff = p.beta * (1 - pt) * chi;

R_S    = shocks.joint.R_S(:);
eps_Y  = shocks.joint.eps_Y_unit(:);
R_H    = shocks.joint.R_H(:);
w_join = shocks.joint.w(:);
n_shock = numel(w_join);
mu_g   = profile.mu_growth(t);
sig_l  = profile.sigma_l_log(t);
G_next = exp(mu_g + sig_l .* eps_Y);

% DC equity-share grid. Glide regime: the single fixed tau_S(t) value (the
% grid search below then collapses to the old one-slice tensor exactly).
% Free choice: linspace seed grid with the glide value appended (unique()
% keeps it a single copy when it coincides with a seed point), so the free
% search always weakly dominates the glide slice on the grid.
if optimise_tau
    NT = 11; if isfield(p, 'N_tau'), NT = p.N_tau; end
    tau_grid = unique([linspace(0, 1, NT).'; tau]);
else
    tau_grid = tau;   % glide arm, or ANY retired age: one slice, share fixed
end
NTg     = numel(tau_grid);
j_glide = find(tau_grid == tau, 1);
% Survival-credit DC returns per tau slice (PRE-TAX, sheltered), n_shock x NTg
R_A_all = ((1 - tau_grid.') * p.Rf + R_S * tau_grid.') / pt;

% After-tax returns on the LIQUID (taxable) account: accrual CGT, no loss
% offset, then the box-3 wealth tax on the end-of-period balance. Bonds pay
% tax on the (always positive) interest; stocks pay tax only on positive
% gains. Still strictly positive and linear in X, so the homothetic
% z-transform machinery is unchanged.
Rf_at  = (1 + p.r * (1 - tau_b)) * (1 - tau_w);            % bond leg, after tax
R_S_at = (R_S - tau_s .* max(R_S - 1, 0)) .* (1 - tau_w);  % stock leg, after tax (no loss offset)

% Z-transform on (lambda, s_A, s_H) grid of V_next
V_filled = V_next; V_filled(~feas) = NaN;
arg = one_m_g * V_filled; arg(arg <= 0) = NaN;
z_next = arg .^ inv_omg;
z_finite = z_next(isfinite(z_next));
if isempty(z_finite)
    error('bellman_step:no_finite_z', 'No finite z values at t=%d', t);
end
z_min = min(z_finite);

% Infeasible-node fill. The interpolant lives on the whole cube but only the
% simplex is solved, so every cell touching the sX = 0 face mixes solved
% corners with unsolved ones. Fill the unsolved ones from the nearest feasible
% node to their radial projection onto the face (solver.build_fill_map). The
% map is grid-only, so solve_lifecycle precomputes it on p.fill_map and this
% is a single gather; recompute as a fallback for direct callers.
if isfield(p, 'fill_map') && ~isempty(p.fill_map) && isequal(p.fill_map.dims, [NL NA NH])
    fmap = p.fill_map;
else
    fmap = solver.build_fill_map(p.lambda_grid, p.sA_grid, p.sH_grid);
end
z_next_filled = z_next;
% Test-only escape hatch reproducing the pre-fix global-minimum fill, so the
% monotonicity check in tests/smoke_fill_fix.m can solve both variants on one
% grid. Never set in production configs.
if isfield(p, 'legacy_fill') && p.legacy_fill
    z_next_filled(~feas) = z_min;
else
    z_next_filled(fmap.infeas_lin) = z_next(fmap.src_lin);
end
% Final safety only: feasible nodes whose arg <= 0 (and any infeasible node
% whose source was such a node) are still NaN at this point.
z_next_filled(isnan(z_next_filled)) = z_min;
pp_z = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, ...
                          z_next_filled, 'linear', 'linear');

% Objective scaling factor for this period, from V_next -- the coauthor's
% main_jmp.m:403 pattern (they use 1e6/min(V) with V positive in CE units).
% Their min() does not translate directly: their value function spans a narrow
% positive range, ours spans ~46 orders of magnitude because the ruin tail
% reaches |V| ~ 1e27 while ordinary states sit near 1e-19. Keying off either
% extreme would scale the whole period to the tail. The median magnitude over
% feasible states is the robust equivalent -- it tracks where the states
% actually are, which is what the optimiser's tolerances need to match.
obj_scale = 1;
if use_scaling
    absV = abs(V_filled(isfinite(V_filled) & V_filled ~= 0));
    if ~isempty(absV)
        obj_scale = 1 / median(absV);
        if ~isfinite(obj_scale) || obj_scale <= 0, obj_scale = 1; end
    end
end

% Inner (c, pi) seed grid for the fmincon polish. NC stays fine because the
% objective is multimodal in c; NP can be coarsened because it is concave in
% pi, but production runs keep both at 41 (see config.params).
NC = 41; if isfield(p, 'N_c'),  NC = p.N_c;  end
NP = 41; if isfield(p, 'N_pi'), NP = p.N_pi; end
pi_grid = linspace(0, 1, NP).';
R_X_all = (1 - pi_grid) * Rf_at + pi_grid * R_S_at.';     % NP x n_shock (after-tax)

opts_polish = optimoptions('fmincon', ...
    'Algorithm', 'interior-point', ...
    'Display', 'off', ...
    'OptimalityTolerance', 1e-8, ...
    'StepTolerance', 1e-9, ...
    'FunctionTolerance', 1e-10, ...
    'MaxIterations', 200, ...
    'MaxFunctionEvaluations', 500, ...
    'FiniteDifferenceType', 'central');

feas_lin = find(feas);
n_feas   = numel(feas_lin);
V_flat   = zeros(n_feas, 1);
c_flat   = zeros(n_feas, 1);
pi_flat  = zeros(n_feas, 1);
tau_flat = zeros(n_feas, 1);

lam_pts = Lam(feas);
sA_pts  = SA(feas);
sH_pts  = SH(feas);

% Warm starts: the t+1 policy at the SAME node, sliced to the feasible set so
% the parfor indexes it exactly like lam_pts. Sliced (not broadcast) variables
% keep the parfor communication cost flat. NaN entries (infeasible or
% unsolved) are screened per state below.
have_warm = use_warm && ~isempty(pol_next) && isstruct(pol_next) ...
            && isfield(pol_next, 'c') && isequal(size(pol_next.c), [NL NA NH]);
if have_warm
    cw_pts = pol_next.c(feas);
    pw_pts = pol_next.pi(feas);
    if isfield(pol_next, 'tau') && isequal(size(pol_next.tau), [NL NA NH])
        tw_pts = pol_next.tau(feas);
    else
        tw_pts = nan(n_feas, 1);
    end
else
    cw_pts = nan(n_feas, 1);
    pw_pts = nan(n_feas, 1);
    tw_pts = nan(n_feas, 1);
end

% Annuity payout factor for retired branch (constants outside parfor)
if is_retired
    ann_t      = ann_price(t);
    A_keep_fac = 1 - 1/ann_t;             % A_next_pre / s_A
else
    ann_t      = 1;                        % unused on working branch
    A_keep_fac = 1;
end

parfor k = 1:n_feas
    lam = lam_pts(k); sA = sA_pts(k); sH = sH_pts(k);
    sX  = 1 - lam - sA - sH;
    c_warm = cw_pts(k); pi_warm = pw_pts(k); tau_warm = tw_pts(k);

    if is_retired
        LW_W              = sX + contrib_factor * lam + net_inc * sA / ann_t ...
                                - h_cost_rate * sH;
        A_next_pre_return = sA * A_keep_fac;
    else
        LW_W              = sX + contrib_factor * lam - h_cost_rate * sH;
        A_next_pre_return = sA + kappa_t * lam;
    end

    H_next_W = sH * R_H;                     % n_shock x 1
    Y_next_W = G_next * lam;                 % n_shock x 1
    F_W      = max(phi_floor * lam, FLOOR_EPS);   % consumption floor, share of W

    if ~use_floor
        % No floor: the legacy sentinel, kept so phi_floor = 0 reproduces the
        % pre-floor model exactly for reruns of old calibrations.
        if LW_W <= 1e-9
            V_flat(k) = -1e15; c_flat(k) = 1e-6; pi_flat(k) = 0; tau_flat(k) = tau;
            continue
        end
    elseif LW_W <= F_W
        % The floor absorbs everything the household has: it consumes exactly
        % the floor, saves nothing, and enters next period with X = 0. The
        % continuation still carries the DC balance, housing and income, so
        % this is an ordinary value that varies across states -- not the flat
        % sentinel it replaces, which gave the whole region no gradient.
        % Only tau is still worth choosing here.
        u_f = F_W ^ one_m_g / one_m_g;
        best = -inf; j_best = 1;
        for j = 1:NTg
            A_next_W_j = R_A_all(:, j) * A_next_pre_return;
            W_g   = A_next_W_j + H_next_W + Y_next_W;
            lam_n = max(min(Y_next_W ./ W_g, 1), 0);
            sA_n  = max(min(A_next_W_j ./ W_g, 1), 0);
            sH_n  = max(min(H_next_W ./ W_g, 1), 0);
            z_n   = pp_z(lam_n, sA_n, sH_n);
            val   = u_f + beta_eff * sum(w_join .* ((W_g .* z_n) .^ one_m_g / one_m_g));
            if beq_eff > 0
                beq_base = max(h_beq_fac * H_next_W, FLOOR_EPS);
                val = val + beq_eff * sum(w_join .* (beq_base .^ one_m_g / one_m_g));
            end
            if val > best, best = val; j_best = j; end
        end
        V_flat(k) = best; c_flat(k) = 1; pi_flat(k) = 0; tau_flat(k) = tau_grid(j_best);
        continue
    end

    % Scale-aware c lower bound. The floor is NOT imposed here: it is a
    % guarantee, not a consumption mandate. A household whose own resources
    % already exceed the floor is free to consume below it and save the rest,
    % and only the branch above -- where own resources fall short -- pays the
    % floor. Forcing c >= F_W/LW_W here instead would make a high floor a
    % welfare LOSS rather than a transfer.
    c_floor = max(1e-3, 0.01 / LW_W);
    c_floor = min(c_floor, 0.5);
    c_grid  = linspace(c_floor, 1 - 1e-6, NC).';
    u_now   = (c_grid * LW_W) .^ one_m_g / one_m_g;

    % Batched grid search: one griddedInterpolant call per tau slice over
    % the full (shock x c x pi) tensor rather than NC*NP separate calls,
    % using the factorisation X_{t+1}/W = R_X(pi) * [(1-c)*LW_W]. X_next is
    % tau-independent and hoisted out of the slice loop. NTg = 1 (glide
    % regime) reproduces the pre-choose_tau_S single-tensor search exactly.
    sav    = (1 - c_grid).' * LW_W;                   % 1 x NC (saved liquid wealth)
    RX     = reshape(R_X_all.', n_shock, 1, NP);      % n_shock x 1 x NP
    X_next = RX .* sav;                               % n_shock x NC x NP

    maxval = -inf; ic_max = 1; ip_max = 1; it_max = 1;
    maxval_g = -inf; ic_g = 1; ip_g = 1;
    rhs_g = [];
    for j = 1:NTg
        A_next_W_j = R_A_all(:, j) * A_next_pre_return;   % n_shock x 1
        base_W = A_next_W_j + H_next_W + Y_next_W;         % n_shock x 1
        W_g    = X_next + base_W;                          % n_shock x NC x NP
        lam_n  = max(min(Y_next_W ./ W_g, 1), 0);
        sA_n   = max(min(A_next_W_j ./ W_g, 1), 0);
        sH_n   = max(min(H_next_W ./ W_g, 1), 0);
        assert(max(lam_n + sA_n + sH_n, [], 'all') <= 1 + 1e-9, ...
               'bellman_step:infeasible_query', ...
               ['Continuation query left the simplex (lambda+sA+sH > 1), i.e. ' ...
                'negative liquid wealth has become reachable. The infeasible-node ' ...
                'fill (solver.build_fill_map) assumes those nodes are never queried ' ...
                'and needs an explicit treatment before this model variant is used.']);
        z_n    = reshape(pp_z(lam_n(:), sA_n(:), sH_n(:)), n_shock, NC, NP);
        CE     = W_g .* z_n;
        V_n    = CE .^ one_m_g / one_m_g;
        EV     = reshape(sum(w_join .* V_n, 1), NC, NP);   % NC x NP
        rhs    = u_now + beta_eff * EV;                     % u_now (NC x 1) broadcasts
        if beq_eff > 0
            beq_base = X_next + h_beq_fac * H_next_W;
            beq_n = beq_base .^ one_m_g / one_m_g;
            rhs   = rhs + beq_eff * reshape(sum(w_join .* beq_n, 1), NC, NP);
        end

        [mv, lin_idx] = max(rhs(:));
        if mv > maxval
            maxval = mv;
            [ic_max, ip_max] = ind2sub([NC, NP], lin_idx);
            it_max = j;
        end
        if j == j_glide
            maxval_g = mv;
            [ic_g, ip_g] = ind2sub([NC, NP], lin_idx);
            if optimise_tau
                rhs_g = rhs;   % kept for multi-basin polish starts below
            end
        end
    end

    if optimise_tau
        % Free-tau polish: best of three candidates (each may fail; the grid
        % max is the fallback).
        %   A) 3-var (c, pi, tau) fmincon from the global grid best. The
        %      interior-point barrier keeps tau strictly inside (0,1), so when
        %      the optimum sits on a tau bound this candidate alone
        %      under-performs -- hence the pinned candidates.
        %   B) 2-var (c, pi) fmincon, tau pinned at the best grid tau.
        %   C) 2-var (c, pi) fmincon, tau pinned at the glide value, from the
        %      glide slice's best grid point. This replicates the glide
        %      regime's own polish, so the free value can never fall below the
        %      glide value for the same continuation. Skipped when it would
        %      duplicate B.
        % obj_scale multiplies the objective and is divided back out of the
        % result, so the reported value is on the model's own scale.
        obj3 = @(x) -obj_scale * bellman_rhs_z3(x(1), x(2), x(3), LW_W, Rf_at, R_S_at, ...
                                     p.Rf, R_S, pt, A_next_pre_return, ...
                                     H_next_W, Y_next_W, ...
                                     w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
        V_polish = -inf; x_opt = [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)];
        try
            [x_try, neg_V_try, exitflag] = fmincon(obj3, ...
                [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)], ...
                [], [], [], [], [c_floor; 0; 0], [1 - 1e-6; 1; 1], [], opts_polish);
            if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_polish
                V_polish = -neg_V_try/obj_scale;
                x_opt    = x_try;
            end
        catch
        end

        pin_tau    = tau_grid(it_max);
        pin_starts = [c_grid(ic_max), pi_grid(ip_max), pin_tau];
        if it_max ~= j_glide && isfinite(maxval_g)
            pin_starts = [pin_starts; c_grid(ic_g), pi_grid(ip_g), tau];
        end
        % t+1 policy at this node: an extra start, at its own tau and at the
        % glide tau. Only a candidate, so it cannot make the answer worse.
        if isfinite(c_warm) && isfinite(pi_warm)
            cw = min(max(c_warm, c_floor), 1 - 1e-6);
            pw = min(max(pi_warm, 0), 1);
            pin_starts = [pin_starts; cw, pw, tau];
            if isfinite(tau_warm)
                pin_starts = [pin_starts; cw, pw, min(max(tau_warm, 0), 1)];
            end
        end
        % Track the best glide-pinned candidate so the derivative-free
        % refinement below can start from it.
        v_gl = maxval_g; c_gl = c_grid(ic_g); p_gl = pi_grid(ip_g);
        % The rhs surface is multimodal in c, and the basin a single argmax
        % start reaches shifts with small continuation changes -- and the
        % glide solve's continuation differs from ours. So anchor against
        % every basin the glide step could land in: pin tau at the glide value
        % and also start from the top interior local maxima of the glide
        % slice's surface (4-neighbour test, up to 2 beyond the argmax).
        if ~isempty(rhs_g)
            is_lmax = true(NC, NP);
            is_lmax(2:NC,   :) = is_lmax(2:NC,   :) & (rhs_g(2:NC,:)   >= rhs_g(1:NC-1,:));
            is_lmax(1:NC-1, :) = is_lmax(1:NC-1, :) & (rhs_g(1:NC-1,:) >= rhs_g(2:NC,:));
            is_lmax(:, 2:NP  ) = is_lmax(:, 2:NP  ) & (rhs_g(:,2:NP)   >= rhs_g(:,1:NP-1));
            is_lmax(:, 1:NP-1) = is_lmax(:, 1:NP-1) & (rhs_g(:,1:NP-1) >= rhs_g(:,2:NP));
            is_lmax(ic_g, ip_g) = false;   % argmax already a start
            lm_idx = find(is_lmax);
            if ~isempty(lm_idx)
                [~, ord] = sort(rhs_g(lm_idx), 'descend');
                lm_idx = lm_idx(ord(1:min(2, numel(ord))));
                [lm_c, lm_p] = ind2sub([NC, NP], lm_idx);
                pin_starts = [pin_starts; ...
                              c_grid(lm_c(:)), pi_grid(lm_p(:)), repmat(tau, numel(lm_idx), 1)];
            end
        end
        for s = 1:size(pin_starts, 1)
            tau_fix = pin_starts(s, 3);
            obj2 = @(x) -obj_scale * bellman_rhs_z3(x(1), x(2), tau_fix, LW_W, Rf_at, R_S_at, ...
                                         p.Rf, R_S, pt, A_next_pre_return, ...
                                         H_next_W, Y_next_W, ...
                                         w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
            try
                [x_try, neg_V_try, exitflag] = fmincon(obj2, pin_starts(s, 1:2).', ...
                    [], [], [], [], [c_floor; 0], [1 - 1e-6; 1], [], opts_polish);
                if exitflag > 0 || exitflag == 0
                    V_try = -neg_V_try/obj_scale;
                    if V_try > V_polish
                        V_polish = V_try;
                        x_opt    = [x_try; tau_fix];
                    end
                    if tau_fix == tau && V_try > v_gl
                        v_gl = V_try; c_gl = x_try(1); p_gl = x_try(2);
                    end
                end
            catch
            end
        end

        % Derivative-free local refinement. The coarse-grid z-interpolant puts
        % narrow kink ridges in the rhs surface, and fmincon's finite
        % differences step straight over them (it can even walk off one when
        % started on it). A shrinking-radius grid scan is ridge-proof. Refine
        % (a) pinned at the glide tau from the best glide-pinned candidate --
        % the dominance anchor -- and (b) pinned at the current best tau.
        dc0 = c_grid(2) - c_grid(1);
        dp0 = pi_grid(min(2, NP)) - pi_grid(1);
        if isfinite(v_gl)
            [c_r, p_r, v_r] = refine_cpi(c_gl, p_gl, tau, v_gl, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0);
            if v_r > V_polish
                V_polish = v_r; x_opt = [c_r; p_r; tau];
            end
        end
        if V_polish > maxval
            cb0 = x_opt(1); pb0 = x_opt(2); tb0 = x_opt(3); vb0 = V_polish;
        else
            cb0 = c_grid(ic_max); pb0 = pi_grid(ip_max); tb0 = tau_grid(it_max); vb0 = maxval;
        end
        [c_r, p_r, v_r] = refine_cpi(cb0, pb0, tb0, vb0, LW_W, Rf_at, R_S_at, ...
            p.Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
            w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0);
        if v_r > V_polish
            V_polish = v_r; x_opt = [c_r; p_r; tb0];
        end

        if V_polish > maxval
            V_flat(k) = V_polish; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2); tau_flat(k) = x_opt(3);
        else
            V_flat(k) = maxval; c_flat(k) = c_grid(ic_max); pi_flat(k) = pi_grid(ip_max); tau_flat(k) = tau_grid(it_max);
        end
    else
        A_next_W = R_A_all(:, 1) * A_next_pre_return;   % glide-slice DC position
        lb = [c_floor; 0];
        ub = [1 - 1e-6; 1];
        polish_obj = @(x) -obj_scale * bellman_rhs_z(x(1), x(2), LW_W, Rf_at, R_S_at, ...
                                          A_next_W, H_next_W, Y_next_W, ...
                                          w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);

        % Grid argmax, plus the t+1 policy at this node when it is available.
        starts = [c_grid(ic_max), pi_grid(ip_max)];
        if isfinite(c_warm) && isfinite(pi_warm)
            starts = [starts; min(max(c_warm, c_floor), 1 - 1e-6), min(max(pi_warm, 0), 1)];
        end

        V_polish = -inf; x_opt = starts(1, :).';
        for s = 1:size(starts, 1)
            try
                [x_try, neg_V_try, exitflag] = fmincon(polish_obj, starts(s, :).', ...
                    [], [], [], [], lb, ub, [], opts_polish);
                if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_polish
                    V_polish = -neg_V_try/obj_scale;
                    x_opt    = x_try;
                end
            catch
            end
        end

        % Derivative-free refinement, as in the free-tau branch. Only the free
        % branch had it, because there the polish was known to walk off the
        % z-interpolant's kink ridges. The glide branch needs it for the same
        % reason -- it was simply invisible while the unscaled objective sat
        % below fmincon's FunctionTolerance and the polish never moved. With
        % scaling the polish does move, so the ridges matter here too.
        if use_scaling
            dc0 = c_grid(2) - c_grid(1);
            dp0 = pi_grid(min(2, NP)) - pi_grid(1);
            if V_polish > maxval
                cb0 = x_opt(1); pb0 = x_opt(2); vb0 = V_polish;
            else
                cb0 = c_grid(ic_max); pb0 = pi_grid(ip_max); vb0 = maxval;
            end
            [c_r, p_r, v_r] = refine_cpi(cb0, pb0, tau, vb0, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0);
            if v_r > V_polish
                V_polish = v_r; x_opt = [c_r; p_r];
            end
        end

        if V_polish > maxval
            V_flat(k) = V_polish; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2);
        else
            V_flat(k) = maxval; c_flat(k) = c_grid(ic_max); pi_flat(k) = pi_grid(ip_max);
        end
        tau_flat(k) = tau;
    end
end

V_t(feas_lin)    = V_flat;
c_pol(feas_lin)  = c_flat;
pi_pol(feas_lin) = pi_flat;
if choose_tau
    tau_pol(feas_lin) = tau_flat;
end
end

function rhs_val = bellman_rhs_z(c, pi_eq, LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                                  w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac)
    % R_S_at/Rf_at are after-tax returns, precomputed once by the caller.
    R_X      = (1 - pi_eq) * Rf_at + pi_eq .* R_S_at;
    X_next_W = R_X * (1 - c) * LW_W;
    W_growth = X_next_W + A_next_W + H_next_W + Y_next_W;
    lam_next = max(min(Y_next_W ./ W_growth, 1), 0);
    sA_next  = max(min(A_next_W ./ W_growth, 1), 0);
    sH_next  = max(min(H_next_W ./ W_growth, 1), 0);
    assert(max(lam_next + sA_next + sH_next) <= 1 + 1e-9, ...
           'bellman_step:infeasible_query', ...
           ['Continuation query left the simplex (lambda+sA+sH > 1), i.e. ' ...
            'negative liquid wealth has become reachable. The infeasible-node ' ...
            'fill (solver.build_fill_map) assumes those nodes are never queried ' ...
            'and needs an explicit treatment before this model variant is used.']);
    z_n      = pp_z(lam_next, sA_next, sH_next);
    CE_n     = W_growth .* z_n;
    V_n      = CE_n .^ one_m_g / one_m_g;
    EV       = sum(w .* V_n);
    u_now    = (c * LW_W) ^ one_m_g / one_m_g;
    rhs_val  = u_now + beta_eff * EV;
    if beq_eff > 0
        beq_base = X_next_W + h_beq_fac * H_next_W;
        beq_n   = beq_base .^ one_m_g / one_m_g;
        E_beq   = sum(w .* beq_n);
        rhs_val = rhs_val + beq_eff * E_beq;
    end
end

function [c_b, p_b, v_b] = refine_cpi(c0, p0, tau_fix, v0, LW_W, Rf_at, R_S_at, Rf, R_S, pt, ...
                                       A_next_pre_return, H_next_W, Y_next_W, ...
                                       w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, ...
                                       c_floor, dc0, dp0)
    % Shrinking-radius local grid scan of the (c, pi) rhs surface with tau
    % pinned at tau_fix. Derivative-free, so it resolves the narrow
    % interpolation-kink ridges that defeat fmincon's finite differences.
    % The surface is spiky in c but well-behaved in pi, so round 1 pairs a
    % fine c window (one seed-grid cell, spacing dc0/8) with the FULL pi
    % range; rounds 2-4 then zoom locally, resolving to ~dc0/256.
    R_A      = ((1 - tau_fix) * Rf + tau_fix .* R_S) / pt;
    A_next_W = R_A * A_next_pre_return;               % n_shock x 1
    base_W   = A_next_W + H_next_W + Y_next_W;        % n_shock x 1
    n_shock  = numel(w);
    c_b = c0; p_b = p0; v_b = v0;
    dc = dc0 / 4; dp = max(dp0, 0.05);
    for r = 1:4
        if r == 1
            c_loc = unique(min(max(c0 + dc0 * (-1 : 0.125 : 1), c_floor), 1 - 1e-6));
            p_loc = unique([linspace(0, 1, 21), p0]);
        else
            c_loc = unique(min(max(c_b + dc * (-1 : 0.25 : 1), c_floor), 1 - 1e-6));
            p_loc = unique(min(max(p_b + dp * (-1 : 0.25 : 1), 0), 1));
            dc = dc / 4; dp = dp / 4;
        end
        [Cm, Pm] = ndgrid(c_loc, p_loc);
        M   = numel(Cm);
        cv  = Cm(:).'; pv = Pm(:).';                  % 1 x M
        R_X    = (1 - pv) .* Rf_at + pv .* R_S_at;    % n_shock x M
        X_next = R_X .* ((1 - cv) * LW_W);            % n_shock x M
        W_g    = X_next + base_W;
        lam_n  = max(min(Y_next_W ./ W_g, 1), 0);
        sA_n   = max(min(A_next_W ./ W_g, 1), 0);
        sH_n   = max(min(H_next_W ./ W_g, 1), 0);
        assert(max(lam_n + sA_n + sH_n, [], 'all') <= 1 + 1e-9, ...
               'bellman_step:infeasible_query', ...
               ['Continuation query left the simplex (lambda+sA+sH > 1), i.e. ' ...
                'negative liquid wealth has become reachable. The infeasible-node ' ...
                'fill (solver.build_fill_map) assumes those nodes are never queried ' ...
                'and needs an explicit treatment before this model variant is used.']);
        z_n    = reshape(pp_z(lam_n(:), sA_n(:), sH_n(:)), n_shock, M);
        V_n    = (W_g .* z_n) .^ one_m_g / one_m_g;
        rhs    = (cv.' * LW_W) .^ one_m_g / one_m_g + beta_eff * (w.' * V_n).';
        if beq_eff > 0
            beq_base = X_next + h_beq_fac * H_next_W;
            rhs = rhs + beq_eff * (w.' * (beq_base .^ one_m_g / one_m_g)).';
        end
        [mv, im] = max(rhs);
        if mv > v_b
            v_b = mv; c_b = Cm(im); p_b = Pm(im);
        end
    end
end

function rhs_val = bellman_rhs_z3(c, pi_eq, tau_dc, LW_W, Rf_at, R_S_at, Rf, R_S, pt, ...
                                   A_next_pre_return, H_next_W, Y_next_W, ...
                                   w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac)
    % 3-choice Bellman RHS for the free-DC-share regime: same as
    % bellman_rhs_z but the DC position A_next_W is rebuilt from the choice
    % variable tau_dc (survival-credit return, PRE-TAX -- the fund is
    % sheltered; only the liquid legs Rf_at/R_S_at carry CGT + wealth tax).
    R_A      = ((1 - tau_dc) * Rf + tau_dc .* R_S) / pt;
    A_next_W = R_A * A_next_pre_return;
    R_X      = (1 - pi_eq) * Rf_at + pi_eq .* R_S_at;
    X_next_W = R_X * (1 - c) * LW_W;
    W_growth = X_next_W + A_next_W + H_next_W + Y_next_W;
    lam_next = max(min(Y_next_W ./ W_growth, 1), 0);
    sA_next  = max(min(A_next_W ./ W_growth, 1), 0);
    sH_next  = max(min(H_next_W ./ W_growth, 1), 0);
    assert(max(lam_next + sA_next + sH_next) <= 1 + 1e-9, ...
           'bellman_step:infeasible_query', ...
           ['Continuation query left the simplex (lambda+sA+sH > 1), i.e. ' ...
            'negative liquid wealth has become reachable. The infeasible-node ' ...
            'fill (solver.build_fill_map) assumes those nodes are never queried ' ...
            'and needs an explicit treatment before this model variant is used.']);
    z_n      = pp_z(lam_next, sA_next, sH_next);
    CE_n     = W_growth .* z_n;
    V_n      = CE_n .^ one_m_g / one_m_g;
    EV       = sum(w .* V_n);
    u_now    = (c * LW_W) ^ one_m_g / one_m_g;
    rhs_val  = u_now + beta_eff * EV;
    if beq_eff > 0
        beq_base = X_next_W + h_beq_fac * H_next_W;
        beq_n   = beq_base .^ one_m_g / one_m_g;
        E_beq   = sum(w .* beq_n);
        rhs_val = rhs_val + beq_eff * E_beq;
    end
end

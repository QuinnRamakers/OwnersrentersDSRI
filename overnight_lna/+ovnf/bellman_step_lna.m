function [V_t, c_pol, pi_pol, tau_pol] = bellman_step_lna(t, V_next, p, profile, shocks, ann_price)
%BELLMAN_STEP_LNA  One backward-induction step on (u1, u2, u3) = (lambda, n-tilde, a).
%
%   FREE-TAU PORT (ovnf). Adds the p.choose_tau_S option: while WORKING, the DC
%   equity share is a per-state choice searched on a grid of p.N_tau points
%   (plus the glide value, so the free search can never lose to the glide on
%   the grid). From t_ret on the share is fixed at config.tau_effective,
%   exactly as in solver.bellman_step -- that is what keeps
%   pension.annuity_price honest without a fourth state variable.
%
%   Search is GRID ONLY over (c, pi, tau); no fmincon polish on the tau axis.
%   That matches how these LNA runs already operate (skip_polish = true) and
%   keeps the extension to a third choice a pure tensor sweep.
%
%   NOT VALIDATED against solver.bellman_step's free-tau branch. With
%   choose_tau_S off it collapses to the single glide slice and reproduces
%   solver.bellman_step_lna.
%
%   This port predates free tau on the maintained cube solver, which has since
%   gained it WITH the polish (see solver.bellman_step_lna). What ovnf still
%   has and the maintained path does not is the simulator half:
%   ovnf.paths_lna reads sol.tau_pol, simulate.paths_lna does not.
%
%   Reparametrization of the (lambda, s_A, s_H) simplex onto the full cube
%   [0,1]^3 (paper Sec. 3 "Redefining variables", plus a renormalization of
%   the illiquid block):
%       u1 = lambda = Y / W
%       u2 = (A + H) / (W - Y)      illiquid share of non-income wealth
%       u3 = A / (A + H)            pension share of the illiquid block
%   Inverse map:
%       lambda = u1
%       s_A    = u2 * (1 - u1) * u3
%       s_H    = u2 * (1 - u1) * (1 - u3)
%       s_X    = (1 - u1) * (1 - u2)
%   Every u in [0,1]^3 maps to a feasible simplex point (lambda+s_A+s_H <= 1
%   holds by construction), so there is NO feasibility mask and
%   griddedInterpolant works directly on the rectangular u-grid.
%
%   Degenerate lines: at u2 = 0 the state is independent of u3 (s_A=s_H=0),
%   and at u1 = 1 it is independent of (u2,u3). The per-state solve then
%   produces identical values along those directions automatically, so the
%   interpolant stays consistent. Next-period coordinates guard the
%   corresponding 0/0 divisions with max(., 1e-12) and clamp to [0,1].
%
%   Grids: p.u1_grid, p.u2_grid, p.u3_grid (column vectors on [0,1]).
%   Set p.skip_polish = true to skip the fmincon polish (grid-search only,
%   ~5-10x faster; policies then accurate to the N_c x N_pi inner grid
%   spacing, ~0.025 at 41x41).
%
%   Model logic -- budget, EET income tax, accrual CGT on the liquid legs,
%   survival-credit DC return, bequest, z-transform, batched (c,pi) grid
%   search -- is IDENTICAL to solver.bellman_step; only the state
%   coordinates change.

N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid);
V_t    = nan(N1, N2, N3);
c_pol  = nan(N1, N2, N3);
pi_pol = nan(N1, N2, N3);

[U1, U2, U3] = ndgrid(p.u1_grid, p.u2_grid, p.u3_grid);
Lam_all = U1;
SA_all  = U2 .* (1 - U1) .* U3;
SH_all  = U2 .* (1 - U1) .* (1 - U3);

gamma   = p.gamma;
one_m_g = 1 - gamma;
inv_omg = 1 / one_m_g;

is_owner   = p.is_owner;
is_retired = (t >= p.t_ret);

% Free DC investment choice: searched on the tau grid while working, fixed at
% config.tau_effective once retired. This is the feature the port exists for.
choose_tau   = isfield(p,'choose_tau_S') && p.choose_tau_S;
optimise_tau = choose_tau && (t < p.t_ret);   % accumulation only
tau_pol = [];
if choose_tau, tau_pol = nan(N1, N2, N3); end

skip_polish = false; if isfield(p, 'skip_polish'), skip_polish = logical(p.skip_polish); end

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

% Effective DC contribution rate at this age (franchise-based T x 1 profile;
% min() keeps legacy scalar-kappa p-structs working). See config.params.
kappa_t = p.kappa(min(t, numel(p.kappa)));

% Bequeathed housing value as a fraction of H: owners' estates sell the house
% and pay p.sell_cost; renters bequeath no housing.
sell_cost = 0; if isfield(p, 'sell_cost'), sell_cost = p.sell_cost; end
h_beq_fac = is_owner * (1 - sell_cost);

% Consumption floor as a share of W: phi_floor * lambda (config.params).
% FLOOR_EPS guards the lambda = 0 grid nodes, which are not reachable states.
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
    for k = 1:numel(Lam_all)
        lam = Lam_all(k); sA = SA_all(k); sH = SH_all(k);
        sX  = 1 - lam - sA - sH;
        if is_retired
            LW_W = sX + contrib_factor * lam + net_inc * sA / ann_price(t) ...
                    - h_cost_rate * sH;
        else
            LW_W = sX + contrib_factor * lam - h_cost_rate * sH;
        end
        if use_floor
            LW_W = max(LW_W, max(phi_floor * lam, FLOOR_EPS));
        elseif LW_W <= 1e-12
            V_t(k)    = -1e15;
            c_pol(k)  = 1e-6;
            pi_pol(k) = 0;
            continue
        end
        beq_H = h_beq_fac * sH;
        if chi_T <= 0
            c_star = 1;
            V_t(k) = (c_star * LW_W)^one_m_g / one_m_g;
        else
            c_star = (LW_W + beq_H) / (LW_W * (1 + chi_T^(1/gamma)));
            c_star = min(max(c_star, 1e-6), 1);
            beq_part = (1 - c_star) * LW_W + beq_H;
            V_t(k) = (c_star * LW_W)^one_m_g / one_m_g ...
                     + chi_T * beq_part^one_m_g / one_m_g;
        end
        c_pol(k)  = c_star;
        pi_pol(k) = 0;
    end
    if choose_tau, tau_pol(:) = 0; end
    return
end

% --- Non-terminal: build z-space interpolant then optimise per state.
tau      = p.tau_S(t);
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
R_A    = ((1 - tau) * p.Rf + tau * R_S) / pt;     % survival-credit DC return (PRE-TAX, sheltered)

% DC equity-share grid. Glide regime (or any retired age): the single fixed
% tau_S(t) slice, so the tensor sweep below collapses to the original one.
% Free regime: linspace seed grid with the glide value appended, so the free
% search always contains the glide slice and cannot lose to it on the grid.
if optimise_tau
    NT = 11; if isfield(p,'N_tau'), NT = p.N_tau; end
    tau_grid = unique([linspace(0,1,NT).'; tau]);
else
    tau_grid = tau;
end
NTg     = numel(tau_grid);
R_A_all = ((1 - tau_grid.') * p.Rf + R_S * tau_grid.') / pt;   % n_shock x NTg

% After-tax returns on the LIQUID (taxable) account: accrual CGT, no loss
% offset, then the box-3 wealth tax on the end-of-period balance. Bonds pay
% tax on the (always positive) interest; stocks pay tax only on positive
% gains.
Rf_at  = (1 + p.r * (1 - tau_b)) * (1 - tau_w);            % bond leg, after tax
R_S_at = (R_S - tau_s .* max(R_S - 1, 0)) .* (1 - tau_w);  % stock leg, after tax (no loss offset)

% Z-transform of V_next on the u-grid. No feasibility mask, but keep the
% arg<=0 guard (cash-infeasible states carry V = -1e15, which for gamma < 1
% would make arg negative) and fill any NaN with z_min as before.
arg = one_m_g * V_next; arg(arg <= 0) = NaN;
z_next = arg .^ inv_omg;
z_finite = z_next(isfinite(z_next));
if isempty(z_finite)
    error('bellman_step_lna:no_finite_z', 'No finite z values at t=%d', t);
end
z_min = min(z_finite);
z_next(isnan(z_next)) = z_min;
pp_z = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                          z_next, 'linear', 'linear');

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

n_states = numel(Lam_all);
V_flat   = zeros(n_states, 1);
c_flat   = zeros(n_states, 1);
pi_flat  = zeros(n_states, 1);
tau_flat = zeros(n_states, 1);

lam_pts = Lam_all(:);
sA_pts  = SA_all(:);
sH_pts  = SH_all(:);

% Annuity payout factor for retired branch (constants outside parfor)
if is_retired
    ann_t      = ann_price(t);
    A_keep_fac = 1 - 1/ann_t;             % A_next_pre / s_A
else
    ann_t      = 1;                        % unused on working branch
    A_keep_fac = 1;
end

parfor k = 1:n_states
    lam = lam_pts(k); sA = sA_pts(k); sH = sH_pts(k);
    sX  = 1 - lam - sA - sH;

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
        if LW_W <= 1e-9
            V_flat(k) = -1e15; c_flat(k) = 1e-6; pi_flat(k) = 0;
            continue
        end
    elseif LW_W <= F_W
        % Floor absorbs everything: consume the floor, save nothing, enter
        % next period with X = 0. See solver.bellman_step for the rationale.
        u_f = F_W ^ one_m_g / one_m_g;
        best = -inf; jt_best = 1;
        for jt = 1:NTg
            A_n    = R_A_all(:, jt) * A_next_pre_return;
            denAH0 = A_n + H_next_W;
            W_g0   = denAH0 + Y_next_W;
            u1_0   = max(min(Y_next_W ./ W_g0, 1), 0);
            u2_0   = max(min(denAH0 ./ max(denAH0, 1e-12), 1), 0);
            u3_0   = max(min(A_n ./ max(denAH0, 1e-12), 1), 0);
            z_0    = pp_z(u1_0, u2_0, u3_0);
            val    = u_f + beta_eff * sum(w_join .* ((W_g0 .* z_0) .^ one_m_g / one_m_g));
            if beq_eff > 0
                beq_base = max(h_beq_fac * H_next_W, FLOOR_EPS);
                val = val + beq_eff * sum(w_join .* (beq_base .^ one_m_g / one_m_g));
            end
            if val > best, best = val; jt_best = jt; end
        end
        V_flat(k) = best; c_flat(k) = 1; pi_flat(k) = 0;
        if optimise_tau, tau_flat(k) = tau_grid(jt_best); end
        continue
    end

    % Scale-aware c lower bound. The floor is a guarantee, not a mandate, so
    % it is not imposed here -- see solver.bellman_step.
    c_floor = max(1e-3, 0.01 / LW_W);
    c_floor = min(c_floor, 0.5);
    c_grid  = linspace(c_floor, 1 - 1e-6, NC).';
    u_now   = (c_grid * LW_W) .^ one_m_g / one_m_g;

    % Sweep the tau slices; only A_next_W depends on tau, everything else is
    % rebuilt per slice because the next-period u2/u3 coordinates move with it.
    best_v = -inf; best_ic = 1; best_ip = 1; best_it = 1;
    for jt = 1:NTg
    A_next_W = R_A_all(:, jt) * A_next_pre_return;   % n_shock x 1

    % Batched grid search over the (shock x c x pi) tensor, as in
    % bellman_step; only the next-period state coordinates differ:
    %   u1 = Y/W_g,  u2 = (A+H)/(W_g - Y) = (A+H)/(X+A+H),  u3 = A/(A+H)
    % each clamped to [0,1] (guards the degenerate lines u2=0 and u1=1).
    denAH  = A_next_W + H_next_W;                     % n_shock x 1
    u3_col = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
    base_W = denAH + Y_next_W;                        % n_shock x 1
    sav    = (1 - c_grid).' * LW_W;                   % 1 x NC (saved liquid wealth)
    RX     = reshape(R_X_all.', n_shock, 1, NP);      % n_shock x 1 x NP
    X_next = RX .* sav;                               % n_shock x NC x NP
    W_g    = X_next + base_W;                         % n_shock x NC x NP
    u1_n   = max(min(Y_next_W ./ W_g, 1), 0);
    u2_n   = max(min(denAH ./ max(X_next + denAH, 1e-12), 1), 0);
    u3_n   = repmat(u3_col, [1, NC, NP]);             % independent of (c,pi)
    z_n    = reshape(pp_z(u1_n(:), u2_n(:), u3_n(:)), n_shock, NC, NP);
    CE     = W_g .* z_n;
    V_n    = CE .^ one_m_g / one_m_g;
    EV     = reshape(sum(w_join .* V_n, 1), NC, NP);   % NC x NP
    rhs    = u_now + beta_eff * EV;                     % u_now (NC x 1) broadcasts
    if beq_eff > 0
        beq_base = X_next + h_beq_fac * H_next_W;
        beq_n = beq_base .^ one_m_g / one_m_g;
        rhs   = rhs + beq_eff * reshape(sum(w_join .* beq_n, 1), NC, NP);
    end

    [mv_j, lin_idx] = max(rhs(:));
    if mv_j > best_v
        best_v = mv_j;
        [best_ic, best_ip] = ind2sub([NC, NP], lin_idx);
        best_it = jt;
    end
    end   % tau slice loop

    maxval = best_v; ic_max = best_ic; ip_max = best_ip;
    tau_flat(k) = tau_grid(best_it);

    % Grid-only whenever tau is a choice: the polish below is 2-var (c,pi) at a
    % FIXED tau and would silently re-solve at the glide slice.
    if skip_polish || optimise_tau
        V_flat(k) = maxval; c_flat(k) = c_grid(ic_max); pi_flat(k) = pi_grid(ip_max);
        continue
    end
    A_next_W = R_A_all(:, best_it) * A_next_pre_return;

    x0 = [c_grid(ic_max); pi_grid(ip_max)];
    lb = [c_floor; 0];
    ub = [1 - 1e-6; 1];
    polish_obj = @(x) -bellman_rhs_z_u(x(1), x(2), LW_W, Rf_at, R_S_at, ...
                                        A_next_W, H_next_W, Y_next_W, ...
                                        w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);

    V_polish = -inf; x_opt = x0;
    try
        [x_try, neg_V_try, exitflag] = fmincon(polish_obj, x0, [], [], [], [], lb, ub, [], opts_polish);
        if exitflag > 0 || exitflag == 0
            V_polish = -neg_V_try;
            x_opt    = x_try;
        end
    catch
    end

    if V_polish > maxval
        V_flat(k) = V_polish; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2);
    else
        V_flat(k) = maxval; c_flat(k) = c_grid(ic_max); pi_flat(k) = pi_grid(ip_max);
    end
end

V_t(:) = V_flat;
c_pol(:)  = c_flat;
pi_pol(:) = pi_flat;
if choose_tau, tau_pol(:) = tau_flat; end
end

function rhs_val = bellman_rhs_z_u(c, pi_eq, LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                                    w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac)
    % Same Bellman RHS as bellman_step's bellman_rhs_z, but the continuation
    % value is interpolated in (u1,u2,u3) coordinates.
    R_X      = (1 - pi_eq) * Rf_at + pi_eq .* R_S_at;
    X_next_W = R_X * (1 - c) * LW_W;
    denAH    = A_next_W + H_next_W;
    W_growth = X_next_W + denAH + Y_next_W;
    u1_next  = max(min(Y_next_W ./ W_growth, 1), 0);
    u2_next  = max(min(denAH ./ max(X_next_W + denAH, 1e-12), 1), 0);
    u3_next  = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
    z_n      = pp_z(u1_next, u2_next, u3_next);
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

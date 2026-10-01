function [V_t, c_pol, pi_pol] = bellman_step_lna(t, V_next, p, profile, shocks, ann_price, pol_next)
%BELLMAN_STEP_LNA  One backward-induction step on the (u1, u2, u3) cube.
%
%   [V_t, c_pol, pi_pol] = solver.bellman_step_lna(t, V_next, p, profile, shocks, ann_price, pol_next)
%
%   Coordinates and their map to wealth shares (W = X + A + H + Y):
%       u1 = Y/W,   u2 = (A+H)/(W-Y),   u3 = A/(A+H)
%       lambda = u1,  s_A = u2 (1-u1) u3,  s_H = u2 (1-u1)(1-u3),  s_X = (1-u1)(1-u2)
%   Every point of the unit cube is a feasible state.
%
%   The value function is homothetic, V(W, u) = W^(1-gamma) V_tilde(u). The
%   continuation is interpolated in its certainty equivalent per unit of
%   wealth, z = ((1-gamma) V_tilde)^(1/(1-gamma)), with p.interp_method
%   (linear by default) and flat extrapolation.
%
%   At each node the household chooses c, the share of liquid resources
%   consumed, and pi, the equity share of what it saves. The search runs in
%   three stages:
%     1. seed from next period's policy at the same node (pol_next);
%     2. if p.use_refine, a global sweep over (c, pi) -- a 21 x 21 grid
%        spanning both ranges, then three rounds shrinking around the best
%        point -- whose best point replaces the seed;
%     3. fmincon (active-set) from the seed, kept if it improves on it.
%   The objective has competing local peaks at a minority of nodes, mostly in
%   retirement, and a local solve from the warm start alone settles on the
%   wrong one there. The sweep is what finds the right basin.
%
%   Where liquid resources fall short of the floor phi_floor * Y, the
%   household consumes the floor and saves nothing.

N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid);
V_t    = nan(N1, N2, N3);
c_pol  = nan(N1, N2, N3);
pi_pol = nan(N1, N2, N3);

[U1, U2, U3] = ndgrid(p.u1_grid, p.u2_grid, p.u3_grid);
Lam_all = U1;
SA_all  = U2 .* (1 - Lam_all) .* U3;
SH_all  = U2 .* (1 - Lam_all) .* (1 - U3);

gamma   = p.gamma;
one_m_g = 1 - gamma;
inv_omg = 1 / one_m_g;

is_owner   = p.is_owner;
is_retired = (t >= p.t_ret);

% Income tax on wages, AOW and annuity; box-3 rates on the liquid account.
% The DC fund is sheltered, so its return stays pre-tax.
net_inc = 1 - p.tau_inc;
tau_b   = p.tau_cg_bond;
tau_w   = p.tau_wealth;

% Housing carrying cost as a share of H
if is_owner
    if t <= numel(p.m_rate_path), m_rate_t = p.m_rate_path(t); else, m_rate_t = 0; end
    h_cost_rate = p.theta + m_rate_t;
else
    h_cost_rate = p.alpha;
end

kappa_t   = p.kappa(min(t, numel(p.kappa)));
h_beq_fac = is_owner * (1 - p.sell_cost);   % renters bequeath no housing
phi_floor = p.phi_floor;
FLOOR_EPS = 1e-12;

% Take-home income per unit of gross income. Contributions are deducted
% before tax (EET).
if is_retired
    contrib_factor = net_inc;
else
    contrib_factor = (1 - kappa_t) * net_inc;
end

% Terminal period: consume all liquid resources, or split them with the
% bequest when chi > 0.
if t == p.T
    chi_T = p.chi;
    for k = 1:numel(Lam_all)
        lam = Lam_all(k); sA = SA_all(k); sH = SH_all(k);
        sX  = 1 - lam - sA - sH;
        if is_retired
            LW_W = sX + contrib_factor * lam + net_inc * sA / ann_price(t) ...
                    - h_cost_rate * sH;
        else
            LW_W = sX + contrib_factor * lam - h_cost_rate * sH;
        end
        LW_W  = max(LW_W, max(phi_floor * lam, FLOOR_EPS));
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
    return
end

tau_path  = config.tau_effective(p);
tau       = tau_path(t);
reit_path = config.reit_effective(p);
tau_R     = reit_path(t);
pt        = profile.p_surv(t);
beta_eff  = p.beta * pt;
beq_eff   = p.beta * (1 - pt) * p.chi;

R_S    = shocks.joint.R_S(:);
eps_Y  = shocks.joint.eps_Y_unit(:);
R_H    = shocks.joint.R_H(:);
R_REIT = shocks.joint.R_REIT(:);         % unit vector when the REIT is off
w_join = shocks.joint.w(:);
G_next = exp(profile.mu_growth(t) + profile.sigma_l_log(t) .* eps_Y);

% DC fund return with the survival credit: bonds, stock and REIT legs.
R_A = ((1 - tau - tau_R) * p.Rf + R_S * tau + R_REIT * tau_R) / pt;

% After-tax returns on the liquid account
Rf_at  = (1 + p.r * (1 - tau_b)) * (1 - tau_w);
R_S_at = config.after_tax_stock(p, R_S);

% Continuation in certainty-equivalent units
arg = one_m_g * V_next; arg(arg <= 0) = NaN;
z_next = arg .^ inv_omg;
z_finite = z_next(isfinite(z_next));
if isempty(z_finite)
    error('bellman_step_lna:no_finite_z', 'No finite z values at t=%d', t);
end
z_min = min(z_finite);
z_next(isnan(z_next)) = z_min;
interp_method = validatestring(p.interp_method, {'linear', 'makima', 'spline'}, ...
                               'bellman_step_lna', 'p.interp_method');
pp_lin = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                            z_next, interp_method, 'nearest');
if strcmp(interp_method, 'linear')
    pp_z = pp_lin;
else
    % A smooth scheme can undershoot below zero next to the ruin region.
    pp_z = @(a, b, c) max(pp_lin(a, b, c), z_min);
end

% fmincon minimises a scaled objective: |V| spans many orders of magnitude, and
% unscaled the objective sits below fmincon's tolerances.
obj_scale = 1;
absV = abs(V_next(isfinite(V_next) & V_next ~= 0));
if ~isempty(absV)
    obj_scale = 1 / median(absV);
    if ~isfinite(obj_scale) || obj_scale <= 0, obj_scale = 1; end
end

% Step sizes of the shrinking rounds of the sweep
NC = p.N_c;
pi_grid = linspace(0, 1, p.N_pi).';
dp0 = pi_grid(min(2, p.N_pi)) - pi_grid(1);
c_floor_frac = p.c_floor_frac;
use_refine   = p.use_refine;

opts_opt = optimoptions('fmincon', ...
    'Algorithm', 'active-set', ...
    'Display', 'off', ...
    'OptimalityTolerance', 1e-8, ...
    'StepTolerance', 1e-9, ...
    'FunctionTolerance', 1e-10, ...
    'MaxIterations', 200, ...
    'MaxFunctionEvaluations', 500, ...
    'FiniteDifferenceType', 'central');

n_states = numel(Lam_all);
V_flat  = zeros(n_states, 1);
c_flat  = zeros(n_states, 1);
pi_flat = zeros(n_states, 1);
lam_pts = Lam_all(:);
sA_pts  = SA_all(:);
sH_pts  = SH_all(:);

have_warm = ~isempty(pol_next) && isstruct(pol_next) && isfield(pol_next, 'c') ...
            && isequal(size(pol_next.c), [N1 N2 N3]);
if have_warm
    cw_pts = pol_next.c(:);
    pw_pts = pol_next.pi(:);
else
    cw_pts = nan(n_states, 1);
    pw_pts = nan(n_states, 1);
end

% Annuity payout in retirement: the pot pays A/a_t each period.
if is_retired
    ann_t      = ann_price(t);
    A_keep_fac = 1 - 1/ann_t;
else
    ann_t      = 1;
    A_keep_fac = 1;
end

parfor k = 1:n_states
    lam = lam_pts(k); sA = sA_pts(k); sH = sH_pts(k);
    sX  = 1 - lam - sA - sH;
    c_warm = cw_pts(k); pi_warm = pw_pts(k);

    if is_retired
        LW_W              = sX + contrib_factor * lam + net_inc * sA / ann_t ...
                                - h_cost_rate * sH;
        A_next_pre_return = sA * A_keep_fac;
    else
        LW_W              = sX + contrib_factor * lam - h_cost_rate * sH;
        A_next_pre_return = sA + kappa_t * lam;
    end

    H_next_W = sH * R_H;
    Y_next_W = G_next * lam;
    A_next_W = R_A * A_next_pre_return;
    F_W      = max(phi_floor * lam, FLOOR_EPS);

    if LW_W <= F_W
        % Resources below the floor: consume the floor, save nothing.
        u_f    = F_W ^ one_m_g / one_m_g;
        denAH0 = A_next_W + H_next_W;
        W_g0   = denAH0 + Y_next_W;
        u1_0   = max(min(Y_next_W ./ W_g0, 1), 0);
        u2_0   = max(min(denAH0 ./ max(denAH0, 1e-12), 1), 0);
        u3_0   = max(min(A_next_W ./ max(denAH0, 1e-12), 1), 0);
        z_0    = pp_z(u1_0, u2_0, u3_0);
        val    = u_f + beta_eff * sum(w_join .* ((W_g0 .* z_0) .^ one_m_g / one_m_g));
        if beq_eff > 0
            beq_base = max(h_beq_fac * H_next_W, FLOOR_EPS);
            val = val + beq_eff * sum(w_join .* (beq_base .^ one_m_g / one_m_g));
        end
        best = -inf;
        if val > best, best = val; end
        V_flat(k) = best; c_flat(k) = 1; pi_flat(k) = 0;
        continue
    end

    % Lower bound of the consumption search: c >= c_floor_frac / LW_W, i.e.
    % consumption of at least c_floor_frac of W. It binds in early life at the
    % production calibration, so read early-life consumption with that in mind.
    c_floor = max(1e-3, c_floor_frac / LW_W);
    c_floor = min(c_floor, 0.5);
    c_grid  = linspace(c_floor, 1 - 1e-6, NC).';
    dc0     = c_grid(2) - c_grid(1);

    % Stage 1: seed from next period's policy, or two fixed points without one.
    if isfinite(c_warm) && isfinite(pi_warm)
        cand = [min(max(c_warm, c_floor), 1 - 1e-6), min(max(pi_warm, 0), 1)];
    else
        cand = [0.5, 0.5; 0.15, 1.0];
    end
    maxval = -inf; c_seed = c_grid(1); pi_seed = 0;
    for s = 1:size(cand, 1)
        v = bellman_rhs(cand(s,1), cand(s,2), LW_W, Rf_at, R_S_at, ...
                A_next_W, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
        if v > maxval, maxval = v; c_seed = cand(s,1); pi_seed = cand(s,2); end
    end

    % Stage 2: global sweep
    if use_refine
        [c_sw, p_sw, v_sw] = sweep_cpi(c_seed, pi_seed, maxval, LW_W, Rf_at, R_S_at, ...
            A_next_W, H_next_W, Y_next_W, w_join, pp_z, one_m_g, beta_eff, beq_eff, ...
            h_beq_fac, c_floor, dc0, dp0);
        if v_sw > maxval
            maxval = v_sw; c_seed = c_sw; pi_seed = p_sw;
        end
    end

    % Stage 3: local solve from the seed
    lb2 = [c_floor; 0];
    ub2 = [1 - 1e-6; 1];
    obj_cpi = @(x) -obj_scale * bellman_rhs(x(1), x(2), LW_W, Rf_at, R_S_at, ...
                                            A_next_W, H_next_W, Y_next_W, ...
                                            w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
    x0 = [min(max(c_seed, c_floor), 1 - 1e-6); min(max(pi_seed, 0), 1)];
    V_opt = -inf; x_opt = x0;
    try
        [x_try, neg_V_try, exitflag] = fmincon(obj_cpi, x0, [], [], [], [], lb2, ub2, [], opts_opt);
        if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_opt
            V_opt = -neg_V_try/obj_scale; x_opt = x_try;
        end
    catch
    end

    if V_opt > maxval
        V_flat(k) = V_opt; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2);
    else
        V_flat(k) = maxval; c_flat(k) = c_seed; pi_flat(k) = pi_seed;
    end
end

V_t(:)    = V_flat;
c_pol(:)  = c_flat;
pi_pol(:) = pi_flat;
end

% ------------------------------------------------------------------------
function rhs_val = bellman_rhs(c, pi_eq, LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                               w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac)
%BELLMAN_RHS  Current utility plus discounted expected continuation, per unit
%   of W^(1-gamma). Next period's state is formed from the post-shock stocks
%   and mapped onto the cube.
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
    beq_n    = beq_base .^ one_m_g / one_m_g;
    E_beq    = sum(w .* beq_n);
    rhs_val  = rhs_val + beq_eff * E_beq;
end
end

% ------------------------------------------------------------------------
function [c_b, p_b, v_b] = sweep_cpi(c0, p0, v0, LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                                     w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0)
%SWEEP_CPI  Derivative-free search of the (c, pi) objective.
%   Round 1 evaluates 21 points of c across [c_floor, 1) against 21 points of
%   pi across [0, 1], plus the seed; rounds 2-4 search a 9 x 9 window around
%   the incumbent, shrinking by four each round. Returns the seed unchanged
%   unless something beats v0.
denAH  = A_next_W + H_next_W;
u3_col = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
base_W = denAH + Y_next_W;
n_shock = numel(w);
c_b = c0; p_b = p0; v_b = v0;
dc = dc0 / 4; dp = max(dp0, 0.05);
for r = 1:4
    if r == 1
        c_loc = unique([linspace(c_floor, 1 - 1e-6, 21), c0]);
        p_loc = unique([linspace(0, 1, 21), p0]);
    else
        c_loc = unique(min(max(c_b + dc * (-1 : 0.25 : 1), c_floor), 1 - 1e-6));
        p_loc = unique(min(max(p_b + dp * (-1 : 0.25 : 1), 0), 1));
        dc = dc / 4; dp = dp / 4;
    end
    [Cm, Pm] = ndgrid(c_loc, p_loc);
    M  = numel(Cm);
    cv = Cm(:).'; pv = Pm(:).';                  % 1 x M
    R_X    = (1 - pv) .* Rf_at + pv .* R_S_at;   % n_shock x M
    X_next = R_X .* ((1 - cv) * LW_W);
    W_g    = X_next + base_W;
    u1_n   = max(min(Y_next_W ./ W_g, 1), 0);
    u2_n   = max(min(denAH ./ max(X_next + denAH, 1e-12), 1), 0);
    u3_n   = repmat(u3_col, 1, M);
    z_n    = reshape(pp_z(u1_n(:), u2_n(:), u3_n(:)), n_shock, M);
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

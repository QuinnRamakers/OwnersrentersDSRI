function [V_t, c_pol, pi_pol] = bellman_step_lna(t, V_next, p, profile, shocks, ann_price, pol_next)
%BELLMAN_STEP_LNA  One backward-induction step on the (u1, u2, u3, q) grid.
%
%   [V_t, c_pol, pi_pol] = solver.bellman_step_lna(t, V_next, p, profile, shocks, ann_price, pol_next)
%
%   Coordinates and their map to wealth shares (W = X + A + H + Y):
%       u1 = Y/W,   u2 = (A+H)/(W-Y),   u3 = A/(A+H)
%       lambda = u1,  s_A = u2 (1-u1) u3,  s_H = u2 (1-u1)(1-u3),  s_X = (1-u1)(1-u2)
%   Every point of the unit cube is a feasible state. The fourth state,
%   q = H0/H on p.q_grid, sets an owner's mortgage payment, m q H with the
%   annuity, and with maint_on_purchase the maintenance, theta q H. It moves
%   as q' = q / R_H, whatever the household chooses. Arrays are
%   N_u1 x N_u2 x N_u3 x N_q. In a period where q enters neither this year's
%   budget nor any later one, one slice is solved and copied to the others;
%   where only the continuation does not depend on q, it is read in 3D off one
%   slice. With N_q = 1 the step is the cube alone. Without housing the
%   u3 = 0 nodes with u2 > 0 (a house the household cannot have) are copied
%   from u3 = 1 rather than solved.
%
%   The value function is homothetic, V(W, u, q) = W^(1-gamma) V_tilde(u, q).
%   The continuation is interpolated in its certainty equivalent per unit of
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
%     3. fmincon (p.fmincon_algorithm) from the seed, on the objective in
%        p.fmincon_objective units, kept if it improves on the seed.
%   The objective has competing local peaks at a minority of nodes, mostly in
%   retirement, and a local solve from the warm start alone settles on the
%   wrong one there. The sweep is what finds the right basin.
%
%   Where liquid resources fall short of the floor phi_floor * Y, the
%   household consumes the floor and saves nothing. Wherever nothing is saved
%   (c = 1), the equity share is stored as 1, or with p.pi_nothing_saved =
%   'limit' as the share of a vanishing saving (limit_share).

N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid);
q_grid = p.q_grid(:); Nq = numel(q_grid);
iq1    = find(q_grid == 1);
V_t    = nan(N1, N2, N3, Nq);
c_pol  = nan(N1, N2, N3, Nq);
pi_pol = nan(N1, N2, N3, Nq);

% Does q enter this year's problem (now or through any later year), and does
% it enter the continuation?
q_now  = Nq > 1 && any(p.q_live(t:end));
q_cont = Nq > 1 && t < p.T && any(p.q_live(t+1:end));
if q_now, slices = 1:Nq; else, slices = iq1; end

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

% Housing carrying cost as a share of H, one per q node. Without housing H = 0
% on every path; zero cost and bequest keep the housing parameters out of the
% solve, also at the nodes no one occupies. The annuity is paid on the
% purchase price, q H; the proportional contract on the current value, H.
if p.h_mult == 0
    h_cost_q = zeros(Nq, 1);
elseif is_owner
    if t <= numel(p.m_rate_path), m_rate_t = p.m_rate_path(t); else, m_rate_t = 0; end
    m_q  = m_rate_t * ones(Nq, 1);
    th_q = p.theta * ones(Nq, 1);
    if strcmp(p.mortgage, 'annuity'), m_q = m_rate_t * q_grid; end
    if p.maint_on_purchase, th_q = p.theta * q_grid; end
    h_cost_q = th_q + m_q;
else
    h_cost_q = p.alpha * ones(Nq, 1);
end

kappa_t   = p.kappa(min(t, numel(p.kappa)));
h_beq_fac = is_owner * (p.h_mult > 0) * (1 - p.sell_cost);   % renters bequeath no housing
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
    for iq = slices
        h_cost_rate = h_cost_q(iq);
        V_s = nan(N1, N2, N3); c_s = nan(N1, N2, N3); pi_s = nan(N1, N2, N3);
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
                V_s(k) = (c_star * LW_W)^one_m_g / one_m_g;
            else
                c_star = (LW_W + beq_H) / (LW_W * (1 + chi_T^(1/gamma)));
                c_star = min(max(c_star, 1e-6), 1);
                beq_part = (1 - c_star) * LW_W + beq_H;
                V_s(k) = (c_star * LW_W)^one_m_g / one_m_g ...
                         + chi_T * beq_part^one_m_g / one_m_g;
            end
            c_s(k)  = c_star;
            pi_s(k) = 0;
        end
        V_t(:, :, :, iq) = V_s; c_pol(:, :, :, iq) = c_s; pi_pol(:, :, :, iq) = pi_s;
    end
    [V_t, c_pol, pi_pol] = copy_slices(V_t, c_pol, pi_pol, q_now, iq1);
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
if q_cont
    pp_lin = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid, q_grid}, ...
                                z_next, interp_method, 'nearest');
else
    pp_lin = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                                z_next(:, :, :, iq1), interp_method, 'nearest');
end
if strcmp(interp_method, 'linear')
    pp_z = pp_lin;
else
    % A smooth scheme can undershoot below zero next to the ruin region.
    pp_z = @(varargin) max(pp_lin(varargin{:}), z_min);
end

% What fmincon minimises. 'ce': the objective in certainty-equivalent units
% relative to the seed, -(rhs / rhs_seed)^(1/(1-gamma)), the same optimum on a
% scale of order one at every node. 'utility': the objective in utility units,
% divided by the median |V| of next period (it spans many orders of magnitude).
use_ce = strcmp(validatestring(p.fmincon_objective, {'ce', 'utility'}, ...
                               'bellman_step_lna', 'p.fmincon_objective'), 'ce');
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
use_refine = p.use_refine;

algorithm = validatestring(p.fmincon_algorithm, {'active-set', 'sqp', 'interior-point'}, ...
                           'bellman_step_lna', 'p.fmincon_algorithm');
opts_opt = optimoptions('fmincon', ...
    'Algorithm', algorithm, ...
    'Display', 'off', ...
    'OptimalityTolerance', 1e-8, ...
    'StepTolerance', 1e-9, ...
    'FunctionTolerance', 1e-10, ...
    'MaxIterations', 200, ...
    'MaxFunctionEvaluations', 500, ...
    'FiniteDifferenceType', 'central');

n_states = numel(Lam_all);
lam_pts = Lam_all(:);
sA_pts  = SA_all(:);
sH_pts  = SH_all(:);

have_warm = ~isempty(pol_next) && isstruct(pol_next) && isfield(pol_next, 'c') ...
            && isequal(size(pol_next.c, 1:4), [N1 N2 N3 Nq]);

% Without housing H = 0 on every path, so u3 = A/(A+H) is 1 wherever the
% household holds a pension pot, and the u3 = 0 slice is reached only at
% u2 = 0, where u3 changes nothing. Its other nodes describe a house the
% household does not have: they are copied from u3 = 1 instead of solved.
copy_u3 = p.h_mult == 0 && N3 == 2 && isequal(p.u3_grid(:), [0; 1]);
if copy_u3
    solve_k = find(U3(:) == 1 | U2(:) == 0);
else
    solve_k = (1:n_states).';
end
n_solve = numel(solve_k);

% The equity share stored where nothing is saved (c = 1)
pi_limit = isfield(p, 'pi_nothing_saved') && strcmp(validatestring(p.pi_nothing_saved, ...
    {'one', 'limit'}, 'bellman_step_lna', 'p.pi_nothing_saved'), 'limit');

% Annuity payout in retirement: the pot pays A/a_t each period.
if is_retired
    ann_t      = ann_price(t);
    A_keep_fac = 1 - 1/ann_t;
else
    ann_t      = 1;
    A_keep_fac = 1;
end

for iq = slices
    h_cost_rate = h_cost_q(iq);
    % Next year's q at each shock node, where the continuation depends on it.
    if q_cont, q_n = q_grid(iq) ./ R_H; else, q_n = []; end
    if have_warm
        cw_pts = reshape(pol_next.c(:, :, :, iq), [], 1);
        pw_pts = reshape(pol_next.pi(:, :, :, iq), [], 1);
    else
        cw_pts = nan(n_states, 1);
        pw_pts = nan(n_states, 1);
    end
    V_sub  = zeros(n_solve, 1);
    c_sub  = zeros(n_solve, 1);
    pi_sub = zeros(n_solve, 1);

    parfor j = 1:n_solve
        k = solve_k(j);
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
            z_0    = z_at(pp_z, u1_0, u2_0, u3_0, q_n);
            val    = u_f + beta_eff * sum(w_join .* ((W_g0 .* z_0) .^ one_m_g / one_m_g));
            if beq_eff > 0
                beq_base = max(h_beq_fac * H_next_W, FLOOR_EPS);
                val = val + beq_eff * sum(w_join .* (beq_base .^ one_m_g / one_m_g));
            end
            best = -inf;
            if val > best, best = val; end
            V_sub(j) = best; c_sub(j) = 1; pi_sub(j) = 1;   % nothing saved: 100% in equity, as below
            continue
        end

        % Lower bound of the consumption search: the consumption floor,
        % C >= phi_floor * Y, i.e. c >= F_W / LW_W. Here LW_W > F_W, so c_floor < 1.
        c_floor = F_W / LW_W;
        c_grid  = linspace(c_floor, 1, NC).';
        dc0     = c_grid(2) - c_grid(1);

        % Stage 1: seed from next period's policy, or two fixed points without one.
        if isfinite(c_warm) && isfinite(pi_warm)
            cand = [min(max(c_warm, c_floor), 1), min(max(pi_warm, 0), 1)];
        else
            cand = [0.5, 0.5; 0.15, 1.0];
        end
        maxval = -inf; c_seed = c_grid(1); pi_seed = 0;
        for s = 1:size(cand, 1)
            v = bellman_rhs(cand(s,1), cand(s,2), LW_W, Rf_at, R_S_at, ...
                    A_next_W, H_next_W, Y_next_W, ...
                    w_join, pp_z, q_n, one_m_g, beta_eff, beq_eff, h_beq_fac);
            if v > maxval, maxval = v; c_seed = cand(s,1); pi_seed = cand(s,2); end
        end

        % Stage 2: global sweep
        if use_refine
            [c_sw, p_sw, v_sw] = sweep_cpi(c_seed, pi_seed, maxval, LW_W, Rf_at, R_S_at, ...
                A_next_W, H_next_W, Y_next_W, w_join, pp_z, q_n, one_m_g, beta_eff, beq_eff, ...
                h_beq_fac, c_floor, dc0, dp0);
            if v_sw > maxval
                maxval = v_sw; c_seed = c_sw; pi_seed = p_sw;
            end
        end

        % Stage 3: local solve from the seed
        lb2 = [c_floor; 0];
        ub2 = [1; 1];
        rhs_fun = @(x) bellman_rhs(x(1), x(2), LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                                   w_join, pp_z, q_n, one_m_g, beta_eff, beq_eff, h_beq_fac);
        if use_ce
            % Certainty-equivalent units relative to the seed: a monotone
            % transform of the objective, equal to -1 at the seed at every node.
            obj_cpi = @(x) -(rhs_fun(x) / maxval) ^ inv_omg;
        else
            obj_cpi = @(x) -obj_scale * rhs_fun(x);
        end
        x0 = [min(max(c_seed, c_floor), 1); min(max(pi_seed, 0), 1)];
        V_opt = -inf; x_opt = x0;
        try
            [x_try, ~, exitflag] = fmincon(obj_cpi, x0, [], [], [], [], lb2, ub2, [], opts_opt);
            V_try = rhs_fun(x_try);
            if (exitflag > 0 || exitflag == 0) && V_try > V_opt
                V_opt = V_try; x_opt = x_try;
            end
        catch
        end

        if V_opt > maxval
            V_sub(j) = V_opt; c_sub(j) = x_opt(1); pi_sub(j) = x_opt(2);
        else
            V_sub(j) = maxval; c_sub(j) = c_seed; pi_sub(j) = pi_seed;
        end
        % With nothing saved the equity share has no effect and every share ties.
        % Store a share that interpolation and next year's warm start can use:
        % 100% in equity, or with p.pi_nothing_saved = 'limit' the share the
        % household would choose for its first euro of saving.
        if c_sub(j) >= 1
            if pi_limit
                pi_sub(j) = limit_share(LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                    w_join, pp_z, q_n, one_m_g, beta_eff, beq_eff, h_beq_fac);
            else
                pi_sub(j) = 1;
            end
        end
    end

    V_flat  = zeros(n_states, 1); V_flat(solve_k)  = V_sub;
    c_flat  = zeros(n_states, 1); c_flat(solve_k)  = c_sub;
    pi_flat = zeros(n_states, 1); pi_flat(solve_k) = pi_sub;
    if copy_u3
        V_flat  = copy_u3_slice(V_flat, N1, N2, p.u2_grid);
        c_flat  = copy_u3_slice(c_flat, N1, N2, p.u2_grid);
        pi_flat = copy_u3_slice(pi_flat, N1, N2, p.u2_grid);
    end
    V_t(:, :, :, iq)    = reshape(V_flat, N1, N2, N3);
    c_pol(:, :, :, iq)  = reshape(c_flat, N1, N2, N3);
    pi_pol(:, :, :, iq) = reshape(pi_flat, N1, N2, N3);
end
[V_t, c_pol, pi_pol] = copy_slices(V_t, c_pol, pi_pol, q_now, iq1);
end

% ------------------------------------------------------------------------
function [V, c, pi_] = copy_slices(V, c, pi_, q_now, iq1)
%COPY_SLICES  Where q enters neither this year nor later, every q slice is the
%   one solved.
if q_now || size(V, 4) == 1, return; end
Nq = size(V, 4);
V   = repmat(V(:, :, :, iq1), 1, 1, 1, Nq);
c   = repmat(c(:, :, :, iq1), 1, 1, 1, Nq);
pi_ = repmat(pi_(:, :, :, iq1), 1, 1, 1, Nq);
end

% ------------------------------------------------------------------------
function p_b = limit_share(LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                           w, pp_z, q_n, one_m_g, beta_eff, beq_eff, h_beq_fac)
%LIMIT_SHARE  The equity share of a vanishing saving: the best share when
%   1e-6 of liquid resources is saved, from 21 shares and three rounds
%   shrinking around the best. To first order in the saving the objective is
%   linear in the share, so the answer is normally 0 or 1: the sign of the
%   marginal-utility-weighted equity premium.
c = 1 - 1e-6;
f = @(pi_) bellman_rhs(c, pi_, LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                       w, pp_z, q_n, one_m_g, beta_eff, beq_eff, h_beq_fac);
grid_ = linspace(0, 1, 21);
v = arrayfun(f, grid_);
[v_b, i] = max(v); p_b = grid_(i);
dp = 0.05;
for r = 1:3
    loc = unique(min(max(p_b + dp * (-1 : 0.25 : 1), 0), 1));
    v = arrayfun(f, loc);
    [mv, i] = max(v);
    if mv > v_b, v_b = mv; p_b = loc(i); end
    dp = dp / 4;
end
end

% ------------------------------------------------------------------------
function v = copy_u3_slice(v, N1, N2, u2_grid)
%COPY_U3_SLICE  Fill the unsolved u3 = 0 nodes (u2 > 0) from u3 = 1.
v = reshape(v, N1, N2, 2);
m = u2_grid(:).' > 0;
v(:, m, 1) = v(:, m, 2);
v = v(:);
end

% ------------------------------------------------------------------------
function z = z_at(pp_z, u1, u2, u3, q)
%Z_AT  The continuation at next year's states; q is empty where it does not
%   depend on q.
if isempty(q), z = pp_z(u1, u2, u3); else, z = pp_z(u1, u2, u3, q); end
end

% ------------------------------------------------------------------------
function rhs_val = bellman_rhs(c, pi_eq, LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                               w, pp_z, q_n, one_m_g, beta_eff, beq_eff, h_beq_fac)
%BELLMAN_RHS  Current utility plus discounted expected continuation, per unit
%   of W^(1-gamma). Next period's state is formed from the post-shock stocks
%   and mapped onto the cube; q_n is next period's q at each shock node.
R_X      = (1 - pi_eq) * Rf_at + pi_eq .* R_S_at;
X_next_W = R_X * (1 - c) * LW_W;
denAH    = A_next_W + H_next_W;
W_growth = X_next_W + denAH + Y_next_W;
u1_next  = max(min(Y_next_W ./ W_growth, 1), 0);
u2_next  = max(min(denAH ./ max(X_next_W + denAH, 1e-12), 1), 0);
u3_next  = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
z_n      = z_at(pp_z, u1_next, u2_next, u3_next, q_n);
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
                                     w, pp_z, q_n, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0)
%SWEEP_CPI  Derivative-free search of the (c, pi) objective.
%   Round 1 evaluates 21 points of c across [c_floor, 1] against 21 points of
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
        c_loc = unique([linspace(c_floor, 1, 21), c0]);
        p_loc = unique([linspace(0, 1, 21), p0]);
    else
        c_loc = unique(min(max(c_b + dc * (-1 : 0.25 : 1), c_floor), 1));
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
    if isempty(q_n)
        z_n = reshape(pp_z(u1_n(:), u2_n(:), u3_n(:)), n_shock, M);
    else
        q_rep = repmat(q_n, 1, M);
        z_n = reshape(pp_z(u1_n(:), u2_n(:), u3_n(:), q_rep(:)), n_shock, M);
    end
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

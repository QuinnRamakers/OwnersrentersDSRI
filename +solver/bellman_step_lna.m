function [V_t, c_pol, pi_pol, tau_pol] = bellman_step_lna(t, V_next, p, profile, shocks, ann_price, pol_next)
%BELLMAN_STEP_LNA  One backward-induction step on the new coordinate system.
%
%   Solves the household's problem at age t on the cube coordinates
%       u1 = Y / W                 income share of  wealth
%       u2 = (A + H) / (W - Y)     illiquid share of non-income wealth
%       u3 = A / (A + H)           pension share of the illiquid block
%   which map back to the wealth shares by
%       lambda = u1,   s_A = u2 (1-u1) u3,   s_H = u2 (1-u1)(1-u3),
%       s_X    = (1-u1)(1-u2).
%
%   Given next period's value function V_next (and, under free DC choice, the
%   next period's policy pol_next used to warm-start the search), it returns
%   this period's value V_t and the optimal policies: consumption c, liquid
%   equity share pi, and the pension equity share tau if turned on.
%

% The pension equity share tau is a free choice while working when the fund
% lets the household pick it (p.choose_tau_S); otherwise it follows the fund.
% After retirement it is always the fund's decumulation setting.
choose_tau   = isfield(p, 'choose_tau_S') && p.choose_tau_S;
optimise_tau = choose_tau && (t < p.t_ret);

%storage construction
N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid);
V_t    = nan(N1, N2, N3);
c_pol  = nan(N1, N2, N3);
pi_pol = nan(N1, N2, N3);
tau_pol = [];
if choose_tau, tau_pol = nan(N1, N2, N3); end

%grid construction
[U1, U2, U3] = ndgrid(p.u1_grid, p.u2_grid, p.u3_grid);
Lam_all = U1;
SA_all  = U2 .* (1 - U1) .* U3;
SH_all  = U2 .* (1 - U1) .* (1 - U3);

%storage of common calculations
gamma   = p.gamma;
one_m_g = 1 - gamma;
inv_omg = 1 / one_m_g;

% set booleans for type and working status
is_owner   = p.is_owner;
is_retired = (t >= p.t_ret);

% legacy code tag from an old version that uses a more extensive optimisation (not required anymore after other code fixes but kept for legacy purposes)

skip_polish = false; if isfield(p, 'skip_polish'), skip_polish = logical(p.skip_polish); end

% Optimisation routine 
%   grid_mode = 'full'  search a (c, pi) grid of guesses, then refine the best point with
%                       fmincon. (legacy)
%   grid_mode = 'none'  skip the grid and run fmincon from the warm start --
%                       next period's policy at this node -- which is faster and
%                       is the default. Requires polish_ver >= 2.
% For normal runs it takes whatever is chosen, for free DC choice it still uses the grid as a backup that hasn't been rewritten yet with the new optimisation routine
%some setup of boolean that assings what legacy parts of the optimisation routine need to run
if nargin < 7, pol_next = []; end
polish_ver = 1; if isfield(p, 'polish_ver'), polish_ver = p.polish_ver; end
use_scaling = polish_ver >= 2;
use_warm    = polish_ver >= 2;
grid_mode   = 'full'; if isfield(p, 'grid_mode'), grid_mode = char(p.grid_mode); end
skip_tensor = strcmp(grid_mode, 'none') && ~optimise_tau && use_warm;

% Tax rates (default to zero if the field is absent):
%   tau_inc       income tax on wages, state pension and annuity payments.
%   tau_b, tau_s  capital-gains tax on  liquid saving.
%   tau_w         wealth tax on the liquid balance.
% The pension fund is tax-sheltered, so its return stays pre-tax.
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
% min() is for legacy bugs
kappa_t = p.kappa(min(t, numel(p.kappa)));

% Bequeathed housing value as a fraction of H: owners'  sell the house at death
% and pay p.sell_cost; renters bequeath no housing.
sell_cost = 0; if isfield(p, 'sell_cost'), sell_cost = p.sell_cost; end
h_beq_fac = is_owner * (1 - sell_cost);

% Consumption floor as a share of W: phi_floor * lambda (config.params).
% Numerical protection against very low consumption
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
    return
end

% Build the interpolation space of the continuations and optimie the current state

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
% Candidate pension equity shares. With no choice this defaults to the assigned strategy, with free choice it creates a grid to search
if optimise_tau
    NT = 11; if isfield(p, 'N_tau'), NT = p.N_tau; end
    tau_grid = unique([linspace(0, 1, NT).'; tau]);
else
    tau_grid = tau;
end
NTg     = numel(tau_grid);
j_glide = find(tau_grid == tau, 1);
% Rate of returns per realisation of the Markov process
R_A_all = ((1 - tau_grid.') * p.Rf + R_S * tau_grid.') / pt;

% After-tax returns on the liquid account
% (stocks taxed only on gains), then the wealth tax on the end-of-period balance.
Rf_at  = (1 + p.r * (1 - tau_b)) * (1 - tau_w);            % bond leg
R_S_at = (R_S - tau_s .* max(R_S - 1, 0)) .* (1 - tau_w);  % stock leg

% Transform of the continuitions to the inverse
arg = one_m_g * V_next; arg(arg <= 0) = NaN;
z_next = arg .^ inv_omg;
z_finite = z_next(isfinite(z_next));
if isempty(z_finite)
    error('bellman_step_lna:no_finite_z', 'No finite z values at t=%d', t);
end
z_min = min(z_finite);
z_next(isnan(z_next)) = z_min;
% Linear inside, gets clamped to the space if a value is outside the grid
pp_z = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                          z_next, 'linear', 'nearest');

% Scale the fmincon objective by the median of the next period
obj_scale = 1;
if use_scaling
    absV = abs(V_next(isfinite(V_next) & V_next ~= 0));
    if ~isempty(absV)
        obj_scale = 1 / median(absV);
        if ~isfinite(obj_scale) || obj_scale <= 0, obj_scale = 1; end
    end
end

% Grid of consumption and equity-share candidates that seeds the search. (legacy optimisation)
NC = 41; if isfield(p, 'N_c'),  NC = p.N_c;  end
NP = 41; if isfield(p, 'N_pi'), NP = p.N_pi; end
pi_grid = linspace(0, 1, NP).';
R_X_all = (1 - pi_grid) * Rf_at + pi_grid * R_S_at.';     % NP x n_shock (after-tax)

%fmincon settings
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
tau_flat = zeros(n_states, 1);
c_flat   = zeros(n_states, 1);
pi_flat  = zeros(n_states, 1);

lam_pts = Lam_all(:);
sA_pts  = SA_all(:);
sH_pts  = SH_all(:);

% Warm start for each state: next period's policy at the same node
have_warm = use_warm && ~isempty(pol_next) && isstruct(pol_next) ...
            && isfield(pol_next, 'c') && isequal(size(pol_next.c), [N1 N2 N3]);
if have_warm
    cw_pts = pol_next.c(:);
    pw_pts = pol_next.pi(:);
else
    cw_pts = nan(n_states, 1);
    pw_pts = nan(n_states, 1);
end

% Annuity payout factor for retired branch (constants outside parfor)
if is_retired
    ann_t      = ann_price(t);
    A_keep_fac = 1 - 1/ann_t;             % A_next_pre / s_A
else
    ann_t      = 1;                        % unused on working branch
    A_keep_fac = 1;
end


%the actual loop
parfor k = 1:n_states
    lam = lam_pts(k); sA = sA_pts(k); sH = sH_pts(k);
    sX  = 1 - lam - sA - sH;
    c_warm = cw_pts(k); pi_warm = pw_pts(k);   % t+1 policy at this node (glide seed)

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
            V_flat(k) = -1e15; c_flat(k) = 1e-6; pi_flat(k) = 0; tau_flat(k) = tau;
            continue
        end
    elseif LW_W <= F_W
        % Consume the minimum amount and set savings to zero (implied call option)
        u_f = F_W ^ one_m_g / one_m_g;
        best = -inf; j_best = 1;
        for j = 1:NTg
            A_n    = R_A_all(:, j) * A_next_pre_return;
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
            if val > best, best = val; j_best = j; end
        end
        V_flat(k) = best; c_flat(k) = 1; pi_flat(k) = 0; tau_flat(k) = tau_grid(j_best);
        continue
    end
   
    % Lower bound on the consumption search (a small share of resources).
    c_floor = max(1e-3, 0.01 / LW_W);
    c_floor = min(c_floor, 0.5);
    c_grid  = linspace(c_floor, 1 - 1e-6, NC).';
    u_now   = (c_grid * LW_W) .^ one_m_g / one_m_g;

    % Seed the polish as CONTINUOUS points (c_seed, pi_seed), so the two modes
    % share the downstream code: from the tensor argmax with a grid search, or
    % from the warm start when the tensor is off.
    maxval = -inf; ic_max = 1; ip_max = 1; it_max = 1;
    maxval_g = -inf; ic_g = 1; ip_g = 1;
    rhs_g = [];
    c_seed = c_grid(1); pi_seed = 0;

    if skip_tensor
        % No tensor (glide + warm start): the t+1 policy at this node is the
        % seed; two fixed fallbacks when there is none, so the polish always has
        % somewhere to start. Mirror of solver.bellman_step's skip_tensor branch.
        A_next_W_g = R_A_all(:, 1) * A_next_pre_return;
        if isfinite(c_warm) && isfinite(pi_warm)
            cand = [min(max(c_warm, c_floor), 1 - 1e-6), min(max(pi_warm, 0), 1)];
        else
            cand = [0.5, 0.5; 0.15, 1.0];
        end
        for s = 1:size(cand, 1)
            v = bellman_rhs_z_u(cand(s,1), cand(s,2), LW_W, Rf_at, R_S_at, ...
                    A_next_W_g, H_next_W, Y_next_W, ...
                    w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
            if v > maxval, maxval = v; c_seed = cand(s,1); pi_seed = cand(s,2); end
        end
        maxval_g = maxval;
    else
    % Grid search over consumption and equity share for each candidate pension
    % share. The next-period cube coordinates (u1, u2, u3) are formed from the
    % resulting wealth and clamped to the grid. The liquid balance does not
    % depend on the pension share, so it is computed once outside the loop.
    sav    = (1 - c_grid).' * LW_W;                   % 1 x NC (saved liquid wealth)
    RX     = reshape(R_X_all.', n_shock, 1, NP);      % n_shock x 1 x NP
    X_next = RX .* sav;                               % n_shock x NC x NP

    for j = 1:NTg
        A_next_W_j = R_A_all(:, j) * A_next_pre_return;   % n_shock x 1
        denAH  = A_next_W_j + H_next_W;                   % n_shock x 1
        u3_col = max(min(A_next_W_j ./ max(denAH, 1e-12), 1), 0);
        base_W = denAH + Y_next_W;                        % n_shock x 1
        W_g    = X_next + base_W;                         % n_shock x NC x NP
        u1_n   = max(min(Y_next_W ./ W_g, 1), 0);
        u2_n   = max(min(denAH ./ max(X_next + denAH, 1e-12), 1), 0);
        u3_n   = repmat(u3_col, [1, NC, NP]);             % independent of (c,pi)
        z_n    = reshape(pp_z(u1_n(:), u2_n(:), u3_n(:)), n_shock, NC, NP);
        V_n    = (W_g .* z_n) .^ one_m_g / one_m_g;
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
            if optimise_tau, rhs_g = rhs; end
        end
    end
    c_seed = c_grid(ic_max); pi_seed = pi_grid(ip_max);
    end   % if skip_tensor

    if skip_polish
        V_flat(k) = maxval; c_flat(k) = c_seed; pi_flat(k) = pi_seed;
        tau_flat(k) = tau_grid(it_max);
        continue
    end

    lb2 = [c_floor; 0];
    ub2 = [1 - 1e-6; 1];

    if optimise_tau
        % Free choice: optimise (c, pi, tau) jointly from the grid's best point,
        % then also run the search with tau pinned to the fund's glide value.
        % Pinning at the glide guarantees the free arm can always reproduce it,
        % so its value never falls below the glide arm's.
        obj3 = @(x) -obj_scale * bellman_rhs_z3_u(x(1), x(2), x(3), LW_W, Rf_at, R_S_at, ...
                                       p.Rf, R_S, pt, A_next_pre_return, ...
                                       H_next_W, Y_next_W, ...
                                       w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
        V_polish = -inf; x_opt = [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)];
        try
            [x_try, neg_V_try, exitflag] = fmincon(obj3, ...
                [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)], ...
                [], [], [], [], [c_floor; 0; 0], [1 - 1e-6; 1; 1], [], opts_polish);
            if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_polish
                V_polish = -neg_V_try/obj_scale; x_opt = x_try;
            end
        catch
        end

        pin_starts = [c_grid(ic_max), pi_grid(ip_max), tau_grid(it_max)];
        if it_max ~= j_glide && isfinite(maxval_g)
            pin_starts = [pin_starts; c_grid(ic_g), pi_grid(ip_g), tau];
        end
        v_gl = maxval_g; c_gl = c_grid(ic_g); p_gl = pi_grid(ip_g);
        % The objective has several local optima in c, so seed the pinned runs
        % from each local maximum of the glide slice, not just its best point.
        if ~isempty(rhs_g)
            is_lmax = true(NC, NP);
            is_lmax(2:NC,   :) = is_lmax(2:NC,   :) & (rhs_g(2:NC,:)   >= rhs_g(1:NC-1,:));
            is_lmax(1:NC-1, :) = is_lmax(1:NC-1, :) & (rhs_g(1:NC-1,:) >= rhs_g(2:NC,:));
            is_lmax(:, 2:NP  ) = is_lmax(:, 2:NP  ) & (rhs_g(:,2:NP)   >= rhs_g(:,1:NP-1));
            is_lmax(:, 1:NP-1) = is_lmax(:, 1:NP-1) & (rhs_g(:,1:NP-1) >= rhs_g(:,2:NP));
            is_lmax(ic_g, ip_g) = false;
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
            obj2 = @(x) -obj_scale * bellman_rhs_z3_u(x(1), x(2), tau_fix, LW_W, Rf_at, R_S_at, ...
                                           p.Rf, R_S, pt, A_next_pre_return, ...
                                           H_next_W, Y_next_W, ...
                                           w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
            try
                [x_try, neg_V_try, exitflag] = fmincon(obj2, pin_starts(s, 1:2).', ...
                    [], [], [], [], lb2, ub2, [], opts_polish);
                if exitflag > 0 || exitflag == 0
                    if -neg_V_try/obj_scale > V_polish
                        V_polish = -neg_V_try/obj_scale; x_opt = [x_try; tau_fix];
                    end
                    if tau_fix == tau && -neg_V_try/obj_scale > v_gl
                        v_gl = -neg_V_try/obj_scale; c_gl = x_try(1); p_gl = x_try(2);
                    end
                end
            catch
            end
        end

        % A short derivative-free search around the best point, which resolves
        % narrow ridges in the interpolated surface that fmincon can step over.
        % Run it at the glide tau and at the current best tau.
        dc0 = c_grid(2) - c_grid(1);
        dp0 = pi_grid(min(2, NP)) - pi_grid(1);
        if isfinite(v_gl)
            [c_r, p_r, v_r] = refine_cpi_u(c_gl, p_gl, tau, v_gl, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0);
            if v_r > V_polish, V_polish = v_r; x_opt = [c_r; p_r; tau]; end
        end
        if V_polish > maxval
            cb0 = x_opt(1); pb0 = x_opt(2); tb0 = x_opt(3); vb0 = V_polish;
        else
            cb0 = c_grid(ic_max); pb0 = pi_grid(ip_max); tb0 = tau_grid(it_max); vb0 = maxval;
        end
        [c_r, p_r, v_r] = refine_cpi_u(cb0, pb0, tb0, vb0, LW_W, Rf_at, R_S_at, ...
            p.Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
            w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0);
        if v_r > V_polish, V_polish = v_r; x_opt = [c_r; p_r; tb0]; end

        if V_polish > maxval
            V_flat(k) = V_polish; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2); tau_flat(k) = x_opt(3);
        else
            V_flat(k) = maxval; c_flat(k) = c_grid(ic_max); pi_flat(k) = pi_grid(ip_max);
            tau_flat(k) = tau_grid(it_max);
        end
    else
        A_next_W = R_A_all(:, 1) * A_next_pre_return;   % glide-slice DC position
        polish_obj = @(x) -obj_scale * bellman_rhs_z_u(x(1), x(2), LW_W, Rf_at, R_S_at, ...
                                            A_next_W, H_next_W, Y_next_W, ...
                                            w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);

        % Best seed: the tensor argmax, or the warm start when the tensor is off.
        % With the tensor on, add the t+1 policy as a second start.
        starts = [c_seed, pi_seed];
        if ~skip_tensor && isfinite(c_warm) && isfinite(pi_warm)
            starts = [starts; min(max(c_warm, c_floor), 1 - 1e-6), min(max(pi_warm, 0), 1)];
        end
        starts(:,1) = min(max(starts(:,1), c_floor), 1 - 1e-6);
        starts(:,2) = min(max(starts(:,2), 0), 1);

        V_polish = -inf; x_opt = starts(1, :).';
        for s = 1:size(starts, 1)
            try
                [x_try, neg_V_try, exitflag] = fmincon(polish_obj, starts(s, :).', ...
                    [], [], [], [], lb2, ub2, [], opts_polish);
                if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_polish
                    V_polish = -neg_V_try/obj_scale; x_opt = x_try;
                end
            catch
            end
        end

        % Same derivative-free refinement as the free-tau branch.
        if use_scaling
            dc0 = c_grid(2) - c_grid(1);
            dp0 = pi_grid(min(2, NP)) - pi_grid(1);
            if V_polish > maxval
                cb0 = x_opt(1); pb0 = x_opt(2); vb0 = V_polish;
            else
                cb0 = c_seed; pb0 = pi_seed; vb0 = maxval;
            end
            [c_r, p_r, v_r] = refine_cpi_u(cb0, pb0, tau, vb0, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0);
            if v_r > V_polish, V_polish = v_r; x_opt = [c_r; p_r]; end
        end

        if V_polish > maxval
            V_flat(k) = V_polish; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2);
        else
            V_flat(k) = maxval; c_flat(k) = c_seed; pi_flat(k) = pi_seed;
        end
        tau_flat(k) = tau;
    end
end

V_t(:)    = V_flat;
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

function rhs_val = bellman_rhs_z3_u(c, pi_eq, tau_dc, LW_W, Rf_at, R_S_at, Rf, R_S, pt, ...
                                     A_next_pre_return, H_next_W, Y_next_W, ...
                                     w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac)
    % 3-choice Bellman RHS on the cube: as bellman_rhs_z_u, but the DC position
    % is rebuilt from the choice variable tau_dc (survival-credit return,
    % PRE-TAX -- the fund is sheltered; only the liquid legs carry tax).
    R_A      = ((1 - tau_dc) * Rf + tau_dc .* R_S) / pt;
    A_next_W = R_A * A_next_pre_return;
    R_X      = (1 - pi_eq) * Rf_at + pi_eq .* R_S_at;
    X_next_W = R_X * (1 - c) * LW_W;
    denAH    = A_next_W + H_next_W;
    W_growth = X_next_W + denAH + Y_next_W;
    u1_next  = max(min(Y_next_W ./ W_growth, 1), 0);
    u2_next  = max(min(denAH ./ max(X_next_W + denAH, 1e-12), 1), 0);
    u3_next  = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
    z_n      = pp_z(u1_next, u2_next, u3_next);
    V_n      = (W_growth .* z_n) .^ one_m_g / one_m_g;
    rhs_val  = (c * LW_W) ^ one_m_g / one_m_g + beta_eff * sum(w .* V_n);
    if beq_eff > 0
        beq_base = X_next_W + h_beq_fac * H_next_W;
        rhs_val  = rhs_val + beq_eff * sum(w .* (beq_base .^ one_m_g / one_m_g));
    end
end

function [c_b, p_b, v_b] = refine_cpi_u(c0, p0, tau_fix, v0, LW_W, Rf_at, R_S_at, Rf, R_S, pt, ...
                                         A_next_pre_return, H_next_W, Y_next_W, ...
                                         w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, ...
                                         c_floor, dc0, dp0)
    % Shrinking-radius local grid scan of the (c, pi) surface with tau pinned.
    % Derivative-free, so it resolves the narrow interpolation-kink ridges that
    % defeat fmincon's finite differences. Cube twin of refine_cpi.
    R_A      = ((1 - tau_fix) * Rf + tau_fix .* R_S) / pt;
    A_next_W = R_A * A_next_pre_return;
    denAH    = A_next_W + H_next_W;
    u3_col   = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
    base_W   = denAH + Y_next_W;
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

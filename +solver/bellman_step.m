function [V_t, c_pol, pi_pol, feas, tau_pol] = bellman_step(t, V_next, p, profile, shocks, ann_price)
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
%     Free DC choice (p.choose_tau_S true): (c, pi, tau) -- the DC equity
%       share becomes a third choice variable. Unified grid search over
%       (n_shock x N_c x N_pi x N_tau) tau-slices -- the tau seed grid is
%       linspace(0,1,p.N_tau) with the glide value tau_S(t) appended, so the
%       free search always contains the glide slice and free choice can
%       never lose to the glide on the grid -- plus a 3-var fmincon polish
%       started from the best grid point (and additionally from the glide
%       slice's best point when that is a different tau slice; best kept).
%       tau_pol (5th output) returns the chosen DC share; it is [] when
%       choose_tau_S is off. With a single tau slice the tensor collapses to
%       the old glide-path grid search exactly (bit-identical).
%   z-transform on V_next throughout.

NL = p.N_lambda; NA = p.N_sA; NH = p.N_sH;
V_t    = nan(NL, NA, NH);
c_pol  = nan(NL, NA, NH);
pi_pol = nan(NL, NA, NH);

choose_tau = isfield(p, 'choose_tau_S') && p.choose_tau_S;
tau_pol = [];
if choose_tau
    tau_pol = nan(NL, NA, NH);
end

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

% Income contribution factor (take-home wage as fraction of Y)
if is_retired
    contrib_factor = (1 - p.delta) * net_inc;            % AOW, taxed as income
else
    contrib_factor = (1 - p.delta) * (1 - p.kappa) * net_inc;  % deductible contrib; rest taxed
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
                if LW_W <= 1e-12
                    V_t(il, ia, ih)    = -1e15;
                    c_pol(il, ia, ih)  = 1e-6;
                    pi_pol(il, ia, ih) = 0;
                    continue
                end
                beq_H = is_owner * sH;
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

% DC equity-share grid. Glide regime: the single fixed tau_S(t) value (the
% grid search below then collapses to the old one-slice tensor exactly).
% Free choice: linspace seed grid with the glide value appended (unique()
% keeps it a single copy when it coincides with a seed point), so the free
% search always weakly dominates the glide slice on the grid.
if choose_tau
    NT = 11; if isfield(p, 'N_tau'), NT = p.N_tau; end
    tau_grid = unique([linspace(0, 1, NT).'; tau]);
else
    tau_grid = tau;
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
z_next_filled = z_next;
z_next_filled(~feas) = z_min;
z_next_filled(isnan(z_next_filled)) = z_min;
pp_z = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, ...
                          z_next_filled, 'linear', 'linear');

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

    if is_retired
        LW_W              = sX + contrib_factor * lam + net_inc * sA / ann_t ...
                                - h_cost_rate * sH;
        A_next_pre_return = sA * A_keep_fac;
    else
        LW_W              = sX + contrib_factor * lam - h_cost_rate * sH;
        A_next_pre_return = sA + p.kappa * lam;
    end

    if LW_W <= 1e-9
        V_flat(k) = -1e15; c_flat(k) = 1e-6; pi_flat(k) = 0; tau_flat(k) = tau;
        continue
    end

    H_next_W = sH * R_H;                     % n_shock x 1
    Y_next_W = G_next * lam;                 % n_shock x 1

    % Scale-aware c lower bound
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
        z_n    = reshape(pp_z(lam_n(:), sA_n(:), sH_n(:)), n_shock, NC, NP);
        CE     = W_g .* z_n;
        V_n    = CE .^ one_m_g / one_m_g;
        EV     = reshape(sum(w_join .* V_n, 1), NC, NP);   % NC x NP
        rhs    = u_now + beta_eff * EV;                     % u_now (NC x 1) broadcasts
        if beq_eff > 0
            if is_owner
                beq_base = X_next + H_next_W;
            else
                beq_base = X_next;
            end
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
            if choose_tau
                rhs_g = rhs;   % kept for multi-basin polish starts below
            end
        end
    end

    if choose_tau
        % Free-tau polish: best of three candidates (each may fail; grid max
        % is the fallback).
        %   A) 3-var (c, pi, tau) fmincon from the global grid best. The
        %      interior-point barrier keeps tau strictly inside (0,1), so
        %      when the optimum sits ON a tau bound (e.g. tau*=0 in
        %      retirement) this candidate alone under-performs by up to
        %      ~0.3% CEV -- hence the pinned candidates below.
        %   B) 2-var (c, pi) fmincon with tau PINNED at the best grid tau.
        %   C) 2-var (c, pi) fmincon with tau PINNED at the glide value,
        %      from the glide slice's best grid point -- exactly replicates
        %      the glide regime's polish, so the free value can never fall
        %      below the glide value for the same continuation (the
        %      dominance anchor). Skipped when identical to B.
        obj3 = @(x) -bellman_rhs_z3(x(1), x(2), x(3), LW_W, Rf_at, R_S_at, ...
                                     p.Rf, R_S, pt, A_next_pre_return, ...
                                     H_next_W, Y_next_W, ...
                                     w_join, pp_z, one_m_g, beta_eff, beq_eff, is_owner);
        V_polish = -inf; x_opt = [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)];
        try
            [x_try, neg_V_try, exitflag] = fmincon(obj3, ...
                [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)], ...
                [], [], [], [], [c_floor; 0; 0], [1 - 1e-6; 1; 1], [], opts_polish);
            if (exitflag > 0 || exitflag == 0) && -neg_V_try > V_polish
                V_polish = -neg_V_try;
                x_opt    = x_try;
            end
        catch
        end

        pin_tau    = tau_grid(it_max);
        pin_starts = [c_grid(ic_max), pi_grid(ip_max), pin_tau];
        if it_max ~= j_glide && isfinite(maxval_g)
            pin_starts = [pin_starts; c_grid(ic_g), pi_grid(ip_g), tau];
        end
        % Track the best glide-pinned candidate so the derivative-free
        % refinement below can start from it.
        v_gl = maxval_g; c_gl = c_grid(ic_g); p_gl = pi_grid(ip_g);
        % The rhs surface is multimodal in c, and the polish basin reached
        % from a single argmax start shifts with small continuation changes
        % (the glide solve's continuation differs from ours). Anchor against
        % every basin the glide step could polish into: pin tau at the glide
        % value and also start from the top interior local maxima of the
        % glide slice's rhs surface (4-neighbour test, up to 2 beyond the
        % argmax).
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
            obj2 = @(x) -bellman_rhs_z3(x(1), x(2), tau_fix, LW_W, Rf_at, R_S_at, ...
                                         p.Rf, R_S, pt, A_next_pre_return, ...
                                         H_next_W, Y_next_W, ...
                                         w_join, pp_z, one_m_g, beta_eff, beq_eff, is_owner);
            try
                [x_try, neg_V_try, exitflag] = fmincon(obj2, pin_starts(s, 1:2).', ...
                    [], [], [], [], [c_floor; 0], [1 - 1e-6; 1], [], opts_polish);
                if exitflag > 0 || exitflag == 0
                    if -neg_V_try > V_polish
                        V_polish = -neg_V_try;
                        x_opt    = [x_try; tau_fix];
                    end
                    if tau_fix == tau && -neg_V_try > v_gl
                        v_gl = -neg_V_try; c_gl = x_try(1); p_gl = x_try(2);
                    end
                end
            catch
            end
        end

        % Derivative-free local refinement: the coarse-grid z-interpolant
        % puts narrow kink ridges in the rhs surface, and fmincon's finite
        % differences step straight over them (it can even walk OFF such a
        % ridge when started on it). A shrinking-radius local grid scan is
        % ridge-proof. Refine (a) pinned at the glide tau from the best
        % glide-pinned candidate -- this is the dominance anchor, since the
        % glide regime's own fmincon can land on these ridges -- and (b)
        % pinned at the current best tau from the current best point.
        dc0 = c_grid(2) - c_grid(1);
        dp0 = pi_grid(min(2, NP)) - pi_grid(1);
        if isfinite(v_gl)
            [c_r, p_r, v_r] = refine_cpi(c_gl, p_gl, tau, v_gl, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, is_owner, c_floor, dc0, dp0);
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
            w_join, pp_z, one_m_g, beta_eff, beq_eff, is_owner, c_floor, dc0, dp0);
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
        x0 = [c_grid(ic_max); pi_grid(ip_max)];
        lb = [c_floor; 0];
        ub = [1 - 1e-6; 1];
        polish_obj = @(x) -bellman_rhs_z(x(1), x(2), LW_W, Rf_at, R_S_at, ...
                                          A_next_W, H_next_W, Y_next_W, ...
                                          w_join, pp_z, one_m_g, beta_eff, beq_eff, is_owner);

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
                                  w, pp_z, one_m_g, beta_eff, beq_eff, is_owner)
    % R_S_at/Rf_at are after-tax returns, precomputed once by the caller.
    R_X      = (1 - pi_eq) * Rf_at + pi_eq .* R_S_at;
    X_next_W = R_X * (1 - c) * LW_W;
    W_growth = X_next_W + A_next_W + H_next_W + Y_next_W;
    lam_next = max(min(Y_next_W ./ W_growth, 1), 0);
    sA_next  = max(min(A_next_W ./ W_growth, 1), 0);
    sH_next  = max(min(H_next_W ./ W_growth, 1), 0);
    z_n      = pp_z(lam_next, sA_next, sH_next);
    CE_n     = W_growth .* z_n;
    V_n      = CE_n .^ one_m_g / one_m_g;
    EV       = sum(w .* V_n);
    u_now    = (c * LW_W) ^ one_m_g / one_m_g;
    rhs_val  = u_now + beta_eff * EV;
    if beq_eff > 0
        if is_owner
            beq_base = X_next_W + H_next_W;
        else
            beq_base = X_next_W;
        end
        beq_n   = beq_base .^ one_m_g / one_m_g;
        E_beq   = sum(w .* beq_n);
        rhs_val = rhs_val + beq_eff * E_beq;
    end
end

function [c_b, p_b, v_b] = refine_cpi(c0, p0, tau_fix, v0, LW_W, Rf_at, R_S_at, Rf, R_S, pt, ...
                                       A_next_pre_return, H_next_W, Y_next_W, ...
                                       w, pp_z, one_m_g, beta_eff, beq_eff, is_owner, ...
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
        z_n    = reshape(pp_z(lam_n(:), sA_n(:), sH_n(:)), n_shock, M);
        V_n    = (W_g .* z_n) .^ one_m_g / one_m_g;
        rhs    = (cv.' * LW_W) .^ one_m_g / one_m_g + beta_eff * (w.' * V_n).';
        if beq_eff > 0
            if is_owner
                beq_base = X_next + H_next_W;
            else
                beq_base = X_next;
            end
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
                                   w, pp_z, one_m_g, beta_eff, beq_eff, is_owner)
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
    z_n      = pp_z(lam_next, sA_next, sH_next);
    CE_n     = W_growth .* z_n;
    V_n      = CE_n .^ one_m_g / one_m_g;
    EV       = sum(w .* V_n);
    u_now    = (c * LW_W) ^ one_m_g / one_m_g;
    rhs_val  = u_now + beta_eff * EV;
    if beq_eff > 0
        if is_owner
            beq_base = X_next_W + H_next_W;
        else
            beq_base = X_next_W;
        end
        beq_n   = beq_base .^ one_m_g / one_m_g;
        E_beq   = sum(w .* beq_n);
        rhs_val = rhs_val + beq_eff * E_beq;
    end
end

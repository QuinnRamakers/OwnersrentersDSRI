function [V_t, c_pol, pi_pol, feas] = bellman_step(t, V_next, p, profile, shocks, ann_price)
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
%   R_A = ((1 - tau_S(t))*Rf + tau_S(t)*R_S) / p_t   (survival-credit return)
%
%   Bequest base (paid at death; weighted by beta*(1-p_t)*chi):
%     Renter: X_next       (A is annuitised -- not bequeathable)
%     Owner:  X_next + H_next
%
%   Choices (c, pi): consumption fraction and equity share. tau_S is fixed
%   (glide path). 41x41 grid search + fmincon polish; z-transform on V_next.

NL = p.N_lambda; NA = p.N_sA; NH = p.N_sH;
V_t    = nan(NL, NA, NH);
c_pol  = nan(NL, NA, NH);
pi_pol = nan(NL, NA, NH);

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
tau_inc = 0; if isfield(p,'tau_inc'),      tau_inc = p.tau_inc;      end
tau_b   = 0; if isfield(p,'tau_cg_bond'),  tau_b   = p.tau_cg_bond;  end
tau_s   = 0; if isfield(p,'tau_cg_stock'), tau_s   = p.tau_cg_stock; end
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
R_A    = ((1 - tau) * p.Rf + tau * R_S) / pt;     % survival-credit DC return (PRE-TAX, sheltered)

% After-tax returns on the LIQUID (taxable) account: accrual CGT, no loss
% offset. Bonds pay tax on the (always positive) interest; stocks pay tax
% only on positive gains. Still strictly positive and linear in X, so the
% homothetic z-transform machinery is unchanged.
Rf_at  = 1 + p.r * (1 - tau_b);                   % bond leg, after tax
R_S_at = R_S - tau_s .* max(R_S - 1, 0);          % stock leg, after tax (no loss offset)

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
        V_flat(k) = -1e15; c_flat(k) = 1e-6; pi_flat(k) = 0;
        continue
    end

    A_next_W = R_A * A_next_pre_return;      % n_shock x 1
    H_next_W = sH * R_H;                     % n_shock x 1
    Y_next_W = G_next * lam;                 % n_shock x 1

    % Scale-aware c lower bound
    c_floor = max(1e-3, 0.01 / LW_W);
    c_floor = min(c_floor, 0.5);
    c_grid  = linspace(c_floor, 1 - 1e-6, NC).';
    u_now   = (c_grid * LW_W) .^ one_m_g / one_m_g;

    % Batched grid search: one griddedInterpolant call over the full
    % (shock x c x pi) tensor rather than NC*NP separate calls, using the
    % factorisation X_{t+1}/W = R_X(pi) * [(1-c)*LW_W].
    base_W = A_next_W + H_next_W + Y_next_W;          % n_shock x 1
    sav    = (1 - c_grid).' * LW_W;                   % 1 x NC (saved liquid wealth)
    RX     = reshape(R_X_all.', n_shock, 1, NP);      % n_shock x 1 x NP
    X_next = RX .* sav;                               % n_shock x NC x NP
    W_g    = X_next + base_W;                          % n_shock x NC x NP
    lam_n  = max(min(Y_next_W ./ W_g, 1), 0);
    sA_n   = max(min(A_next_W ./ W_g, 1), 0);
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

    [maxval, lin_idx] = max(rhs(:));
    [ic_max, ip_max]  = ind2sub([NC, NP], lin_idx);

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
end

V_t(feas_lin)    = V_flat;
c_pol(feas_lin)  = c_flat;
pi_pol(feas_lin) = pi_flat;
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

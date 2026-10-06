function [V_t, c_pol, pi_pol] = bellman_step_lna(t, V_next, p, profile, shocks, ann_price, pol_next)
%Solves one period

%storage construction
N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid);
V_t    = nan(N1, N2, N3);
c_pol  = nan(N1, N2, N3);
pi_pol = nan(N1, N2, N3);

%grid constructiones
[U1, U2, U3] = ndgrid(p.u1_grid, p.u2_grid, p.u3_grid);
Lam_all = U1;
SA_all  = U2 .* (1 - U1) .* U3;
SH_all  = U2 .* (1 - U1) .* (1 - U3);

%common constants
gamma   = p.gamma;
one_m_g = 1 - gamma;
inv_omg = 1 / one_m_g;

is_owner   = p.is_owner;
is_retired = (t >= p.t_ret);

if nargin < 7, pol_next = []; end

% Tax rates
tau_inc = 0; if isfield(p,'tau_inc'),      tau_inc = p.tau_inc;      end
tau_b   = 0; if isfield(p,'tau_cg_bond'),  tau_b   = p.tau_cg_bond;  end
tau_s   = 0; if isfield(p,'tau_cg_stock'), tau_s   = p.tau_cg_stock; end
tau_w   = 0; if isfield(p,'tau_wealth'),   tau_w   = p.tau_wealth;   end
net_inc = 1 - tau_inc;

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

% Effective DC contribution rate at this age 
kappa_t = p.kappa(min(t, numel(p.kappa)));

% Bequeathed housing value
sell_cost = 0; if isfield(p, 'sell_cost'), sell_cost = p.sell_cost; end
h_beq_fac = is_owner * (1 - sell_cost);

% Consumption floor 
phi_floor = 0; if isfield(p, 'phi_floor'), phi_floor = p.phi_floor; end
use_floor = phi_floor > 0;
FLOOR_EPS = 1e-12;

% Take home fraction
if is_retired
    contrib_factor = (1 - p.delta) * net_inc;                 % AOW, taxed as income
else
    contrib_factor = (1 - p.delta) * (1 - kappa_t) * net_inc; % deductible contrib; rest taxed
end

% Terminal period: no continuation, consume all liquid wealth 
if t == p.T
    chi_T = 0; if isfield(p, 'chi'), chi_T = p.chi; end

    for k = 1:numel(Lam_all)
        lam = Lam_all(k); sA = SA_all(k); sH = SH_all(k);
        sX  = 1 - lam - sA - sH;
        %update wealth
        if is_retired
            LW_W = sX + contrib_factor * lam + net_inc * sA / ann_price(t) ...
                    - h_cost_rate * sH;
        else
            LW_W = sX + contrib_factor * lam - h_cost_rate * sH;
        end
        %floor check
        if use_floor
            LW_W = max(LW_W, max(phi_floor * lam, FLOOR_EPS));
        elseif LW_W <= 1e-12
            V_t(k)    = -1e15;
            c_pol(k)  = 1e-6;
            pi_pol(k) = 0;
            continue
        end
        beq_H = h_beq_fac * sH;
        %bequest check for decision
        if chi_T <= 0
            c_star = 1;
            V_t(k) = (c_star * LW_W)^one_m_g / one_m_g;
        else
            %should this be replaced by full bequest? Not used now 
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

% Continuation value helper values
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
mu_g   = profile.mu_growth(t);
sig_l  = profile.sigma_l_log(t);
G_next = exp(mu_g + sig_l .* eps_Y);

% Rate of returns DC account per realisation
Rf = p.Rf;
R_A_glide = ((1 - tau) * Rf + tau * R_S) / pt;

% After-tax returns on the liquid account
Rf_at  = (1 + p.r * (1 - tau_b)) * (1 - tau_w);            % bond leg
R_S_at = (R_S - tau_s .* max(R_S - 1, 0)) .* (1 - tau_w);  % stock leg

% Transform of continuation vlaue with clamping at the grid end
arg = one_m_g * V_next; arg(arg <= 0) = NaN;
z_next = arg .^ inv_omg;
z_finite = z_next(isfinite(z_next));
if isempty(z_finite)
    error('bellman_step_lna:no_finite_z', 'No finite z values at t=%d', t);
end
z_next(isnan(z_next)) = min(z_finite);
pp_z = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                          z_next, 'linear', 'nearest');

% Scale the objective function by next period
absV = abs(V_next(isfinite(V_next) & V_next ~= 0));
obj_scale = 1;
if ~isempty(absV)
    obj_scale = 1 / median(absV);
    if ~isfinite(obj_scale) || obj_scale <= 0, obj_scale = 1; end
end

%fmincon config
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

lam_pts = Lam_all(:);
sA_pts  = SA_all(:);
sH_pts  = SH_all(:);

% construct initial guesses for warm start
have_warm = ~isempty(pol_next) && isstruct(pol_next) ...
            && isfield(pol_next, 'c') && isequal(size(pol_next.c), [N1 N2 N3]);
if have_warm
    cw_pts = pol_next.c(:);
    pw_pts = pol_next.pi(:);
else
    cw_pts = nan(n_states, 1);
    pw_pts = nan(n_states, 1);
end

% Annuity payout rate
if is_retired
    ann_t      = ann_price(t);
    A_keep_fac = 1 - 1/ann_t;             % A_next_pre / s_A
else
    ann_t      = 1;
    A_keep_fac = 1;
end

%optimise per state
parfor k = 1:n_states
    %set liquid wealth and gueeses
    lam = lam_pts(k); sA = sA_pts(k); sH = sH_pts(k);
    sX  = 1 - lam - sA - sH;
    c_warm = cw_pts(k); pi_warm = pw_pts(k);   % t+1 policy at this node (warm seed)

    %update savings with income
    if is_retired
        LW_W              = sX + contrib_factor * lam + net_inc * sA / ann_t ...
                                - h_cost_rate * sH;
        A_next_pre_return = sA * A_keep_fac;
    else
        LW_W              = sX + contrib_factor * lam - h_cost_rate * sH;
        A_next_pre_return = sA + kappa_t * lam;
    end
    % continuatiuon coordinates
    A_next_W = R_A_glide * A_next_pre_return;   % n_shock x 1 (glide DC position)
    H_next_W = sH * R_H;                        % n_shock x 1
    Y_next_W = G_next * lam;                    % n_shock x 1
    F_W      = max(phi_floor * lam, FLOOR_EPS); % consumption floor, share of W


    % Ruin / floor handling: not enough resources so gets punished with low
    % values
    if ~use_floor
        if LW_W <= 1e-9
            V_flat(k) = -1e15; c_flat(k) = 1e-6; pi_flat(k) = 0;
            continue
        end
    elseif LW_W <= F_W
        % At very low resources consume the minimal consumption level and
        % calculate the utility based on this(alternative to setting ruin
        % values)
        u_f  = F_W ^ one_m_g / one_m_g;
        W_g0 = A_next_W + H_next_W + Y_next_W;
        u1_0 = max(min(Y_next_W ./ W_g0, 1), 0);
        u2_0 = max(min((A_next_W + H_next_W) ./ max(A_next_W + H_next_W, 1e-12), 1), 0);
        u3_0 = max(min(A_next_W ./ max(A_next_W + H_next_W, 1e-12), 1), 0);
        z_0  = pp_z(u1_0, u2_0, u3_0);
        val  = u_f + beta_eff * sum(w_join .* ((W_g0 .* z_0) .^ one_m_g / one_m_g));
        if beq_eff > 0
            beq_base = max(h_beq_fac * H_next_W, FLOOR_EPS);
            val = val + beq_eff * sum(w_join .* (beq_base .^ one_m_g / one_m_g));
        end
        V_flat(k) = val; c_flat(k) = 1; pi_flat(k) = 0;
        continue
    end

    %setting the consumption rate lower bound based on the floor
    c_floor = max(1e-3, 0.01 / LW_W);
    c_floor = min(c_floor, 0.5);

    % Warm-start with next period value or fallback to 0.5 
    if isfinite(c_warm) && isfinite(pi_warm)
        cand = [min(max(c_warm, c_floor), 1 - 1e-6), min(max(pi_warm, 0), 1)];
    else
        cand = [0.5, 0.5; 0.15, 1.0];
    end
    maxval = -inf; c_seed = cand(1,1); pi_seed = cand(1,2);
    %check if the guesses are actually feasible/ an improvement
    for s = 1:size(cand, 1)
        v = bellman_rhs_z_u(cand(s,1), cand(s,2), LW_W, Rf_at, R_S_at, ...
                A_next_W, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
        if v > maxval, maxval = v; c_seed = cand(s,1); pi_seed = cand(s,2); end
    end

    % start fmincon from the initial guess
    polish_obj = @(x) -obj_scale * bellman_rhs_z_u(x(1), x(2), LW_W, Rf_at, R_S_at, ...
                                        A_next_W, H_next_W, Y_next_W, ...
                                        w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
    lb2 = [c_floor; 0];
    ub2 = [1 - 1e-6; 1];
    V_polish = -inf; x_opt = [c_seed; pi_seed];
    try
        [x_try, neg_V_try, exitflag] = fmincon(polish_obj, [c_seed; pi_seed], ...
            [], [], [], [], lb2, ub2, [], opts_polish);
        if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_polish
            V_polish = -neg_V_try/obj_scale; x_opt = x_try;
        end
    catch
    end

    % fallback if fmincon performs worse than the guess
    if V_polish > maxval
        cb0 = x_opt(1); pb0 = x_opt(2); vb0 = V_polish;
    else
        cb0 = c_seed; pb0 = pi_seed; vb0 = maxval;
    end

    % Check for better nearby solutions, helps for the stock policy

    dc0 = (1 - 1e-6 - c_floor) / 40;
    dp0 = 1 / 40;
    [c_r, p_r, v_r] = refine_cpi_u(cb0, pb0, tau, vb0, LW_W, Rf_at, R_S_at, ...
        Rf, R_S, pt, A_next_pre_return, H_next_W, Y_next_W, ...
        w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0);
    if v_r > vb0, cb0 = c_r; pb0 = p_r; vb0 = v_r; end

    V_flat(k) = vb0; c_flat(k) = cb0; pi_flat(k) = pb0;
end

V_t(:)    = V_flat;
c_pol(:)  = c_flat;
pi_pol(:) = pi_flat;
end

function rhs_val = bellman_rhs_z_u(c, pi_eq, LW_W, Rf_at, R_S_at, A_next_W, H_next_W, Y_next_W, ...
                                    w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac)
    % Calculates utility from consumption and the expected continuation
    % value 
    R_X      = (1 - pi_eq) * Rf_at + pi_eq .* R_S_at;
    X_next_W = R_X * (1 - c) * LW_W;
    denAH    = A_next_W + H_next_W;
    W_growth = X_next_W + denAH + Y_next_W;
    u1_next  = max(min(Y_next_W ./ W_growth, 1), 0);
    u2_next  = max(min(denAH ./ max(X_next_W + denAH, 1e-12), 1), 0);
    u3_next  = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
    z_n      = pp_z(u1_next, u2_next, u3_next);
    V_n      = (W_growth .* z_n) .^ one_m_g / one_m_g;
    EV       = sum(w .* V_n);
    u_now    = (c * LW_W) ^ one_m_g / one_m_g;
    rhs_val  = u_now + beta_eff * EV;
    if beq_eff > 0
        beq_base = X_next_W + h_beq_fac * H_next_W;
        beq_n   = beq_base .^ one_m_g / one_m_g;
        rhs_val = rhs_val + beq_eff * sum(w .* beq_n);
    end
end

function [c_b, p_b, v_b] = refine_cpi_u(c0, p0, tau_fix, v0, LW_W, Rf_at, R_S_at, Rf, R_S, pt, ...
                                         A_next_pre_return, H_next_W, Y_next_W, ...
                                         w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, ...
                                         c_floor, dc0, dp0)
    % Tries to improve upon the initial guess by doing small grid searches
    % around the current solution to see if fmincon can be improved upon
    %simply selects a group of candidate policies and calculates the value
    %of the objective function
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
        cv  = Cm(:).'; pv = Pm(:).';                 
        R_X    = (1 - pv) .* Rf_at + pv .* R_S_at;    
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

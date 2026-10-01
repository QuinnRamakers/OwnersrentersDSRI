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
%
% The first axis need not be lambda itself. p.coord1 (config.coord1) chooses what
% it carries; 'yw' is lambda and is the default and bit-identical. Whatever it
% carries, the budget below is written in wealth shares, so the axis value is
% converted back to lambda here once, at THIS age's coefficients, and nothing
% downstream changes. Going the other way -- next period's shares back onto the
% axis, at NEXT period's coefficients -- is what coord_fwd does at the
% interpolation sites.
[U1, U2, U3] = ndgrid(p.u1_grid, p.u2_grid, p.u3_grid);
cnow    = config.coord1(p, t, ann_price);
cnext   = config.coord1(p, min(t + 1, p.T), ann_price);
Lam_all = cnow.inv(U1, U2, U3);
SA_all  = U2 .* (1 - Lam_all) .* U3;
SH_all  = U2 .* (1 - Lam_all) .* (1 - U3);

%storage of common calculations
gamma   = p.gamma;
one_m_g = 1 - gamma;
inv_omg = 1 / one_m_g;

% set booleans for type and working status
is_owner   = p.is_owner;
is_retired = (t >= p.t_ret);

% skip_polish BYPASSES the per-node optimiser (below) and returns the seed
% unchanged. It is a functionality smoke-test switch ONLY: with grid_mode='none'
% the seed is next period's policy, so skipping the optimiser freezes pi at the
% terminal all-bond value at every node -- the resulting policies, simulations,
% welfare and dashboards are INVALID. Never set it for a run whose output is
% read; solver.solve_lifecycle_lna warns when it is on. Default false.
skip_polish = false; if isfield(p, 'skip_polish'), skip_polish = logical(p.skip_polish); end

% Per-node optimiser. The household's (c, pi) [and tau under free DC choice]
% problem at each state is solved by fmincon -- this IS the optimisation, not a
% cosmetic polish -- started from a seed, then a derivative-free refinement
% (refine_cpi_u) that clears the interpolation-kink ridges fmincon's finite
% differences step over. The seed depends on grid_mode:
%   grid_mode = 'none'  seed = the warm start (next period's policy at this
%                       node); fmincon optimises from there. The default and
%                       faster; requires polish_ver >= 2. (skip_tensor path)
%   grid_mode = 'full'  seed = the argmax of an NC x NP (c, pi) grid search.
%                       (legacy; free DC choice still uses this path.)
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
% DC REIT share at this age (config.reit_effective; 0 when the REIT is off).
reit_eff_path = config.reit_effective(p);
tau_R    = reit_eff_path(t);
pt       = profile.p_surv(t);
beta_eff = p.beta * pt;
chi = 0; if isfield(p, 'chi'), chi = p.chi; end
beq_eff = p.beta * (1 - pt) * chi;

R_S    = shocks.joint.R_S(:);
eps_Y  = shocks.joint.eps_Y_unit(:);
R_H    = shocks.joint.R_H(:);
R_REIT = shocks.joint.R_REIT(:);         % DC REIT leg (unit vector when off)
w_join = shocks.joint.w(:);
n_shock = numel(w_join);
mu_g   = profile.mu_growth(t);
sig_l  = profile.sigma_l_log(t);
G_next = exp(mu_g + sig_l .* eps_Y);
% Candidate pension equity shares. With no choice this defaults to the assigned strategy, with free choice it creates a grid to search
if optimise_tau
    % Free stock share, capped at 1 - tau_R so the bond leg stays non-negative
    % alongside the fixed REIT carve-out.
    NT = 11; if isfield(p, 'N_tau'), NT = p.N_tau; end
    tau_grid = unique([linspace(0, max(1 - tau_R, 0), NT).'; tau]);
else
    tau_grid = tau;
end
NTg     = numel(tau_grid);
j_glide = find(tau_grid == tau, 1);
% Survival-credit DC return per shock realisation and tau slice: three legs,
% (1-tau-tau_R) in bonds, tau in stock, tau_R in the REIT (PRE-TAX, sheltered).
R_A_all = ((1 - tau_grid.' - tau_R) * p.Rf + R_S * tau_grid.' + R_REIT * tau_R) / pt;

% After-tax returns on the liquid account
% (stocks taxed only on gains), then the wealth tax on the end-of-period balance.
Rf_at  = (1 + p.r * (1 - tau_b)) * (1 - tau_w);            % bond leg
R_S_at = config.after_tax_stock(p, R_S);                   % stock leg

% Transform of the continuitions to the inverse
arg = one_m_g * V_next; arg(arg <= 0) = NaN;
z_next = arg .^ inv_omg;
z_finite = z_next(isfinite(z_next));
if isempty(z_finite)
    error('bellman_step_lna:no_finite_z', 'No finite z values at t=%d', t);
end
z_min = min(z_finite);
z_next(isnan(z_next)) = z_min;
% Linear inside, gets clamped to the space if a value is outside the grid.
%
% p.interp_space picks what the rule is linear IN. 'z' (default, and what every
% solve before this option used) interpolates the certainty equivalent itself.
% 'logz' interpolates its logarithm, i.e. geometric rather than arithmetic
% between nodes. Both leave the node values untouched; they differ only between
% nodes, and they differ most where z spans orders of magnitude inside one cell,
% which is what the consumption floor does near the ruin region.
% p.interp_method picks the STRUCTURE, which is a separate choice from the
% transform. 'linear' (default) is shape-preserving: a value between two nodes
% can never leave their range, which matters next to the ruin region where one
% corner of a cell can be orders of magnitude below the others. 'makima' and
% 'spline' are smoother and more accurate where the function is smooth, but they
% can overshoot; makima is built to suppress that, spline is not. Extrapolation
% stays 'nearest' in every case, so nothing runs away outside the grid.
interp_space = 'z';
if isfield(p, 'interp_space') && ~isempty(p.interp_space)
    interp_space = validatestring(p.interp_space, {'z', 'logz'}, ...
                                  'bellman_step_lna', 'p.interp_space');
end
interp_method = 'linear';
if isfield(p, 'interp_method') && ~isempty(p.interp_method)
    % 'cubic' is deliberately not offered. config.insert_anchor_nodes splices
    % the welfare anchors into u1 and u2, so the grid is not uniformly spaced,
    % and griddedInterpolant silently downgrades 'cubic' to 'spline' in that
    % case -- asking for one method and getting another.
    interp_method = validatestring(p.interp_method, ...
                                   {'linear', 'makima', 'spline'}, ...
                                   'bellman_step_lna', 'p.interp_method');
end
% p.interp_object picks WHAT is interpolated, which is a choice prior to both of
% the above. 'z' (default, and what every solve before this used) interpolates
% the certainty equivalent directly. 'kappa' factors the known singularity out
% first. Next period's liquid resources per unit of wealth,
%     m(u1,u2,u3) = s_X + cf*lambda + ann*s_A - hc*s_H,
% are an exact affine function of the cube coordinates, and CRRA forces
% z -> m as m -> 0: at zero resources the household consumes zero, u(0)
% dominates the finite continuation, and the certainty equivalent collapses
% onto current resources. So z = kappa * m with kappa in (0, 1] smooth and
% bounded, while z itself carries the collapse. Interpolating kappa and
% multiplying by an exactly evaluated m puts the ruin surface m = 0 where the
% budget says it is, rather than wherever the cell containing it happens to
% interpolate to, and keeps the interpolated object O(1) everywhere.
%
% p.interp_space applies to the 'z' object only; kappa has no logarithmic
% variant because it does not span orders of magnitude.
interp_object = 'z';
if isfield(p, 'interp_object') && ~isempty(p.interp_object)
    interp_object = validatestring(p.interp_object, {'z', 'kappa'}, ...
                                   'bellman_step_lna', 'p.interp_object');
end
if strcmp(interp_object, 'kappa')
    [cf_n, hc_n, ann_n] = budget_coeffs(p, min(t + 1, p.T), ann_price, net_inc);
    % Written in lambda, then composed with the chart's inverse so that it takes
    % AXIS coordinates like the interpolant it multiplies. Under 'yw' the inverse
    % is the identity and this is the expression that was here before.
    m_of_lam = @(l, b, c) (1 - l) .* (1 - b) + cf_n * l ...
                          + ann_n * (b .* (1 - l) .* c) ...
                          - hc_n  * (b .* (1 - l) .* (1 - c));
    m_of_u  = @(a, b, c) m_of_lam(cnext.inv(a, b, c), b, c);
    LAM_n   = cnext.inv(U1, U2, U3);
    M_nodes = m_of_lam(LAM_n, U2, U3);
    F_nodes = max(phi_floor * LAM_n, FLOOR_EPS);
    % A node at or below the floor is in the other regime -- the state tops the
    % household up and it saves nothing -- so z there is the floor rather than a
    % multiple of its own resources, and kappa would be F/m, unbounded as m
    % falls. Those nodes are excluded and keep kappa = 1, the m -> 0 limit, so a
    % cell straddling the boundary blends toward the right asymptote instead of
    % toward a value belonging to the other regime. The floor itself comes back
    % through the clamp below.
    live = M_nodes > F_nodes & isfinite(z_next);
    assert(any(live(:)), 'bellman_step_lna:no_live_m', ...
        'No node is above the consumption floor at t=%d.', t);
    k_nodes = ones(size(z_next));
    k_nodes(live) = z_next(live) ./ M_nodes(live);
    % kappa <= 1 wherever the household funds itself, since the certainty
    % equivalent of a whole remaining lifetime cannot exceed what one period of
    % it consumes. The clamp is read off the grid rather than imposed at 1.
    k_hi = max(1, max(k_nodes(live)));
    k_nodes = min(max(k_nodes, 0), k_hi);
    pp_k = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                              k_nodes, interp_method, 'nearest');
    pp_z = @(a, b, c) max(min(max(pp_k(a, b, c), 0), k_hi) ...
                          .* max(m_of_u(a, b, c), 0), ...
                          max(phi_floor * cnext.inv(a, b, c), FLOOR_EPS));
else
    switch interp_space
        case 'logz'
            pp_log = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                                        log(max(z_next, realmin)), ...
                                        interp_method, 'nearest');
            pp_z = @(a, b, c) exp(pp_log(a, b, c));
        otherwise
            pp_lin = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                                        z_next, interp_method, 'nearest');
            if strcmp(interp_method, 'linear')
                pp_z = pp_lin;              % untouched: the original object
            else
                % A smooth scheme can undershoot past zero next to the cliff, and a
                % negative z is not a certainty equivalent. Clamp to the smallest
                % value the solved grid actually carries.
                pp_z = @(a, b, c) max(pp_lin(a, b, c), z_min);
            end
    end
end

% Everything built above indexes the FIRST AXIS, whatever p.coord1 put there.
% Every call site downstream computes next period's state as lambda = Y'/W', the
% budget quantity, and none of them needs to know what the axis carries. One
% wrapper reconciles the two: take lambda in, put it on the axis, then
% interpolate. Under 'yw' the map is the identity and pp_z is handed through
% untouched, so the default path stays bit-identical.
if ~strcmp(cnext.mode, 'yw')
    pp_axis = pp_z;
    pp_z    = @(lam, b, c) pp_axis(cnext.fwd(lam, b, c), b, c);
end

% Scale the fmincon objective by a summary of next period's value magnitudes.
% One scalar serves the whole step, but |V| varies by orders of magnitude across
% the state space, so the scale is right for a typical node and wrong for an
% extreme one. p.obj_scale_mode exposes the summary for testing whether that
% matters: 'median' (default, and what every solve before this used), 'min',
% 'max', or 'none'.
obj_scale = 1;
if use_scaling
    absV = abs(V_next(isfinite(V_next) & V_next ~= 0));
    if ~isempty(absV)
        mode_s = 'median';
        if isfield(p, 'obj_scale_mode') && ~isempty(p.obj_scale_mode)
            mode_s = char(p.obj_scale_mode);
        end
        switch mode_s
            case 'median', ref = median(absV);
            case 'min',    ref = min(absV);
            case 'max',    ref = max(absV);
            case 'none',   ref = 1;
            otherwise
                error('bellman_step_lna:obj_scale_mode', ...
                    'p.obj_scale_mode must be median, min, max or none (got %s).', mode_s);
        end
        obj_scale = 1 / ref;
        if ~isfinite(obj_scale) || obj_scale <= 0, obj_scale = 1; end
    end
end

% Grid of consumption and equity-share candidates that seeds the search. (legacy optimisation)
NC = 41; if isfield(p, 'N_c'),  NC = p.N_c;  end
NP = 41; if isfield(p, 'N_pi'), NP = p.N_pi; end
pi_grid = linspace(0, 1, NP).';
R_X_all = (1 - pi_grid) * Rf_at + pi_grid * R_S_at.';     % NP x n_shock (after-tax)

%fmincon settings. active-set reaches the same optimum as interior-point on the
% flat (c, pi) objective but with a smoother policy across neighbouring states --
% the interior-point barrier gives a noisy argmax here -- and less runtime.
% p.polish_algo overrides the algorithm (default 'active-set') for solver
% comparisons; p.use_refine toggles the derivative-free refinement below.
polish_algo = 'active-set';
if isfield(p, 'polish_algo') && ~isempty(p.polish_algo), polish_algo = char(p.polish_algo); end
use_refine = true;
if isfield(p, 'use_refine'), use_refine = logical(p.use_refine); end
opts_opt = optimoptions('fmincon', ...
    'Algorithm', polish_algo, ...
    'Display', 'off', ...
    'OptimalityTolerance', 1e-8, ...
    'StepTolerance', 1e-9, ...
    'FunctionTolerance', 1e-10, ...
    'MaxIterations', 200, ...
    'MaxFunctionEvaluations', 500, ...
    'FiniteDifferenceType', 'central');
% p.fd_step widens fmincon's finite-difference step. The default (~1.5e-8)
% samples inside a single cell of the piecewise-linear continuation
% interpolant, so the slope it sees carries no information about the next
% cell; a step of the order of the grid spacing makes the difference a
% secant across cells instead. Unset leaves MATLAB's default.
if isfield(p, 'fd_step') && ~isempty(p.fd_step)
    opts_opt = optimoptions(opts_opt, 'FiniteDifferenceStepSize', p.fd_step);
end
% p.pi_starts adds extra equity-share seeds, each run as its own fmincon from
% the same consumption seed. Empty keeps the single-start behaviour.
pi_starts = []; if isfield(p, 'pi_starts'), pi_starts = p.pi_starts(:); end
% p.refine_c_global widens the refinement's first round so it sweeps consumption
% across its whole feasible range as well as pi. The shipped refinement sweeps
% pi globally but keeps c within one grid cell of the seed, so a node whose seed
% carries a bad c is never reached. Default false keeps the shipped behaviour.
refine_c_global = false;
if isfield(p, 'refine_c_global'), refine_c_global = logical(p.refine_c_global); end
% p.refine_pi_global mirrors it for the equity share; true is what ships.
refine_pi_global = true;
if isfield(p, 'refine_pi_global'), refine_pi_global = logical(p.refine_pi_global); end
% p.refine_stage decides whether the sweep runs after fmincon ('post', the
% shipped order) or before it, to choose fmincon's seed ('pre'). The sweep is
% what locates the basin, so running it first lets fmincon converge inside the
% right one instead of being corrected afterwards.
refine_stage = 'post';
if isfield(p, 'refine_stage') && ~isempty(p.refine_stage)
    refine_stage = char(p.refine_stage);
end
refine_pre  = strcmp(refine_stage, 'pre');
refine_post = ~refine_pre;

n_states = numel(Lam_all);
% Diagnostic scan selection (see the dump below). scan_node is a plain logical
% so the parfor body only tests an index.
scan_on = isfield(p, 'scan') && ~isempty(p.scan) && any(t == p.scan.t);
scan_node = false(n_states, 1);
if scan_on
    nd = p.scan.nodes(:); nd = nd(nd >= 1 & nd <= n_states);
    scan_node(nd) = true;
    if ~isfolder(p.scan.dir), mkdir(p.scan.dir); end
end
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
    % Lower bound on the consumption search. c is the share of liquid resources
    % consumed, so 0.01/LW_W is "consume at least 1% of total wealth W". It
    % exists to keep the optimiser off c = 0, but where the household would
    % rather consume less than that -- which is the whole of early life at this
    % calibration -- it is the bound, not the household, that sets consumption.
    % p.c_floor_frac exposes it so that can be measured. Default 0.01, bitwise
    % what every solve before this used.
    cff = 0.01; if isfield(p, 'c_floor_frac'), cff = p.c_floor_frac; end
    c_floor = max(1e-3, cff / LW_W);
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
        obj3 = @(x) -obj_scale * bellman_rhs_z3_u(x(1), x(2), x(3), tau_R, LW_W, Rf_at, R_S_at, ...
                                       p.Rf, R_S, R_REIT, pt, A_next_pre_return, ...
                                       H_next_W, Y_next_W, ...
                                       w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
        V_opt = -inf; x_opt = [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)];
        try
            [x_try, neg_V_try, exitflag] = fmincon(obj3, ...
                [c_grid(ic_max); pi_grid(ip_max); tau_grid(it_max)], ...
                [], [], [], [], [c_floor; 0; 0], [1 - 1e-6; 1; max(1 - tau_R, 0)], [], opts_opt);
            if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_opt
                V_opt = -neg_V_try/obj_scale; x_opt = x_try;
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
            obj2 = @(x) -obj_scale * bellman_rhs_z3_u(x(1), x(2), tau_fix, tau_R, LW_W, Rf_at, R_S_at, ...
                                           p.Rf, R_S, R_REIT, pt, A_next_pre_return, ...
                                           H_next_W, Y_next_W, ...
                                           w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);
            try
                [x_try, neg_V_try, exitflag] = fmincon(obj2, pin_starts(s, 1:2).', ...
                    [], [], [], [], lb2, ub2, [], opts_opt);
                if exitflag > 0 || exitflag == 0
                    if -neg_V_try/obj_scale > V_opt
                        V_opt = -neg_V_try/obj_scale; x_opt = [x_try; tau_fix];
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
        if use_refine && isfinite(v_gl)
            [c_r, p_r, v_r] = refine_cpi_u(c_gl, p_gl, tau, tau_R, v_gl, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, R_REIT, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0, refine_c_global, refine_pi_global);
            if v_r > V_opt, V_opt = v_r; x_opt = [c_r; p_r; tau]; end
        end
        if V_opt > maxval
            cb0 = x_opt(1); pb0 = x_opt(2); tb0 = x_opt(3); vb0 = V_opt;
        else
            cb0 = c_grid(ic_max); pb0 = pi_grid(ip_max); tb0 = tau_grid(it_max); vb0 = maxval;
        end
        if use_refine
            [c_r, p_r, v_r] = refine_cpi_u(cb0, pb0, tb0, tau_R, vb0, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, R_REIT, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0, refine_c_global, refine_pi_global);
            if v_r > V_opt, V_opt = v_r; x_opt = [c_r; p_r; tb0]; end
        end

        if V_opt > maxval
            V_flat(k) = V_opt; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2); tau_flat(k) = x_opt(3);
        else
            V_flat(k) = maxval; c_flat(k) = c_grid(ic_max); pi_flat(k) = pi_grid(ip_max);
            tau_flat(k) = tau_grid(it_max);
        end
    else
        A_next_W = R_A_all(:, 1) * A_next_pre_return;   % glide-slice DC position
        obj_cpi = @(x) -obj_scale * bellman_rhs_z_u(x(1), x(2), LW_W, Rf_at, R_S_at, ...
                                            A_next_W, H_next_W, Y_next_W, ...
                                            w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac);

        % Sweep first, when asked: the seed fmincon gets is then the best point
        % of the sweep rather than the warm start, so the local solve runs
        % inside the right basin instead of being corrected after the fact.
        if use_scaling && use_refine && refine_pre
            dc0p = c_grid(2) - c_grid(1);
            dp0p = pi_grid(min(2, NP)) - pi_grid(1);
            [c_pre, p_pre, v_pre] = refine_cpi_u(c_seed, pi_seed, tau, tau_R, maxval, ...
                LW_W, Rf_at, R_S_at, p.Rf, R_S, R_REIT, pt, A_next_pre_return, ...
                H_next_W, Y_next_W, w_join, pp_z, one_m_g, beta_eff, beq_eff, ...
                h_beq_fac, c_floor, dc0p, dp0p, refine_c_global, refine_pi_global);
            if v_pre > maxval
                maxval = v_pre; c_seed = c_pre; pi_seed = p_pre;
            end
        end

        % Best seed: the tensor argmax, or the warm start when the tensor is off.
        % With the tensor on, add the t+1 policy as a second start.
        starts = [c_seed, pi_seed];
        if ~skip_tensor && isfinite(c_warm) && isfinite(pi_warm)
            starts = [starts; min(max(c_warm, c_floor), 1 - 1e-6), min(max(pi_warm, 0), 1)];
        end
        if ~isempty(pi_starts)
            starts = [starts; repmat(c_seed, numel(pi_starts), 1), pi_starts];
        end
        starts(:,1) = min(max(starts(:,1), c_floor), 1 - 1e-6);
        starts(:,2) = min(max(starts(:,2), 0), 1);

        V_opt = -inf; x_opt = starts(1, :).';
        for s = 1:size(starts, 1)
            try
                [x_try, neg_V_try, exitflag] = fmincon(obj_cpi, starts(s, :).', ...
                    [], [], [], [], lb2, ub2, [], opts_opt);
                if (exitflag > 0 || exitflag == 0) && -neg_V_try/obj_scale > V_opt
                    V_opt = -neg_V_try/obj_scale; x_opt = x_try;
                end
            catch
            end
        end

        % Same derivative-free refinement as the free-tau branch, unless the
        % sweep already ran before fmincon.
        if use_scaling && use_refine && refine_post
            dc0 = c_grid(2) - c_grid(1);
            dp0 = pi_grid(min(2, NP)) - pi_grid(1);
            if V_opt > maxval
                cb0 = x_opt(1); pb0 = x_opt(2); vb0 = V_opt;
            else
                cb0 = c_seed; pb0 = pi_seed; vb0 = maxval;
            end
            [c_r, p_r, v_r] = refine_cpi_u(cb0, pb0, tau, tau_R, vb0, LW_W, Rf_at, R_S_at, ...
                p.Rf, R_S, R_REIT, pt, A_next_pre_return, H_next_W, Y_next_W, ...
                w_join, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, c_floor, dc0, dp0, refine_c_global, refine_pi_global);
            if v_r > V_opt, V_opt = v_r; x_opt = [c_r; p_r]; end
        end

        % Diagnostic landscape dump. Off unless p.scan is set, and then only at
        % the requested ages and nodes, so the hot loop is untouched otherwise.
        % Records the objective on a dense (c, pi) grid together with the seed,
        % the global grid maximum, and where each optimiser actually lands --
        % enough to see which of them escape the seed's basin.
        if scan_on && scan_node(k)
            % The primitives of the node's budget go with the dump, so the
            % objective can be taken apart afterwards into the current-utility
            % term and the continuation term, and the next-period state each
            % (c, pi) leads to can be recovered exactly rather than rebuilt.
            prim = struct('LW_W', LW_W, 'Rf_at', Rf_at, 'R_S_at', R_S_at, ...
                          'A_next_W', A_next_W, 'H_next_W', H_next_W, ...
                          'Y_next_W', Y_next_W, 'w', w_join, 'one_m_g', one_m_g, ...
                          'beta_eff', beta_eff, 'beq_eff', beq_eff, ...
                          'h_beq_fac', h_beq_fac, 'lam', lam, 'sA', sA, 'sH', sH, 'sX', sX);
            scan_write(fullfile(p.scan.dir, sprintf('scan_t%03d_k%06d.mat', t, k)), ...
                node_scan(obj_cpi, obj_scale, c_floor, lb2, ub2, ...
                          c_seed, pi_seed, x_opt, p.scan, ...
                          c_grid(2) - c_grid(1), pi_grid(min(2,NP)) - pi_grid(1), prim));
        end

        if V_opt > maxval
            V_flat(k) = V_opt; c_flat(k) = x_opt(1); pi_flat(k) = x_opt(2);
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

function rhs_val = bellman_rhs_z3_u(c, pi_eq, tau_dc, tau_R, LW_W, Rf_at, R_S_at, Rf, R_S, R_REIT, pt, ...
                                     A_next_pre_return, H_next_W, Y_next_W, ...
                                     w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac)
    % 3-choice Bellman RHS on the cube: as bellman_rhs_z_u, but the DC position
    % is rebuilt from the choice variable tau_dc plus the fixed REIT share tau_R
    % (survival-credit return, PRE-TAX -- the fund is sheltered; only the liquid
    % legs carry tax).
    R_A      = ((1 - tau_dc - tau_R) * Rf + tau_dc .* R_S + tau_R .* R_REIT) / pt;
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

function Sc = node_scan(obj_cpi, obj_scale, c_floor, lb2, ub2, c_seed, pi_seed, x_opt, scan, dc0, dp0, prim)
%NODE_SCAN  The per-node objective landscape, plus where each optimiser lands.
%   Diagnostic only. rhs = -obj_cpi(x)/obj_scale recovers the Bellman right
%   hand side from the scaled minimisation objective the solver hands fmincon.
%
%   prim, when given, carries the node's budget primitives so the objective can
%   be decomposed afterwards. It is stored and not used here.
if nargin < 12, prim = []; end
cg = linspace(c_floor, 1 - 1e-6, scan.c_n);
pg = linspace(0, 1, scan.pi_n);
Z  = zeros(numel(cg), numel(pg));
for ii = 1:numel(cg)
    for jj = 1:numel(pg)
        Z(ii, jj) = -obj_cpi([cg(ii); pg(jj)]) / obj_scale;
    end
end
[gmax, im] = max(Z(:));
[ig, jg]   = ind2sub(size(Z), im);

% Where each method ends up, all from the same seed the solver used.
algs = {'active-set', 'sqp', 'interior-point'};
land = nan(numel(algs) + 2, 3);            % [c, pi, value]
for m = 1:numel(algs)
    o = optimoptions('fmincon', 'Algorithm', algs{m}, 'Display', 'off', ...
        'OptimalityTolerance', 1e-8, 'StepTolerance', 1e-9, ...
        'FunctionTolerance', 1e-10, 'MaxIterations', 200, ...
        'MaxFunctionEvaluations', 500, 'FiniteDifferenceType', 'central');
    try
        xt = fmincon(obj_cpi, [c_seed; pi_seed], [], [], [], [], lb2, ub2, [], o);
        land(m, :) = [xt(1), xt(2), -obj_cpi(xt)/obj_scale];
    catch
    end
end
% active-set with a grid-scale finite-difference step
o = optimoptions('fmincon', 'Algorithm', 'active-set', 'Display', 'off', ...
    'OptimalityTolerance', 1e-8, 'StepTolerance', 1e-9, ...
    'FunctionTolerance', 1e-10, 'MaxIterations', 200, ...
    'MaxFunctionEvaluations', 500, 'FiniteDifferenceType', 'central', ...
    'FiniteDifferenceStepSize', 1e-2);
try
    xt = fmincon(obj_cpi, [c_seed; pi_seed], [], [], [], [], lb2, ub2, [], o);
    land(numel(algs)+1, :) = [xt(1), xt(2), -obj_cpi(xt)/obj_scale];
catch
end
% multistart over pi, active-set, default step
best = [nan nan -inf];
for ps = linspace(0, 1, 5)
    o = optimoptions('fmincon', 'Algorithm', 'active-set', 'Display', 'off', ...
        'OptimalityTolerance', 1e-8, 'StepTolerance', 1e-9, ...
        'FunctionTolerance', 1e-10, 'MaxIterations', 200, ...
        'MaxFunctionEvaluations', 500, 'FiniteDifferenceType', 'central');
    try
        xt = fmincon(obj_cpi, [c_seed; ps], [], [], [], [], lb2, ub2, [], o);
        vt = -obj_cpi(xt)/obj_scale;
        if vt > best(3), best = [xt(1), xt(2), vt]; end
    catch
    end
end
land(numel(algs)+2, :) = best;

Sc.c = cg; Sc.pi = pg; Sc.rhs = Z;
Sc.prim = prim;
Sc.seed = [c_seed, pi_seed];
Sc.gmax = [cg(ig), pg(jg), gmax];
Sc.solver_opt = [x_opt(1), x_opt(2)];
Sc.methods = [algs, {'active-set FD 1e-2'}, {'pi multistart x5'}];
Sc.land = land;

% The refinement's own trajectory, run on this same objective, so the figure
% shows what it evaluates rather than a description of it. Mirrors
% refine_cpi_u: round 1 sweeps pi across the whole interval, later rounds
% shrink around the incumbent.
% Two traces: the shipped refinement, whose round 1 sweeps pi globally but keeps
% c near the seed, and a variant that sweeps c globally as well. Comparing them
% on the same node shows whether the local c window is what limits it.
Sc.refine    = trace_refine(obj_cpi, obj_scale, c_seed, pi_seed, c_floor, dc0, dp0, false);
Sc.refine_gc = trace_refine(obj_cpi, obj_scale, c_seed, pi_seed, c_floor, dc0, dp0, true);
end

% ------------------------------------------------------------------------
function rc = trace_refine(obj_cpi, obj_scale, c_seed, pi_seed, c_floor, dc0, dp0, c_global)
%TRACE_REFINE  refine_cpi_u's search, recorded round by round.
rc = struct('c',{},'pi',{},'best',{});
cb = c_seed; pb = pi_seed; vb = -obj_cpi([c_seed; pi_seed])/obj_scale;
dc = dc0/4; dp = max(dp0, 0.05);
for r = 1:4
    if r == 1
        if c_global
            c_loc = unique([linspace(c_floor, 1-1e-6, 21), c_seed]);
        else
            c_loc = unique(min(max(c_seed + dc0*(-1:0.125:1), c_floor), 1-1e-6));
        end
        p_loc = unique([linspace(0,1,21), pi_seed]);
    else
        c_loc = unique(min(max(cb + dc*(-1:0.25:1), c_floor), 1-1e-6));
        p_loc = unique(min(max(pb + dp*(-1:0.25:1), 0), 1));
        dc = dc/4; dp = dp/4;
    end
    bv = -inf; bc = cb; bp = pb;
    for ii = 1:numel(c_loc)
        for jj = 1:numel(p_loc)
            v = -obj_cpi([c_loc(ii); p_loc(jj)])/obj_scale;
            if v > bv, bv = v; bc = c_loc(ii); bp = p_loc(jj); end
        end
    end
    if bv > vb, vb = bv; cb = bc; pb = bp; end
    rc(r).c = c_loc; rc(r).pi = p_loc; rc(r).best = [cb, pb, vb];
end
end

% ------------------------------------------------------------------------
function scan_write(fn, Sc)
%SCAN_WRITE  save() wrapped in a function so it is legal inside the parfor.
save(fn, '-struct', 'Sc');
end

% ------------------------------------------------------------------------
function [c_b, p_b, v_b] = refine_cpi_u(c0, p0, tau_fix, tau_R, v0, LW_W, Rf_at, R_S_at, Rf, R_S, R_REIT, pt, ...
                                         A_next_pre_return, H_next_W, Y_next_W, ...
                                         w, pp_z, one_m_g, beta_eff, beq_eff, h_beq_fac, ...
                                         c_floor, dc0, dp0, c_global, pi_global)
    % Shrinking-radius local grid scan of the (c, pi) surface with tau pinned.
    % Derivative-free, so it resolves the narrow interpolation-kink ridges that
    % defeat fmincon's finite differences. Cube twin of refine_cpi.
    R_A      = ((1 - tau_fix - tau_R) * Rf + tau_fix .* R_S + tau_R .* R_REIT) / pt;
    A_next_W = R_A * A_next_pre_return;
    denAH    = A_next_W + H_next_W;
    u3_col   = max(min(A_next_W ./ max(denAH, 1e-12), 1), 0);
    base_W   = denAH + Y_next_W;
    n_shock  = numel(w);
    c_b = c0; p_b = p0; v_b = v0;
    dc = dc0 / 4; dp = max(dp0, 0.05);
    for r = 1:4
        if r == 1
            if c_global
                c_loc = unique([linspace(c_floor, 1 - 1e-6, 21), c0]);
            else
                c_loc = unique(min(max(c0 + dc0 * (-1 : 0.125 : 1), c_floor), 1 - 1e-6));
            end
            if pi_global
                p_loc = unique([linspace(0, 1, 21), p0]);
            else
                p_loc = unique(min(max(p0 + max(dp0, 0.05) * (-1 : 0.125 : 1), 0), 1));
            end
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

function [cf, hc, ann_fac] = budget_coeffs(p, t, ann_price, net_inc)
%BUDGET_COEFFS  Age-t coefficients of the liquid-resource identity
%   m = s_X + cf*lambda + ann_fac*s_A - hc*s_H,
% which is what the main loop computes as LW_W. Factored out so the kappa
% interpolant can evaluate it at NEXT period's coefficients without
% duplicating the branch.
if t >= p.t_ret
    cf      = (1 - p.delta) * net_inc;
    ann_fac = net_inc / ann_price(t);
else
    kap     = p.kappa(min(t, numel(p.kappa)));
    cf      = (1 - p.delta) * (1 - kap) * net_inc;
    ann_fac = 0;
end
if p.is_owner
    if t <= numel(p.m_rate_path), mr = p.m_rate_path(t); else, mr = 0; end
    hc = p.theta + mr;
else
    hc = p.alpha;
end
end

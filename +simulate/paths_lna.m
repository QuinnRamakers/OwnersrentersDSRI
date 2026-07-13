function sim = paths_lna(p, profile, sol, ann_price, N, seed, X0_frac)
%PATHS_LNA  Forward Monte-Carlo simulation for the (u1,u2,u3) cube solver.
%
%   Identical to simulate.paths -- same shock construction, same default
%   seed, same budget/tax logic, same reported fields -- EXCEPT that the
%   policy lookup converts the simulated simplex state (lambda, s_A, s_H)
%   into the reparametrized coordinates of solver.bellman_step_lna:
%       u1 = lambda
%       u2 = (s_A + s_H) / (1 - lambda)
%       u3 = s_A / (s_A + s_H)
%   each clamped to [0,1] (guards the degenerate lines u2=0 and u1=1).
%   Every cube point is feasible, so no nearest-feasible NaN-fill is needed
%   when building the policy interpolants.
%
%   sol must come from solver.solve_lifecycle_lna (policies on
%   {p.u1_grid, p.u2_grid, p.u3_grid}).

if nargin < 5 || isempty(N), N = 5000; end
if nargin < 6 || isempty(seed), seed = 20260511; end
if nargin < 7 || isempty(X0_frac), X0_frac = 0; end   % initial liquid buffer = X0_frac * Y0
rng(seed);

T = p.T;
is_owner = p.is_owner;

% Tax parameters (guarded so legacy p-structs => no tax). Must match the
% solver: income tax (EET) on wages/AOW/annuity, accrual CGT (no loss offset)
% on the liquid account, DC fund sheltered.
tau_inc = 0; if isfield(p,'tau_inc'),      tau_inc = p.tau_inc;      end
tau_b   = 0; if isfield(p,'tau_cg_bond'),  tau_b   = p.tau_cg_bond;  end
tau_s   = 0; if isfield(p,'tau_cg_stock'), tau_s   = p.tau_cg_stock; end
net_inc = 1 - tau_inc;
Rf_at   = 1 + p.r * (1 - tau_b);

Y_path  = zeros(N, T);
X_path  = zeros(N, T);
A_path  = zeros(N, T);
H_path  = zeros(N, T);
W_path  = zeros(N, T);
lam_path = zeros(N, T);
sA_path  = zeros(N, T);
sH_path  = zeros(N, T);
c_path  = zeros(N, T);
pi_path = zeros(N, T);
C_path  = zeros(N, T);
LW_path = zeros(N, T);
m_path  = zeros(N, T);
ann_pay_path = zeros(N, T);
disp_inc = zeros(N, T);
bequest_path = zeros(N, 1);

n_clamp_c  = 0;
n_clamp_pi = 0;
n_negLW    = 0;

% Policy interpolants directly on the cube grid -- all nodes are feasible.
pp_c  = cell(T, 1);  pp_pi = cell(T, 1);
for t = 1:T
    pp_c{t}  = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                                  sol.c_pol(:,:,:,t), 'linear', 'nearest');
    pp_pi{t} = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                                  sol.pi_pol(:,:,:,t), 'linear', 'nearest');
end

logY_canon = config.income_profile(p);
Y0 = exp(logY_canon(1));
Y_path(:,1) = Y0;
H_path(:,1) = p.h_mult * Y0;
X_path(:,1) = X0_frac * Y0;
A_path(:,1) = 0;
W_path(:,1) = X_path(:,1) + A_path(:,1) + H_path(:,1) + Y_path(:,1);
lam_path(:,1) = Y_path(:,1) ./ W_path(:,1);
sA_path(:,1)  = A_path(:,1) ./ W_path(:,1);
sH_path(:,1)  = H_path(:,1) ./ W_path(:,1);

% Independent standard-normal draws, then Cholesky-correlated (income L,
% stock S, housing H) with the same Sigma used by grids.shock_grid -- no
% resampling, just a linear transform of the same three draws.
eps_S_ind = randn(N, T-1);
eps_Y_ind = randn(N, T-1);
eps_H_ind = randn(N, T-1);

Sigma_shock = [1,           p.corr_SL, p.corr_HL; ...
               p.corr_SL,   1,         p.corr_SH; ...
               p.corr_HL,   p.corr_SH, 1        ];
Lc_shock = chol(Sigma_shock, 'lower');

Zind_shock  = [eps_Y_ind(:).'; eps_S_ind(:).'; eps_H_ind(:).'];  % 3 x N*(T-1)
Zcorr_shock = Lc_shock * Zind_shock;
eps_Y = reshape(Zcorr_shock(1, :), N, T-1);
eps_S = reshape(Zcorr_shock(2, :), N, T-1);
eps_H = reshape(Zcorr_shock(3, :), N, T-1);

for t = 1:T
    is_retired = (t >= p.t_ret);

    if is_owner
        if t <= numel(p.m_rate_path)
            m_rate_t = p.m_rate_path(t);
        else
            m_rate_t = 0;
        end
        h_cost_rate = p.theta + m_rate_t;
    else
        m_rate_t = 0;
        h_cost_rate = p.alpha;
    end

    if is_retired
        contrib_factor = (1 - p.delta) * net_inc;            % AOW taxed as income
        ann_pay     = A_path(:,t) ./ ann_price(t);           % GROSS payout (reduces A stock)
        ann_pay_net = ann_pay .* net_inc;                    % NET payout (spendable)
        LW = X_path(:,t) + contrib_factor .* Y_path(:,t) + ann_pay_net ...
             - h_cost_rate .* H_path(:,t);
    else
        contrib_factor = (1 - p.delta) * (1 - p.kappa) * net_inc;  % deductible contrib; rest taxed
        ann_pay     = zeros(N, 1);
        ann_pay_net = zeros(N, 1);
        LW = X_path(:,t) + contrib_factor .* Y_path(:,t) ...
             - h_cost_rate .* H_path(:,t);
    end
    LW_path(:,t) = LW;
    m_path(:,t)  = m_rate_t .* H_path(:,t);
    ann_pay_path(:,t) = ann_pay;          % report GROSS payout from the fund
    disp_inc(:,t) = contrib_factor .* Y_path(:,t) + ann_pay_net - h_cost_rate .* H_path(:,t);

    % Convert simulated simplex state to cube coordinates for the lookup
    u1q = min(max(lam_path(:,t), 0), 1);
    sAH = sA_path(:,t) + sH_path(:,t);
    u2q = min(max(sAH ./ max(1 - lam_path(:,t), 1e-12), 0), 1);
    u3q = min(max(sA_path(:,t) ./ max(sAH, 1e-12), 0), 1);

    cf_raw = pp_c{t}(u1q, u2q, u3q);
    pi_raw = pp_pi{t}(u1q, u2q, u3q);
    cf  = max(min(cf_raw, 1), 0);
    pi_ = max(min(pi_raw, 1), 0);
    n_clamp_c  = n_clamp_c  + sum(abs(cf  - cf_raw)  > 1e-10);
    n_clamp_pi = n_clamp_pi + sum(abs(pi_ - pi_raw) > 1e-10);
    c_path(:,t)  = cf;
    pi_path(:,t) = pi_;
    C_path(:,t)  = cf .* max(LW, 0);

    if t == T
        % Bequest: liquid wealth post-consumption + housing (if owner).
        % Pension A is forfeited at death (annuity convention).
        if is_owner
            bequest_path = max(0, (1 - cf) .* LW) + H_path(:,t);
        else
            bequest_path = max(0, (1 - cf) .* LW);
        end
        break
    end

    % No-borrow safety clamp on liquid post-saving
    X_post = max((1 - cf) .* LW, 0);
    n_negLW = n_negLW + sum(LW < 0);

    % Returns
    R_S_draw = exp(p.mu_S + p.sigma_S * eps_S(:,t));
    R_H_draw = exp(p.mu_H + p.sigma_H * eps_H(:,t));
    R_S_at_draw = R_S_draw - tau_s .* max(R_S_draw - 1, 0);   % after-tax equity (no loss offset)
    R_X      = (1 - pi_) .* Rf_at + pi_ .* R_S_at_draw;       % liquid acct after CGT

    % Pension return for transition t -> t+1: tau_S applies on the t-side.
    tau_t      = p.tau_S(t);
    pt_surv    = profile.p_surv(t);
    R_A_with   = ((1 - tau_t) * p.Rf + tau_t .* R_S_draw) ./ max(pt_surv, 1e-8);

    % Pension account dynamics
    if is_retired
        A_pre = A_path(:,t) - ann_pay;            % stock after payout
    else
        A_pre = A_path(:,t) + p.kappa .* Y_path(:,t);   % stock after contribution
    end

    X_path(:,t+1) = R_X .* X_post;
    A_path(:,t+1) = R_A_with .* A_pre;
    H_path(:,t+1) = R_H_draw .* H_path(:,t);

    if t < p.t_ret - 1
        Y_path(:,t+1) = Y_path(:,t) .* exp(profile.mu_growth(t) + profile.sigma_l_log(t) .* eps_Y(:,t));
    elseif t == p.t_ret - 1
        Y_path(:,t+1) = p.replacement .* Y_path(:,t);
    else
        Y_path(:,t+1) = Y_path(:,t);
    end

    W_path(:,t+1) = X_path(:,t+1) + A_path(:,t+1) + H_path(:,t+1) + Y_path(:,t+1);
    lam_path(:,t+1) = Y_path(:,t+1) ./ W_path(:,t+1);
    sA_path(:,t+1)  = A_path(:,t+1) ./ W_path(:,t+1);
    sH_path(:,t+1)  = H_path(:,t+1) ./ W_path(:,t+1);
end

if n_clamp_c > 0.001 * N * T
    warning('paths_lna:clamp_c', '%d c-clamps fired', n_clamp_c);
end
if n_clamp_pi > 0.001 * N * T
    warning('paths_lna:clamp_pi', '%d pi-clamps fired', n_clamp_pi);
end

sim.Y = Y_path;  sim.X = X_path;  sim.A = A_path;  sim.H = H_path;  sim.W = W_path;
sim.lambda = lam_path;  sim.sA = sA_path;  sim.sH = sH_path;
sim.c_frac = c_path;  sim.pi = pi_path;
sim.C = C_path;  sim.LW = LW_path;
sim.m_pay = m_path;
sim.ann_pay = ann_pay_path;
sim.disp_inc = disp_inc;
sim.bequest = bequest_path;
sim.ages = (p.age0 : p.age0 + p.T - 1);
sim.N = N;
sim.is_owner = is_owner;
sim.diagnostics = struct('n_clamp_c', n_clamp_c, 'n_clamp_pi', n_clamp_pi, ...
                         'n_negLW', n_negLW);
end

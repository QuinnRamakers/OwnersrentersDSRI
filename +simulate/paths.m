function sim = paths(p, profile, sol, ann_price, N, seed, X0_frac)
%PATHS  Forward Monte-Carlo simulation, combined pension+housing model.
%
%   Initial state at age 20: X = X0_frac*Y_0, A = 0, H = h_mult * Y_0, Y = Y_0.
%   X0_frac (optional, default 0) endows the household with an initial liquid
%   buffer of X0_frac years of income -- used for buffered-benchmark welfare.
%
%   Working transitions:
%     X_{t+1} = R_X * X_post
%     A_{t+1} = R_A_with * (A_t + kappa * Y_t)
%     H_{t+1} = R_H * H_t
%     Y_{t+1} = Y_t * exp(mu_g + sigma_l * eps_Y)
%   Retirement transition (t = t_ret - 1): Y_{t+1} = replacement * Y_t,
%     A_{t+1} = R_A_with * (A_t + kappa*Y_t)  (one last contribution).
%   Retired transitions (t >= t_ret):
%     A pays out A_t/ann_price(t); A_{t+1} = R_A_with * (A_t - payout)
%   LW:
%     Working: LW = X + (1-delta)(1-kappa)*Y - h_cost_rate*H
%     Retired: LW = X + (1-delta)*Y + A/ann_price(t) - h_cost_rate*H
%
%   R_A_with = ((1-tau)*Rf + tau*R_S) / p_t  (survival-credit pension return)

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

% Nearest-feasible-neighbor map depends only on the fixed simplex grid, not
% on t or on which policy array -- build it once and reuse it, instead of
% re-running an O(n_bad*n_ok) search inside the loop below 2*T times.
mask_ok = ~isnan(sol.c_pol(:,:,:,1));
[bad_lin, nn_lin] = build_nan_fill_map(mask_ok);

pp_c  = cell(T, 1);  pp_pi = cell(T, 1);
for t = 1:T
    Cpol = sol.c_pol(:,:,:,t);  Ppol = sol.pi_pol(:,:,:,t);
    Cf = apply_nan_fill(Cpol, bad_lin, nn_lin);
    Pf = apply_nan_fill(Ppol, bad_lin, nn_lin);
    pp_c{t}  = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, Cf, 'linear', 'nearest');
    pp_pi{t} = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, Pf, 'linear', 'nearest');
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

eps_S = randn(N, T-1);
eps_Y = randn(N, T-1);
eps_H = randn(N, T-1);

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

    cf_raw = pp_c{t}(lam_path(:,t),  sA_path(:,t), sH_path(:,t));
    pi_raw = pp_pi{t}(lam_path(:,t), sA_path(:,t), sH_path(:,t));
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
    warning('paths:clamp_c', '%d c-clamps fired', n_clamp_c);
end
if n_clamp_pi > 0.001 * N * T
    warning('paths:clamp_pi', '%d pi-clamps fired', n_clamp_pi);
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

function [bad_lin, nn_lin] = build_nan_fill_map(mask_ok)
% For every infeasible grid node, find the linear index of its nearest
% feasible neighbor. Depends only on the (fixed) grid geometry, so callers
% should compute this once and reuse it via apply_nan_fill, rather than
% re-deriving it for every policy array.
bad_lin = find(~mask_ok);
nn_lin  = zeros(size(bad_lin));
if isempty(bad_lin), return; end
[NL, NA, NH] = size(mask_ok);
[Ig, Jg, Kg] = ndgrid(1:NL, 1:NA, 1:NH);
I_ok = Ig(mask_ok); J_ok = Jg(mask_ok); K_ok = Kg(mask_ok);
ok_lin = find(mask_ok);
I_bad = Ig(~mask_ok); J_bad = Jg(~mask_ok); K_bad = Kg(~mask_ok);
for k = 1:numel(I_bad)
    di = I_bad(k) - I_ok; dj = J_bad(k) - J_ok; dk = K_bad(k) - K_ok;
    d2 = di.*di + dj.*dj + dk.*dk;
    [~, q] = min(d2);
    nn_lin(k) = ok_lin(q);
end
end

function Z = apply_nan_fill(M, bad_lin, nn_lin)
Z = M;
if isempty(bad_lin), return; end
Z(bad_lin) = M(nn_lin);
end

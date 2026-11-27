function [V, c, pi_, Vc] = point_solve(r, t, lam, sA, sH, q, opts)
%POINT_SOLVE  The solver's Bellman problem at given states, against r's V_next.
%
%   [V, c, pi, Vc] = point_solve(r, t, lam, sA, sH, q)
%   [...] = point_solve(r, t, lam, sA, sH, q, fixed=neural.grid_policy_fn(r))
%   [...] = point_solve(r, t, lam, sA, sH, q, V_next=V)   % another continuation
%
%   solver.bellman_step_lna in its point mode at the states (lam = Y/W,
%   sA = A/W, sH = H/W, q = H0/H; column vectors), with next year's value
%   r.sol.V(:,:,:,:,t+1) (or opts.V_next) on r's grid, its quadrature, search
%   and bankruptcy rule. V is per unit of W^(1-gamma), as sol.V; c the share
%   of liquid resources consumed, pi the equity share, Vc the value of
%   continuing (default as a choice; empty otherwise). With fixed, a policy
%   struct as neural.evaluate_policy takes, nothing is searched: V is the
%   value of that policy for one year followed by V_next (with default as a
%   choice, the value of continuing). opts.chunk states go to the solver at a
%   time, so the parfor inside stays busy without holding everything at once.

arguments
    r struct
    t (1,1) double
    lam (:,1) double
    sA (:,1) double
    sH (:,1) double
    q (:,1) double
    opts.fixed = []
    opts.V_next = []
    opts.seed_c (:,1) double = []
    opts.seed_pi (:,1) double = []
    opts.chunk (1,1) double = 20000
end
p = r.p;
if isempty(opts.V_next)
    if t < p.T, Vn = r.sol.V(:, :, :, :, t + 1); else, Vn = []; end
else
    Vn = opts.V_next;
end
% model.run does not keep the quadrature; callers may cache it in r.shocks.
if isfield(r, 'shocks'), shocks = r.shocks; else, [~, shocks] = config.model_inputs(p); end
profile = r.profile; ann_price = r.ann_price;
n = numel(lam);
V = nan(n, 1); c = nan(n, 1); pi_ = nan(n, 1); Vc = [];
choice = p.floor_absorbing && isfield(p, 'default_choice') && p.default_choice;
if choice, Vc = -inf(n, 1); end
for a = 1:opts.chunk:n
    k = a:min(n, a + opts.chunk - 1);
    pts = struct('lam', lam(k), 'sA', sA(k), 'sH', sH(k), 'q', q(k));
    if ~isempty(opts.seed_c), pts.c = opts.seed_c(k); pts.pi = opts.seed_pi(k); end
    [V(k), c(k), pi_(k), ~, ~, vc] = solver.bellman_step_lna(t, Vn, p, profile, shocks, ann_price, [], opts.fixed, pts);
    if choice, Vc(k) = vc; end
end
end

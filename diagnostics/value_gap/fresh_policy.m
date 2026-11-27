function sol2 = fresh_policy(r, mode)
%FRESH_POLICY  A policy for simulate.paths_lna that is optimised at each state.
%
%   sim = simulate.paths_lna(r.p, r.profile, fresh_policy(r, 'all'), r.ann_price, N, seed, r.p.b0)
%
%   mode 'all': consumption, the equity share and (default as a choice) the
%   default decision are solved at each simulated household's own state
%   against the solver's V_next (point_solve), instead of read off the grid.
%   mode 'default': consumption and the equity share are the grid policy, as
%   the simulator reads it; only the default decision is taken afresh, by
%   comparing the default value with the value of continuing at the state
%   with the solver's V_next (continuing also optimised at the state).
%   If simulated welfare then rises to the value function, the policy's
%   interpolation (or the simulator's default rule) is the cause of the gap.
%   The point solves run in the pool the solver uses.

arguments
    r struct
    mode char {mustBeMember(mode, {'all', 'default'})} = 'all'
end
p = r.p;
[~, shocks] = config.model_inputs(p); r.shocks = shocks;
choice = p.floor_absorbing && isfield(p, 'default_choice') && p.default_choice;
assert(choice || strcmp(mode, 'all'), 'fresh_policy:mode', 'mode ''default'' needs default as a choice.');
gpol = neural.grid_policy_fn(r);
sol2 = struct('policy_fn', @fn);

    function varargout = fn(t, u1, u2, u3, q)
        n = numel(u1);
        lam = u1; sA = u2 .* (1 - u1) .* u3; sH = u2 .* (1 - u1) .* (1 - u3);
        [lw, F_W, Flo_W] = resources(p, r.ann_price, t, lam, sA, sH, q);
        % Households with nothing (bankrupt earlier: u1 = 1 with housing) and
        % those below the bound need no solve: the simulator decides them.
        solve = lw > Flo_W & ~(u1 >= 1 & p.h_mult > 0);
        c = ones(n, 1); pi_ = zeros(n, 1); d = false(n, 1);
        if strcmp(mode, 'all') || choice
            [c0, pi0] = gpol.fn(t, u1, u2, u3, q);      % the seed: the grid policy
            [V, cs, ps, Vc] = point_solve(r, t, lam(solve), sA(solve), sH(solve), q(solve), ...
                seed_c = c0(solve), seed_pi = pi0(solve));
            c(solve) = cs; pi_(solve) = ps;
            if choice
                vdef = (F_W(solve)) .^ (1 - p.gamma) / (1 - p.gamma) * p.D_beq(t);
                d(solve) = Vc <= vdef;
            end
        end
        if strcmp(mode, 'default')
            [c, pi_] = gpol.fn(t, u1, u2, u3, q);
        end
        % paths_lna reads s, the share above the bound of consumption it uses:
        % F with the forced rule, phi_floor Y with default as a choice.
        if choice, Fb = Flo_W; else, Fb = F_W; end
        Fs = min(Fb ./ max(lw, realmin), 1);
        s = (c - Fs) ./ max(1 - Fs, realmin);
        s(Fs >= 1) = 0;
        varargout = {s, pi_};
        if choice, varargout{3} = d; end
        if t == 1 || mod(t, 10) == 0
            fprintf('  fresh policy t=%d: %d states solved\n', t, sum(solve));
        end
    end
end

function [lw, F_W, Flo_W] = resources(p, ann_price, t, lam, sA, sH, q)
%RESOURCES  Liquid resources, the floor and the search's lower bound, per unit
%   of W, as solver.bellman_step_lna and simulate.paths_lna form them.
net_inc = 1 - p.tau_inc;
sX = 1 - lam - sA - sH;
if p.h_mult == 0
    h = 0;
elseif p.is_owner
    if t <= numel(p.m_rate_path), m = p.m_rate_path(t); else, m = 0; end
    hm = m; ht = p.theta;
    if strcmp(p.mortgage, 'annuity'), hm = m .* q; end
    if p.maint_on_purchase, ht = p.theta .* q; end
    h = ht + hm;
else
    h = p.alpha;
end
if t >= p.t_ret
    lw = sX + net_inc * lam + net_inc * sA / ann_price(t) - h .* sH;
else
    lw = sX + (1 - p.kappa(min(t, numel(p.kappa)))) * net_inc * lam - h .* sH;
end
F_W = max(p.phi_path(t) * lam, 1e-12);
choice = p.floor_absorbing && isfield(p, 'default_choice') && p.default_choice;
Flo_W = F_W;
if choice, Flo_W = max(p.phi_floor * lam, 1e-12); end
end

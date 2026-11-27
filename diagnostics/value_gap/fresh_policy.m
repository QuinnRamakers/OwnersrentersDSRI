function sol2 = fresh_policy(r, mode, opts)
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
%   mode 'boundary': as 'default', but the decision is solved at the state
%   only where the corner nodes of the household's grid cell disagree (the
%   cell the default boundary runs through); elsewhere the nodes' common
%   decision is taken. If the boundary does not fold back inside a cell this
%   is the 'default' rule at a fraction of the cost.
%   If simulated welfare then rises to the value function, the policy's
%   interpolation (or the simulator's default rule) is the cause of the gap.
%   The point solves run in the pool the solver uses. sol2.stats() returns
%   the number of states solved and in boundary cells, by period.

arguments
    r struct
    mode char {mustBeMember(mode, {'all', 'default', 'boundary'})} = 'all'
    opts.gh_n double = []          % the point solves' quadrature: gh_n nodes a shock (default r.p.gh_n)
end
p = r.p;
pg = p; if ~isempty(opts.gh_n), pg.gh_n = opts.gh_n; end
r.shocks = grids.shock_grid(pg);
choice = p.floor_absorbing && isfield(p, 'default_choice') && p.default_choice;
assert(choice || strcmp(mode, 'all'), 'fresh_policy:mode', 'modes ''default'' and ''boundary'' need default as a choice.');
gpol = neural.grid_policy_fn(r);
n_solved = zeros(p.T, 1); n_cell = zeros(p.T, 1);
if strcmp(mode, 'boundary'), node_d = node_decisions(r); end
sol2 = struct('policy_fn', @fn, 'stats', @stats);

    function S = stats()
        S = table((1:p.T).', n_cell, n_solved, 'VariableNames', {'t', 'in_boundary_cell', 'solved'});
    end

    function varargout = fn(t, u1, u2, u3, q)
        n = numel(u1);
        lam = u1; sA = u2 .* (1 - u1) .* u3; sH = u2 .* (1 - u1) .* (1 - u3);
        [lw, F_W, Flo_W] = resources(p, r.ann_price, t, lam, sA, sH, q);
        % Households with nothing (bankrupt earlier: u1 = 1 with housing) and
        % those below the bound need no solve: the simulator decides them.
        solve = lw > Flo_W & ~(u1 >= 1 & p.h_mult > 0);
        c = ones(n, 1); pi_ = zeros(n, 1); d = false(n, 1);
        if strcmp(mode, 'boundary')
            dn = node_d{t}(u1, u2, u3, q);           % share of the cell's corners that default
            mixed = solve & dn > 1e-12 & dn < 1 - 1e-12;
            d = dn >= 1 - 1e-12;
            n_cell(t) = n_cell(t) + sum(mixed);
            if any(mixed)
                [~, ~, ~, Vc] = point_solve(r, t, lam(mixed), sA(mixed), sH(mixed), q(mixed));
                vdef = (F_W(mixed)) .^ (1 - p.gamma) / (1 - p.gamma) * p.D_beq(t);
                d(mixed) = Vc <= vdef;
                n_solved(t) = n_solved(t) + sum(mixed);
            end
            [c, pi_] = gpol.fn(t, u1, u2, u3, q);
        else
            if strcmp(mode, 'all') || choice
                [c0, pi0] = gpol.fn(t, u1, u2, u3, q);      % the seed: the grid policy
                [V, cs, ps, Vc] = point_solve(r, t, lam(solve), sA(solve), sH(solve), q(solve), ...
                    seed_c = c0(solve), seed_pi = pi0(solve)); %#ok<ASGLU>
                c(solve) = cs; pi_(solve) = ps;
                n_solved(t) = n_solved(t) + sum(solve);
                if choice
                    vdef = (F_W(solve)) .^ (1 - p.gamma) / (1 - p.gamma) * p.D_beq(t);
                    d(solve) = Vc <= vdef;
                end
            end
            if strcmp(mode, 'default')
                [c, pi_] = gpol.fn(t, u1, u2, u3, q);
            end
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
            fprintf('  fresh policy (%s) t=%d: %d states solved\n', mode, t, n_solved(t));
        end
    end
end

function f = node_decisions(r)
%NODE_DECISIONS  Per period, a function giving the linear interpolant of the
%   nodes' default decisions (1 default, 0 continue) at clamped coordinates,
%   as the simulator clamps them: strictly between 0 and 1 means the
%   household's cell has corners that disagree.
p = r.p; sol = r.sol; T = p.T;
assert(~(isfield(p, 'u2_coord') && strcmp(p.u2_coord, 'edge')), 'fresh_policy:edge', 'boundary mode reads the share coordinate only.');
q_grid = p.q_grid(:); iq1 = find(q_grid == 1);
q_dep = numel(q_grid) > 1 & flipud(cummax(flipud(double(p.q_live(:))))) > 0;
Dfac = p.D_beq(:) .^ (1 / (1 - p.gamma));
f = cell(T, 1);
for t = 1:T
    [g1, g2] = utility.grid_at(p, t);
    Vc = sol.V_cont(:, :, :, :, t);
    z = zeros(size(Vc)); m = isfinite(Vc); z(m) = ((1 - p.gamma) * Vc(m)) .^ (1 / (1 - p.gamma));
    zdef = p.phi_path(t) * max(g1(:), 1e-12) * Dfac(t);   % default value per unit of W, by u1 node
    dn = double(z <= zdef);                              % implicit expansion along u1
    lim = [g1(1), g1(end), g2(1), g2(end), q_grid(1), q_grid(end)];
    if q_dep(t)
        G = griddedInterpolant({g1, g2, p.u3_grid, q_grid}, dn, 'linear', 'nearest');
        f{t} = @(u1, u2, u3, q) G(min(max(u1, lim(1)), lim(2)), min(max(u2, lim(3)), lim(4)), u3, min(max(q, lim(5)), lim(6)));
    else
        G = griddedInterpolant({g1, g2, p.u3_grid}, dn(:, :, :, iq1), 'linear', 'nearest');
        f{t} = @(u1, u2, u3, q) G(min(max(u1, lim(1)), lim(2)), min(max(u2, lim(3)), lim(4)), u3);
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

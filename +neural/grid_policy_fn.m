function pol = grid_policy_fn(r)
%GRID_POLICY_FN  A grid solve's policy as a function of the coordinates.
%
%   pol = neural.grid_policy_fn(r)
%   [c, pi] = pol.fn(t, u1, u2, u3, q)
%
%   The lookup of simulate.paths_lna: linear interpolation of r.sol.c_pol and
%   r.sol.pi_pol on r's grid, the coordinates clamped to the grid, on the
%   4D grid where the policy depends on q and on the q = 1 slice elsewhere.
%   c is the share of resources consumed (pol.kind = 'c'), clamped to [0, 1]
%   as in the simulator. For neural.evaluate_policy on another grid.

p = r.p; sol = r.sol; T = p.T;
q_grid = p.q_grid(:);
iq1 = find(q_grid == 1);
q_dep = numel(q_grid) > 1 & flipud(cummax(flipud(double(p.q_live(:))))) > 0;
pp_c = cell(T, 1); pp_pi = cell(T, 1); lim = cell(T, 1);
for t = 1:T
    [g1, g2] = utility.grid_at(p, t);
    lim{t} = [g1(1), g1(end), g2(1), g2(end), q_grid(1), q_grid(end)];
    if q_dep(t)
        ax = {g1, g2, p.u3_grid, q_grid};
        pp_c{t}  = griddedInterpolant(ax, sol.c_pol(:, :, :, :, t), 'linear', 'nearest');
        pp_pi{t} = griddedInterpolant(ax, sol.pi_pol(:, :, :, :, t), 'linear', 'nearest');
    else
        ax = {g1, g2, p.u3_grid};
        pp_c{t}  = griddedInterpolant(ax, sol.c_pol(:, :, :, iq1, t), 'linear', 'nearest');
        pp_pi{t} = griddedInterpolant(ax, sol.pi_pol(:, :, :, iq1, t), 'linear', 'nearest');
    end
end
pol = struct('fn', @lookup, 'kind', 'c');

    function [c, pi_] = lookup(t, u1, u2, u3, q)
        L = lim{t};
        u1 = min(max(u1, L(1)), L(2));
        u2 = min(max(u2, L(3)), L(4));
        q  = min(max(q, L(5)), L(6));
        if q_dep(t)
            c = pp_c{t}(u1, u2, u3, q); pi_ = pp_pi{t}(u1, u2, u3, q);
        else
            c = pp_c{t}(u1, u2, u3); pi_ = pp_pi{t}(u1, u2, u3);
        end
        c = min(max(c, 0), 1); pi_ = min(max(pi_, 0), 1);
    end
end

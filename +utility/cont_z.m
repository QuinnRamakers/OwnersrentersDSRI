function [z, info] = cont_z(p, t, Vc, ann_price, extend)
%CONT_Z  The value of continuing on period t's grid in certainty-equivalent units.
%
%   z = utility.cont_z(p, t, Vc, ann_price)            % 0 where continuing is not open
%   [z, info] = utility.cont_z(p, t, Vc, ann_price, true)
%
%   Vc is sol.V_cont(:,:,:,:,t), the value of continuing per unit of
%   W^(1-gamma) (-Inf where the household has no resources to continue
%   with), N_u1 x N_u2 x N_u3 x N_q on period t's grid. z is its certainty
%   equivalent per unit of W, ((1-gamma) Vc)^(1/(1-gamma)), and 0 where Vc is
%   -Inf, as the simulator has read it since default became a choice.
%
%   With extend (p.default_boundary = 'extend'), a node where continuing is
%   not open takes instead the z of the nearest open node on its u2 line
%   (same u1, u3, q), scaled by the ratio of the two nodes' resources above
%   the edge, s = LW/W - phi_floor u1 = num - den u2 (utility.slack_terms):
%       z(closed) = z(open) * s(closed) / s(open)  <= 0.
%   Linear interpolation between the two nodes then runs through zero at the
%   edge of continuing itself, not at the closed node beyond it, so the
%   states just inside the edge are not priced off a node that still holds
%   the open node's value. Near the edge the true z goes to zero in
%   proportion to resources (consumption is all there is), so this is the
%   right first-order shape; the max with the exact default value
%   (solver.bellman_step_lna, bankrupt_nodes) removes the negative values.
%   A line with no open node keeps 0. info.n_closed counts the closed nodes,
%   info.n_lines_none the lines without an open node.
if nargin < 5, extend = false; end
g = p.gamma;
z = zeros(size(Vc));
m = isfinite(Vc);
z(m) = ((1 - g) * Vc(m)) .^ (1 / (1 - g));
info = struct('n_closed', nnz(~m), 'n_lines_none', 0);
if ~extend || all(m(:)), return; end

[g1, g2] = utility.grid_at(p, t);
N1 = numel(g1); N2 = numel(g2); N3 = numel(p.u3_grid); Nq = size(Vc, 4);
q_grid = p.q_grid(:);
if Nq == 1, q_grid = 1; end
edge = isfield(p, 'u2_coord') && strcmp(p.u2_coord, 'edge');
[U1, U2, U3] = ndgrid(g1, g2, p.u3_grid);
for iq = 1:Nq
    [num, den] = utility.slack_terms(p, t, U1, U3, q_grid(iq), ann_price);
    u2 = U2;
    if edge, u2 = U2 .* utility.u2_max(p, t, U1, U3, q_grid(iq), ann_price); end
    s  = num - den .* u2;                         % N1 x N2 x N3
    zs = z(:, :, :, iq); ms = m(:, :, :, iq);
    for i3 = 1:N3
        for i1 = 1:N1
            open = ms(i1, :, i3);
            if all(open), continue; end
            ko = find(open);
            if isempty(ko), info.n_lines_none = info.n_lines_none + 1; continue; end
            for j = find(~open)
                [~, ii] = min(abs(ko - j));
                k = ko(ii);
                zs(i1, j, i3) = zs(i1, k, i3) * min(s(i1, j, i3), 0) / max(s(i1, k, i3), realmin);
            end
        end
    end
    z(:, :, :, iq) = zs;
end
end

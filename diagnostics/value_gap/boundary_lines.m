function out = boundary_lines(r)
%BOUNDARY_LINES  The default boundary along u2 at each (t, u1, u3, q).
%
%   out = boundary_lines(r)            % r = model.run output with r.sol, default as a choice
%
%   At every node the solve's own decision: default where the value of
%   continuing (sol.V_cont) is at or below the default value, or continuing
%   is not open. Along each u2 line (fixed t, u1, u3, q) the decision should
%   switch once, from continuing at low u2 (liquid wealth) to default at high
%   u2, if the boundary is monotone. out.T counts, by period, the lines that
%   never default, that switch once from continue to default, that switch
%   once the other way, and that switch more than once; out.multi lists the
%   lines with more than one switch (t, i1, i3, iq and the decisions).
p = r.p; sol = r.sol; T = p.T; g = p.gamma;
assert(p.floor_absorbing && p.default_choice, 'boundary_lines:choice', 'needs default as a choice.');
Dfac = p.D_beq(:) .^ (1 / (1 - g));
Nq = numel(p.q_grid); N3 = numel(p.u3_grid);
rows = zeros(T, 5); multi = zeros(0, 4); dec = {};
for t = 1:T
    g1 = utility.grid_at(p, t);
    Vc = sol.V_cont(:, :, :, :, t);
    z = zeros(size(Vc)); m = isfinite(Vc); z(m) = ((1 - g) * Vc(m)) .^ (1 / (1 - g));
    zdef = p.phi_path(t) * max(g1(:), 1e-12) * Dfac(t);
    d = z <= zdef;                                  % N1 x N2 x N3 x Nq
    for iq = 1:Nq
        for i3 = 1:N3
            for i1 = 1:numel(g1)
                dl = d(i1, :, i3, iq);
                sw = diff(double(dl));
                n_sw = nnz(sw);
                if ~any(dl)
                    rows(t, 1) = rows(t, 1) + 1;
                elseif n_sw == 0
                    rows(t, 5) = rows(t, 5) + 1;   % defaults along the whole line
                elseif n_sw == 1 && any(sw > 0)
                    rows(t, 2) = rows(t, 2) + 1;
                elseif n_sw == 1
                    rows(t, 3) = rows(t, 3) + 1;
                else
                    rows(t, 4) = rows(t, 4) + 1;
                    multi(end + 1, :) = [t, i1, i3, iq]; %#ok<AGROW>
                    dec{end + 1, 1} = dl; %#ok<AGROW>
                end
            end
        end
    end
end
out.T = array2table([(1:T).', p.age0 + (0:T-1).', rows], 'VariableNames', ...
    {'t', 'age', 'never', 'cont_to_default', 'default_to_cont', 'more_than_one', 'all_default'});
out.multi = array2table(multi, 'VariableNames', {'t', 'i1', 'i3', 'iq'});
out.multi.decisions = dec;
fprintf('boundary along u2: %d lines, %d never default, %d switch once to default, %d once the other way, %d more than once, %d default throughout\n', ...
    T * numel(utility.grid_at(p, 1)) * N3 * Nq, sum(rows(:, 1)), sum(rows(:, 2)), sum(rows(:, 3)), sum(rows(:, 4)), sum(rows(:, 5)));
end

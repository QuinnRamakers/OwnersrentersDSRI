function T = compare_rules(r, opts)
%COMPARE_RULES  Simulated welfare of r's grid policy under default rules.
%
%   T = compare_rules(r)                                   % r = model.run output with r.sol
%   T = compare_rules(r, N=100000, seed=303, rules=["grid", "boundary"])
%
%   The same households (seed) under each rule:
%     grid      simulate.paths_lna as it is: default where V_cont, interpolated
%               in z, is at or below the default value
%     boundary  fresh_policy(r, 'boundary'): the decision solved at the state
%               where the cell's corner nodes disagree, else the nodes' decision
%     default   fresh_policy(r, 'default'): the decision solved at every state
%   Consumption and the equity share are the grid policy in every rule. Each
%   row: the solver's value at entry, simulated welfare (realised_utility,
%   with its s.e.), the gap in percent, the share ever defaulting, the share
%   of utility in the worst 1% of households, states solved and seconds.

arguments
    r struct
    opts.N (1,1) double = 100000
    opts.seed (1,1) double = 303
    opts.rules string = ["grid", "boundary"]
end
p = r.p;
rows = cell(0, 9);
for rule = opts.rules
    t0 = tic; solved = 0;
    if rule == "grid"
        sol = r.sol;
    else
        sol = fresh_policy(r, char(rule));
    end
    sim = simulate.paths_lna(p, r.profile, sol, r.ann_price, opts.N, opts.seed, p.b0);
    [U, ce, se] = realised_utility(p, r.profile, sim);
    if rule ~= "grid", st = sol.stats(); solved = sum(st.solved); end
    Us = sort(U); worst = sum(Us(1:ceil(0.01 * numel(U)))) / sum(U);
    ever = mean(any(sim.absorbed, 2));
    rows(end + 1, :) = {char(rule), r.checks.ce_entry, ce, se, 100 * (r.checks.ce_entry / ce - 1), ever, worst, solved, toc(t0)}; %#ok<AGROW>
    fprintf('rule %s: ce_entry %.4f, simulated %.4f (s.e. %.4f), value above simulation %+.1f%%, ever default %.4f, worst 1%% hold %.2f, %d states solved, %.0f s\n', ...
        rows{end, :});
end
T = cell2table(rows, 'VariableNames', {'rule', 'ce_entry', 'ce_sim', 'se', 'gap_pct', 'ever_default', 'worst1_share', 'solved', 'sec'});
end

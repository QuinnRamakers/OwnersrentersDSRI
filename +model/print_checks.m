function print_checks(r)
%PRINT_CHECKS  One-screen report of a model.run result.
s = r.summary; c = r.checks; a = s.ages;
at = @(v, age) v(a == age);
fprintf('\n  %s, %s\n', r.tenure, s.units);
fprintf('  %-6s %10s %10s %10s %8s %8s %8s\n', 'age', 'C med', 'net worth', 'DC pot', 'pi', 'equity', 'floored');
for age = [25 30 40 50 60 66 70 80 90]
    if ~any(a == age), continue; end
    fprintf('  %-6d %10.0f %10.0f %10.0f %8.2f %8.2f %7.1f%%\n', age, ...
        at(s.C.p50, age), at(s.net_worth.mean, age), at(s.A.mean, age), ...
        at(s.pi, age), at(s.equity_share, age), 100 * at(s.floored, age));
end
fprintf('  housing cost / net income at 25: %.0f%%   after-tax premium %.2f%%, liquid Merton share %.2f\n', ...
    100 * c.burden_25, 100 * c.premium_after_tax, c.merton_liquid);
fprintf('  entry value worth a constant %.3g x entry income;  off-grid lookups %d;  thin u1 at %.0f%% of ages 40+\n', ...
    c.ce_entry, sum(c.offgrid), 100 * c.thin_u1_40);
for i = 1:numel(c.notes)
    fprintf('  NOTE: %s\n', c.notes{i});
end
fprintf('\n');
end

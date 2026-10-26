function floor_rule_dashboards(c_min)
%FLOOR_RULE_DASHBOARDS  Owner dashboards for both maintenance rules, with and without the absorbing floor.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       floor_rule_dashboards          % c_min = 5,000
%
%   Loads four saved step-16 owner solves on the one-axis base grid (bunched
%   16x16, u3 at 10 bunched, q at 4, active-set; nothing is solved):
%   maintenance on the purchase price and on the current value, each with
%   the absorbing floor at c_min and with the yearly top-up at 1e-6 instead.
%   Writes, in summary_step16/:
%     16_base_owner_<rule>_<floor>.png    the twelve-panel dashboard of each
%     16_base_owner_floor_rules.png       the four overlaid (figures.compare),
%                                         the purchase price with the floor
%                                         as the reference

arguments
    c_min (1,1) double = 5000
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
base = 'pow3_16x16_lim_u3p2_qn4';
C = {sprintf('%s_cmin%d_as_nc11_mop', base, c_min), 'purchase', 'floor',  sprintf('Purchase price, floor EUR %d', c_min)
     sprintf('%s_as_nc11_mop', base),               'purchase', 'topup',  'Purchase price, top-up 1e-6'
     sprintf('%s_cmin%d_as_nc11', base, c_min),     'current',  'floor',  sprintf('Current value, floor EUR %d', c_min)
     sprintf('%s_as_nc11', base),                   'current',  'topup',  'Current value, top-up 1e-6'};
R = cell(1, size(C, 1));
for i = 1:size(C, 1)
    R{i} = case_load(16, 'owner', C{i, 1});
    assert(~isempty(R{i}), 'floor_rule_dashboards:missing', '%s is not solved.', C{i, 1});
    file = fullfile(out, sprintf('16_base_owner_%s_%s.png', C{i, 2}, C{i, 3}));
    figures.dashboard(R{i}, file);
    close all
    fprintf('Wrote %s\n', file);
end
file = fullfile(out, '16_base_owner_floor_rules.png');
figures.compare(R, C(:, 4).', 'Owner, base grid: maintenance rule and floor', file);
close all
fprintf('Wrote %s\n', file);
fprintf('\n%-36s %8s %8s %8s %8s %9s %9s\n', '', 'minutes', 'C at 30', 'C at 70', 'peak X', 'bkr/fl 85', 'entry');
for i = 1:numel(R)
    s = R{i}.summary; a = s.ages;
    fprintf('%-36s %8.0f %8.3f %8.3f %8.2f %8.1f%% %9.4f\n', C{i, 4}, R{i}.timing.solve_sec / 60, ...
        s.C.p50(a == 30) / s.Y0, s.C.p50(a == 70) / s.Y0, max(s.X.mean) / s.Y0, 100 * s.floored(a == 85), ...
        R{i}.checks.ce_entry);
end
end

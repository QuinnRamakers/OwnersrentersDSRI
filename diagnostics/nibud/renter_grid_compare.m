function renter_grid_compare(case_name)
%RENTER_GRID_COMPARE  Step-16 renter: the summary grid against larger grids.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       renter_grid_compare                 % the renter grid of maint_dashboards
%
%   Uses the solves of the 18 October grid study, all bunched (power 3) with
%   the limit share and the global sweep: 32x32 and 48x48 with u3 at 10 points,
%   16x16 with u3 at 10 and 40. The summary grid is 16x16 with u3 at 20. q is
%   not a state for renters. Writes, in summary_step16/ next to the ladder
%   results:
%     16_renter_grid_vs_48x48.png   the summary grid against 48x48, each with its band
%     16_renter_grid_ladder.png     every grid on one page, 48x48 as the reference
%   and prints policy_gaps by age band against 48x48 (finer u1 and u2) and
%   against 16x16 with u3 at 40 (finer u3).

arguments
    case_name (1,:) char = 'pow3_16x16_lim_u3p2_u3n20'
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end

cases  = {'pow3_48x48_lim_u3p2', case_name, 'pow3_16x16_lim_u3p2', ...
          'pow3_32x32_lim_u3p2', 'pow3_16x16_lim_u3p2_u3n40'};
labels = {'48x48', '16x16, u3 20, the summary grid', '16x16, u3 10', '32x32', '16x16, u3 40'};
rs = cellfun(@(c) case_load(16, 'renter', c), cases, 'UniformOutput', false);
assert(all(~cellfun(@isempty, rs)), 'renter_grid_compare:missing', 'a case is not solved.');

notes = {'All grids bunched (power 3), limit share, sweep on', ...
         '48x48 and 32x32: u3 at 10 points; the summary grid: u3 at 20', ...
         'q is not a state for renters', 'Same households and seed'};
figures.step_dashboard(rs{1}, rs{2}, labels(1:2), ...
    'Step 16, renter: the summary grid against 48x48', ...
    fullfile(out, '16_renter_grid_vs_48x48.png'), changes = notes, ...
    colours = [0 0 0; 0.45 0.20 0.55]);
figures.compare(rs, labels, 'Step 16, renter: the summary grid against larger grids', ...
    fullfile(out, '16_renter_grid_ladder.png'));
close all

bands = {[26 39], [40 54], [55 66], [67 89], [90 95]};
head = sprintf('%-32s', 'consumption % / share');
for b = bands, head = [head sprintf('  %5d-%-5d', b{1}(1), b{1}(2))]; end %#ok<AGROW>
fprintf('\nPolicies at the households of 48x48\n%s\n', head);
for i = 2:4
    fprintf('%-32s%s\n', labels{i}, gap_row(policy_gaps(rs{i}, rs{1}, bands)));
end
fprintf('\nPolicies at the households of 16x16 with u3 at 40\n%s\n', head);
for i = 2:3
    fprintf('%-32s%s\n', labels{i}, gap_row(policy_gaps(rs{i}, rs{5}, bands)));
end

fprintf('\n%-32s %5s %8s %8s %8s %6s %8s\n', '', 'age', 'C/Y0', 'X/Y0', 'NW/Y0', 'pi', 'floored');
for i = 1:numel(rs)
    s = rs{i}.summary; a = s.ages;
    for age = [30 40 55 66 80 95]
        m = a == age;
        fprintf('%-32s %5d %8.2f %8.2f %8.2f %6.2f %7.1f%%\n', labels{i}, age, s.C.p50(m) / s.Y0, ...
            s.X.mean(m) / s.Y0, s.net_worth.mean(m) / s.Y0, s.pi(m), 100 * s.floored(m));
    end
end
for i = 1:numel(rs)
    c = rs{i}.checks;
    fprintf('%-32s floored %.2f%%  entry %.3f  off-grid %s\n', labels{i}, 100 * c.floored_share, ...
        c.ce_entry, mat2str(c.offgrid));
end
end

function s = gap_row(G)
s = '';
for k = 1:numel(G.C)
    s = [s sprintf('  %5.1f/%5.3f', 100 * G.C(k), G.pi(k))]; %#ok<AGROW>
end
end

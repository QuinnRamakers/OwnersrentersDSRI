function maint_grid_compare(case_name)
%MAINT_GRID_COMPARE  Step-16 owner, maintenance on the current value: the summary grid against larger ones.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       maint_grid_compare                  % the grid of maint_dashboards
%
%   Uses the solves of the 18 October grid study, all bunched (power 3) with
%   the limit share: 20x20 and 32x32 with q at 8 points, 24x24 with q at 4, and
%   24x24 with q at 4 and u3 at 20 points instead of 10. They were solved with
%   the global sweep; the summary grid without it. Writes, in summary_step16/
%   next to the ladder results:
%     16_owner_grid_vs_32x32.png   the summary grid against 32x32, each with its band
%     16_owner_grid_ladder.png     every grid on one page, 32x32 as the reference
%   and prints policy_gaps by age band: each grid's policies at the reference's
%   households, which leaves out wealth carried in from younger ages.

arguments
    case_name (1,:) char = 'pow3_16x16_lim_u3p2_qn4_nosweep'
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end

cases  = {'pow3_32x32_lim_u3p2', case_name, 'pow3_20x20_lim_u3p2', ...
          'pow3_24x24_lim_u3p2_qn4', 'pow3_24x24_lim_u3p2_qn4_u3n20'};
labels = {'32x32', '16x16, the summary grid', '20x20', '24x24', '24x24, u3 at 20 points'};
rs = cellfun(@(c) case_load(16, 'owner', c), cases, 'UniformOutput', false);
assert(all(~cellfun(@isempty, rs)), 'maint_grid_compare:missing', 'a case is not solved.');
assert(~any(cellfun(@(r) r.p.maint_on_purchase, rs)), 'maint_grid_compare:rule', ...
    'every case must charge maintenance on the current value.');

notes = {'Maintenance on the current house value', ...
         'All grids bunched (power 3), limit share, u3 at 10 points unless named', ...
         '32x32 and 20x20: q at 8 points; 24x24 and 16x16: q at 4 (equal to 8 at this step)', ...
         'Summary grid solved without the global sweep, the others with it', ...
         'Same households and seed'};
figures.step_dashboard(rs{1}, rs{2}, labels(1:2), ...
    'Step 16, owner, maintenance on the current value: the summary grid against 32x32', ...
    fullfile(out, '16_owner_grid_vs_32x32.png'), changes = notes);
figures.compare(rs, labels, ...
    'Step 16, owner, maintenance on the current value: the summary grid against larger grids', ...
    fullfile(out, '16_owner_grid_ladder.png'));
close all

bands = {[26 39], [40 54], [55 66], [67 89], [90 95]};
head = sprintf('%-28s', 'consumption % / share');
for b = bands, head = [head sprintf('  %5d-%-5d', b{1}(1), b{1}(2))]; end %#ok<AGROW>
fprintf('\nPolicies at the households of 32x32\n%s\n', head);
for i = 2:numel(rs)
    G = policy_gaps(rs{i}, rs{1}, bands);
    fprintf('%-28s%s\n', labels{i}, gap_row(G));
end
fprintf('\nPolicies at the households of 24x24 with u3 at 20 points\n%s\n', head);
for i = [2 4]
    G = policy_gaps(rs{i}, rs{5}, bands);
    fprintf('%-28s%s\n', labels{i}, gap_row(G));
end

fprintf('\n%-28s %5s %8s %8s %8s %6s %8s\n', '', 'age', 'C/Y0', 'X/Y0', 'NW/Y0', 'pi', 'floored');
for i = 1:numel(rs)
    s = rs{i}.summary; a = s.ages;
    for age = [30 40 55 66 80 95]
        m = a == age;
        fprintf('%-28s %5d %8.2f %8.2f %8.2f %6.2f %7.1f%%\n', labels{i}, age, s.C.p50(m) / s.Y0, ...
            s.X.mean(m) / s.Y0, s.net_worth.mean(m) / s.Y0, s.pi(m), 100 * s.floored(m));
    end
end
for i = 1:numel(rs)
    c = rs{i}.checks;
    fprintf('%-28s floored %.2f%%  entry %.3f  off-grid %s\n', labels{i}, 100 * c.floored_share, ...
        c.ce_entry, mat2str(c.offgrid));
end
end

function s = gap_row(G)
s = '';
for k = 1:numel(G.C)
    s = [s sprintf('  %5.1f/%5.3f', 100 * G.C(k), G.pi(k))]; %#ok<AGROW>
end
end

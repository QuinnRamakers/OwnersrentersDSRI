function maint_dashboards(case_name, renter_case)
%MAINT_DASHBOARDS  Step 16 with maintenance on the current value and on the purchase price.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       maint_dashboards                    % the cases solved on 20 October 2026
%       maint_dashboards('pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_16x16_lim_u3p2_u3n20')
%
%   The owner is solved twice on one grid with solve_cases, as case_name and
%   case_name with _mop; only the maintenance rule differs. The renter pays rent
%   and no maintenance, so one renter solve serves both. Writes, in
%   summary_step16/ next to the ladder results:
%     16_owner_maint_current.png        dashboard, maintenance on the current value
%     16_owner_maint_purchase.png       dashboard, maintenance on the purchase price
%     16_renter.png                     dashboard of the renter
%     16_owner_current_vs_purchase.png  the two owners on one page
%     16_renter_vs_owner_current.png    renter and owner, current value
%     16_renter_vs_owner_purchase.png   renter and owner, purchase price
%   and prints a table of the main quantities at a few ages.

arguments
    case_name (1,:) char = 'pow3_16x16_lim_u3p2_qn4_nosweep'
    renter_case (1,:) char = 'pow3_16x16_lim_u3p2_u3n20'
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end

cur = case_load(16, 'owner', case_name);
pur = case_load(16, 'owner', [case_name '_mop']);
ren = case_load(16, 'renter', renter_case);
assert(~isempty(cur) && ~isempty(pur) && ~isempty(ren), 'maint_dashboards:missing', ...
    'solve the cases first (solve_cases).');
assert(~cur.p.maint_on_purchase && pur.p.maint_on_purchase, 'maint_dashboards:rule', ...
    'the two owner cases must differ in maint_on_purchase.');

lc = 'owner, maintenance on current value';
lp = 'owner, maintenance on purchase price';
lr = 'renter';
grids = {sprintf('Owner grid %s (_mop for purchase price)', case_name), ...
         sprintf('Renter grid %s', renter_case)};
owner_col = [0.20 0.60 0.30]; renter_col = [0.45 0.20 0.55];

% Grid-study solves carry no step; the dashboard title reads it from r.step
cur.step = struct('number', '16', 'label', 'Nibud house, maintenance on the current value');
pur.step = struct('number', '16', 'label', 'Nibud house, maintenance on the purchase price');
ren.step = struct('number', '16', 'label', 'Nibud house');

figures.dashboard(cur, fullfile(out, '16_owner_maint_current.png'));
figures.dashboard(pur, fullfile(out, '16_owner_maint_purchase.png'));
figures.dashboard(ren, fullfile(out, '16_renter.png'));
figures.step_dashboard(cur, pur, {lc, lp}, ...
    'Step 16, owner: maintenance on the current value against the purchase price', ...
    fullfile(out, '16_owner_current_vs_purchase.png'), ...
    changes = {'maint_on_purchase: false -> true', ...
               'Maintenance 1.5% of the purchase price instead of the current house value', ...
               'Same grid, households and seed', grids{1}});
figures.step_dashboard(ren, cur, {lr, lc}, ...
    'Step 16: renter and owner, maintenance on the current value', ...
    fullfile(out, '16_renter_vs_owner_current.png'), colours = [renter_col; owner_col], changes = grids);
figures.step_dashboard(ren, pur, {lr, lp}, ...
    'Step 16: renter and owner, maintenance on the purchase price', ...
    fullfile(out, '16_renter_vs_owner_purchase.png'), colours = [renter_col; owner_col], changes = grids);
close all

rs = {cur, pur, ren};
names = {'owner, current value', 'owner, purchase price', 'renter'};
fprintf('\n%-24s %5s %8s %8s %8s %8s %6s %8s\n', '', 'age', 'C/Y0', 'X/Y0', 'NW/Y0', 'DC/Y0', 'pi', 'floored');
for i = 1:3
    s = rs{i}.summary; a = s.ages;
    for age = [25 35 45 55 66 75 85 95]
        m = a == age;
        if ~any(m), continue; end
        fprintf('%-24s %5d %8.2f %8.2f %8.2f %8.2f %6.2f %7.1f%%\n', names{i}, age, ...
            s.C.p50(m) / s.Y0, s.X.mean(m) / s.Y0, s.net_worth.mean(m) / s.Y0, ...
            s.A.mean(m) / s.Y0, s.pi(m), 100 * s.floored(m));
    end
end
for i = 1:3
    c = rs{i}.checks;
    fprintf('%-24s solve %5.0f s  floored %.2f%%  entry %.3f  c-bound 25-39 %.1f%%  off-grid %s  thin u1 %.2f\n', ...
        names{i}, rs{i}.timing.solve_sec, 100 * c.floored_share, c.ce_entry, 100 * c.c_bound_25_39, ...
        mat2str(c.offgrid), c.thin_u1_40);
end
end

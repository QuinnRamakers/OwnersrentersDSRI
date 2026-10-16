function export_dashboard(out)
%EXPORT_DASHBOARD  The grid study's numbers as JSON rows for the dashboard.
%
%   export_dashboard('C:/somewhere')
%
%   Writes four files into out, from the saved solves of the grid study
%   (case_load) at standard numerics:
%     paths.json        by step (6, 9-12), household, grid and age: mean
%                       consumption, gross income, liquid savings and DC pot
%                       (thousand EUR of 2025), the equity share of liquid
%                       saving weighted by saving (share_savers) and the mean
%                       share (share_mean)
%     convergence.json  by step, household and grid: case_gaps against the
%                       step's finest grid (reference), and the signed %
%                       differences in liquid savings at 60 and consumption at 66
%     occupancy.json    by step, household and age: percentiles 5/25/50/75/95 of
%                       total resources over income and of the liquid share
%                       (1 - u2), from the finest bunched grid's panel (evenly
%                       spaced 64x64 for step 6)
%     gridpoints.json   the u1 and u2 points of the old grid and the bunched
%                       grids at 16x16 and 48x48
%   The dashboard is the claude.ai artifact "Pension grid study".

dc = {'standard', 'uniform_32x32', 'uniform_64x64', 'uniform_16x16_lim', 'pow3_16x16_lim', ...
      'pow3_32x32_lim', 'pow3_48x48_lim', 'pow3_64x64_lim'};
cases = struct('s6', {{'standard', 'uniform_32x32', 'uniform_64x64', 'uniform_128x128', ...
                       'pow3_16x16_lim', 'pow3_32x32_lim'}}, ...
               's9', {dc}, 's10', {[dc, {'pow3_96x96_lim'}]}, 's11', {dc}, 's12', {dc});
refs = struct('s6', 'uniform_128x128', 's9', 'pow3_64x64_lim', 's10', 'pow3_96x96_lim', ...
              's11', 'pow3_64x64_lim', 's12', 'pow3_64x64_lim');
occ_from = struct('s6', 'uniform_64x64', 's9', 'pow3_64x64_lim', 's10', 'pow3_64x64_lim', ...
                  's11', 'pow3_64x64_lim', 's12', 'pow3_64x64_lim');
rd = @(v, d) round(v * 10^d) / 10^d;

P = {}; G = {}; O = {};
for st = [6 9 10 11 12]
    key = sprintf('s%d', st);
    for arm = {'renter', 'owner'}
        a = arm{1};
        ref = case_load(st, a, refs.(key));
        for c = cases.(key)
            r = case_load(st, a, c{1});
            if isempty(r), continue; end
            s = r.summary; ages = s.ages;
            for t = 1:numel(ages)
                P{end+1} = struct('step', st, 'arm', a, 'grid', c{1}, 'age', ages(t), ...
                    'consumption', rd(s.C.mean(t) / 1e3, 3), 'income', rd(s.Y.mean(t) / 1e3, 3), ...
                    'liquid', rd(s.X.mean(t) / 1e3, 3), 'pension', rd(s.A.mean(t) / 1e3, 3), ...
                    'share_savers', rd(r.piw(t), 4), 'share_mean', rd(s.pi(t), 4)); %#ok<AGROW>
            end
            g = case_gaps(r, ref);
            i66 = ages == 66; i60 = ages == 60;
            fam = 'uniform';
            if startsWith(c{1}, 'pow3'), fam = 'power3'; end
            if strcmp(c{1}, 'uniform_16x16_lim'), fam = 'limit16'; end
            G{end+1} = struct('step', st, 'arm', a, 'grid', c{1}, 'family', fam, ...
                'reference', refs.(key), 'points', r.p.N_u1 * r.p.N_u2, ...
                'solve_s', round(r.timing.solve_sec), ...
                'c_gap_40_66', rd(100 * g.C(2), 2), 'c_gap_67_95', rd(100 * g.C(3), 2), ...
                'x_gap_40_66', rd(g.X(2), 3), 'x_gap_67_95', rd(g.X(3), 3), ...
                'share_gap_40_66', rd(g.piw(2), 4), 'share_gap_67_95', rd(g.piw(3), 4), ...
                'c66_pct', rd(100 * (s.C.mean(i66) / ref.summary.C.mean(i66) - 1), 2), ...
                'x60_pct', rd(100 * (s.X.mean(i60) / ref.summary.X.mean(i60) - 1), 2)); %#ok<AGROW>
        end
        sim = figures.panel_data(case_load(st, a, occ_from.(key))).sim;
        wy  = 1 ./ sim.lambda;
        liq = 1 - (sim.sA + sim.sH) ./ max(1 - sim.lambda, 1e-12);
        for t = 1:numel(sim.ages)
            pw = prctile(wy(:, t), [5 25 50 75 95]);
            pl = prctile(max(liq(:, t), 1e-4), [5 25 50 75 95]);
            O{end+1} = struct('step', st, 'arm', a, 'age', sim.ages(t), ...
                'wy_p5', rd(pw(1), 3), 'wy_p25', rd(pw(2), 3), 'wy_p50', rd(pw(3), 3), ...
                'wy_p75', rd(pw(4), 3), 'wy_p95', rd(pw(5), 3), ...
                'liq_p5', rd(pl(1), 5), 'liq_p25', rd(pl(2), 5), 'liq_p50', rd(pl(3), 5), ...
                'liq_p75', rd(pl(4), 5), 'liq_p95', rd(pl(5), 5)); %#ok<AGROW>
        end
    end
end

Q = {};
for gname = {'standard', 'pow3_16x16_lim', 'pow3_48x48_lim'}
    p = case_params(12, 'owner', strrep(gname{1}, 'standard', 'uniform_16x16'));
    for v = p.u1_grid(:).'
        Q{end+1} = struct('grid', gname{1}, 'axis', 'resources_over_income', 'value', rd(1 / v, 4)); %#ok<AGROW>
    end
    for v = p.u2_grid(:).'
        if v < 1
            Q{end+1} = struct('grid', gname{1}, 'axis', 'liquid_share', 'value', rd(1 - v, 6)); %#ok<AGROW>
        end
    end
end

if ~isfolder(out), mkdir(out); end
put(fullfile(out, 'paths.json'), P); put(fullfile(out, 'convergence.json'), G);
put(fullfile(out, 'occupancy.json'), O); put(fullfile(out, 'gridpoints.json'), Q);
fprintf('paths %d, convergence %d, occupancy %d, gridpoints %d rows in %s\n', ...
    numel(P), numel(G), numel(O), numel(Q), out);
end

function put(file, rows)
fid = fopen(file, 'w');
fwrite(fid, jsonencode([rows{:}]));
fclose(fid);
end

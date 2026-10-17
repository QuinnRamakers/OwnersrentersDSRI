function start_vs_grid()
%START_VS_GRID  Step 16 against step 15: the starting house against the grid.
%
%   From the repository root, after ladder.run([15 16]) at standard numerics:
%       addpath diagnostics/nibud; start_vs_grid
%
%   h_mult enters the solve only through the grid (the top of the u1 axis and
%   the entry nodes), so steps 15 and 16 solve the same problem on two grids.
%   Each saved solution is simulated again from both starting houses, with the
%   seed and panel size of the ladder run. On one solution, the difference
%   between the two starts is the effect of the starting house. From one
%   start, the difference between the two solutions is the grid's.
%
%   Writes, next to the ladder results, in nibud/:
%     start_<step>_<tenure>.png   solution of that step, 4x start against the Nibud start
%     grid_<start>_<tenure>.png   one start, solution 15 against solution 16

num = ladder.numerics('standard');
out = fullfile(num.dir, 'nibud');
if ~isfolder(out), mkdir(out); end
L15 = ladder.load(15, 'standard');
L16 = ladder.load(16, 'standard');

for tenure = {'owner', 'renter'}
    t = tenure{1};
    sols = {L15.(t), L16.(t)};
    step = {'15', '16'};
    h = [sols{1}.p.h_mult, sols{2}.p.h_mult];
    start = {sprintf('%.2fx', h(1)), sprintf('%.2fx', h(2))};
    R = cell(2, 2);                         % R{solution, start}
    for i = 1:2
        for j = 1:2
            R{i, j} = resimulate(sols{i}, h(j));
        end
    end
    % The re-simulation on its own solution and start reproduces the saved panel
    for i = 1:2
        assert(isequaln(R{i, i}.summary.C.mean, sols{i}.summary.C.mean), ...
            '%s: re-simulating step %s does not reproduce the saved panel', t, step{i});
    end

    for i = 1:2
        figures.step_dashboard(R{i, 1}, R{i, 2}, ...
            {sprintf('start %s', start{1}), sprintf('start %s', start{2})}, ...
            sprintf('%s: starting house %s against %s, both on the solution of step %s', ...
                t, start{2}, start{1}, step{i}), ...
            fullfile(out, sprintf('start_%s_%s.png', step{i}, t)), ...
            changes = {sprintf('Same solution (step %s, its grid); only the starting house differs.', step{i}), ...
                       'The difference is the effect of the starting house.'});
    end
    for j = 1:2
        figures.step_dashboard(R{1, j}, R{2, j}, ...
            {'solution 15', 'solution 16'}, ...
            sprintf('%s: solution of step 16 against step 15, both from a start of %s', t, start{j}), ...
            fullfile(out, sprintf('grid_%s_%s.png', strrep(start{j}, '.', 'p'), t)), ...
            changes = {sprintf('Same starting house (%s); only the grid differs.', start{j}), ...
                       'The difference is numerical, not economic.'});
    end
    print_gaps(t, R, start);
end
end

function r = resimulate(r, h)
% Simulate a saved solution again from a starting house of h times income.
% p keeps the grid the solution was solved on; only the entry state moves.
p = r.p;
p.h_mult = h;
[~, shocks] = config.model_inputs(p);
sim = simulate.forward(p, r.profile, r.sol, r.ann_price, r.timing.N_sim, r.timing.seed, p.b0);
r.p = p;
r.summary = model.summarize(p, sim);
r.checks = model.checks(p, r.sol, sim, r.summary, r.profile, shocks);
end

function print_gaps(t, R, start)
% Mean consumption and liquid equity share: the starting-house effect on each
% solution, and the grid effect from each start, at a few ages.
ages = [30 40 50 55 56 60 66 70 75 80 85];
a = R{1, 1}.summary.ages;
pick = @(v) v(ismember(a, ages));
C  = @(r) pick(r.summary.C.mean);
PI = @(r) pick(r.summary.pi);
pct = @(x, y) 100 * (y ./ x - 1);
fprintf('\n%s: %% change in mean consumption, and change in the liquid equity share\n', t);
fprintf('%-34s', 'age'); fprintf('%7d', ages); fprintf('\n');
row = @(name, v, f) fprintf(['%-34s' repmat(f, 1, numel(v)) '\n'], name, v);
row(sprintf('start %s vs %s, solution 15', start{2}, start{1}), pct(C(R{1,1}), C(R{1,2})), '%7.1f');
row(sprintf('start %s vs %s, solution 16', start{2}, start{1}), pct(C(R{2,1}), C(R{2,2})), '%7.1f');
row(sprintf('grid 16 vs 15, start %s', start{1}), pct(C(R{1,1}), C(R{2,1})), '%7.1f');
row(sprintf('grid 16 vs 15, start %s', start{2}), pct(C(R{1,2}), C(R{2,2})), '%7.1f');
row('  equity share: start, solution 15', PI(R{1,2}) - PI(R{1,1}), '%7.2f');
row('  equity share: start, solution 16', PI(R{2,2}) - PI(R{2,1}), '%7.2f');
row(sprintf('  equity share: grid, start %s', start{1}), PI(R{2,1}) - PI(R{1,1}), '%7.2f');
row(sprintf('  equity share: grid, start %s', start{2}), PI(R{2,2}) - PI(R{1,2}), '%7.2f');
for i = 1:2
    for j = 1:2
        fprintf('  solution %d, start %s: entry value %.3f, floored %.2f%%\n', 14 + i, start{j}, ...
            R{i, j}.checks.ce_entry, 100 * R{i, j}.checks.floored_share);
    end
end
end

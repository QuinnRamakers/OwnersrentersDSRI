% Weekend of 27-30 November 2026, step 24 (production) renters. First the
% low-consumption years of the standard-grid solve (tail_states), then solves
% on other grids (grid_study, 100,000 households, seed 303): the standard grid
% in z and log z, one axis refined at a time, the production grid, and one
% large grid. Run from the repository root with diagnostics/value_gap on the
% path. The solutions are not kept (disk).
src = '/Solutionstorage/OwnersrentersDSRI_gap/neural/data';
r = load(fullfile(src, 'solve_24_renter_standard.mat')).r;
tail = tail_states(r, N = 20000, cut = 0.05);
rules = compare_rules(r, N = 100000, seed = 303, rules = ["grid", "boundary"]);
save(fullfile(utility.output_dir(), 'value_gap', 'tail_24_renter_standard.mat'), 'tail', 'rules');
clear r tail rules
lz = struct('interp_space', 'logz');
cases = { ...
    {24, 'renter', [16 16 10 8], 5, 'share'}, {24, 'renter', [16 16 10 8], 5, 'share', lz}, ...
    {24, 'renter', [64 16 10 8], 5, 'share'}, {24, 'renter', [16 48 10 8], 5, 'share'}, {24, 'renter', [16 16 40 8], 5, 'share'}, ...
    {24, 'renter', [64 16 10 8], 5, 'share', lz}, {24, 'renter', [16 48 10 8], 5, 'share', lz}, {24, 'renter', [16 16 40 8], 5, 'share', lz}, ...
    {24, 'renter', [32 16 40 4], 5, 'share'}, {24, 'renter', [32 16 40 4], 5, 'share', lz}, ...
    {24, 'renter', [128 32 80 4], 5, 'share'}, {24, 'renter', [128 32 80 4], 5, 'share', lz}};
grid_study(cases, tag = 'weekend24');

% Weekend of 27-30 November 2026, step 24 (production) owners. As
% weekend24_renter: the low-consumption years of the standard-grid solve,
% then the standard grid in z and log z, one axis refined at a time (q, u1,
% u3, u2), the production grid, and last the large grid [64 16 40 16]
% (66x18x40x17 nodes, 28 times the standard grid).
src = '/Solutionstorage/OwnersrentersDSRI_gap/neural/data';
r = load(fullfile(src, 'solve_24_owner_standard.mat')).r;
tail = tail_states(r, N = 20000, cut = 0.05);
rules = compare_rules(r, N = 100000, seed = 303, rules = ["grid", "boundary"]);
save(fullfile(utility.output_dir(), 'value_gap', 'tail_24_owner_standard.mat'), 'tail', 'rules');
clear r tail rules
lz = struct('interp_space', 'logz');
cases = { ...
    {24, 'owner', [16 16 10 8], 5, 'share'}, {24, 'owner', [16 16 10 8], 5, 'share', lz}, ...
    {24, 'owner', [16 16 10 32], 5, 'share'}, {24, 'owner', [64 16 10 8], 5, 'share'}, ...
    {24, 'owner', [16 16 40 8], 5, 'share'}, {24, 'owner', [16 48 10 8], 5, 'share'}, ...
    {24, 'owner', [32 16 40 4], 5, 'share'}, {24, 'owner', [32 16 40 4], 5, 'share', lz}, ...
    {24, 'owner', [64 16 40 16], 5, 'share'}};
grid_study(cases, tag = 'weekend24');

function solve_cases(opts)
%SOLVE_CASES  The solves behind the step-7 diagnosis.
%
%   solve_cases()                       every case below (about 25 minutes)
%   solve_cases(cases="owner_floor_020")
%   solve_cases(cases="owner_floor_020", grids={[8 6 6], [10 6 6]}, gh_n=3, out=tempdir)
%
%   Each case is step 7 (ladder.params(7)) with the primitives listed below
%   changed, solved at standard numerics with N_sim = 10000 on the standard
%   grid and with the income axis doubled, or on the one grid given. Results
%   are saved as <out>/<case>.mat with fields std and dense, or r for a single
%   grid. Step 7 as run and its doubled-income-axis solve come from
%   ladder.run(7) and ladder.robustness(7).

arguments
    opts.cases (1,:) string = string.empty
    opts.grids cell = {[16 16 10], [32 16 10]}
    opts.gh_n (1,1) double = 5
    opts.out (1,:) char = ''
end

P = step07_paths();
cd(P.repo);
out = opts.out; if isempty(out), out = P.data; end
if ~isfolder(out), mkdir(out); end
setenv('CGM_OUTPUT_DIR', ''); setenv('CGM_STATE_GRID', ''); setenv('CGM_GH_N', '');

%  name                   owner  changed primitives                                 grids
C = {
  'owner_flat_prices',    true,  struct('mu_H_level', 0, 'sigma_H_level', 0.001), {}
  'owner_no_maintenance', true,  struct('theta', 0),                              {}
  'owner_no_growth',      true,  struct('mu_H_level', 0),                         {}
  'owner_floor_010',      true,  struct('phi_floor', 0.1),                        {}
  'owner_floor_020',      true,  struct('phi_floor', 0.2),                        {}
  'owner_floor_030',      true,  struct('phi_floor', 0.3),                        {}
  'owner_floor_050',      true,  struct('phi_floor', 0.5),                        {}
  'renter_floor_010',     false, struct('phi_floor', 0.1),                        {}
  'renter_u2_doubled',    false, struct(),                                        {[16 32 10]}
  'renter_both_doubled',  false, struct(),                                        {[32 32 10]}
  };
bad = setdiff(opts.cases, string(C(:, 1)));
assert(isempty(bad), 'solve_cases:name', 'unknown case: %s', strjoin(bad, ', '));

for c = 1:size(C, 1)
    name = C{c, 1};
    if ~isempty(opts.cases) && ~any(opts.cases == name), continue; end
    G = C{c, 4}; if isempty(G), G = opts.grids; end
    R = cell(1, numel(G));
    for g = 1:numel(G)
        p = ladder.params(7); p.is_owner = C{c, 2};
        f = fieldnames(C{c, 3});
        for i = 1:numel(f), p.(f{i}) = C{c, 3}.(f{i}); end
        p.grid_dims = G{g}; p.gh_n = opts.gh_n; p = config.derive(p);
        R{g} = model.run(p, N_sim = 10000, verbose = false);
        k = R{g}.checks;
        fprintf('%-22s grid %-10s solve %4.0f s  floored %.4f  c_bound %.4f  offgrid %d  entry %.3f\n', name, ...
            mat2str(G{g}), R{g}.timing.solve_sec, k.floored_share, k.c_bound_25_39, sum(k.offgrid), k.ce_entry);
    end
    s = struct();
    if isscalar(R), s.r = R{1}; else, s.std = R{1}; s.dense = R{2}; end
    save(fullfile(out, [name '.mat']), '-struct', 's');
end
end

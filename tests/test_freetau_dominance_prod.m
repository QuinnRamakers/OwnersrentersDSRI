% TEST_FREETAU_DOMINANCE_PROD  Production-grid welfare-loss test for the
% individually-optimal DC equity share.
%
%   Theory: letting each household set the DC equity share tau to its own
%   individually optimal value (choose_tau_S=true) must weakly DOMINATE the
%   mechanical glide path -- at every state, free choice can replicate the
%   glide slice, so it can never do worse. This checks that property on the
%   actual PRODUCTION solves (utility.production_grid), per-state across the
%   whole value function (not just the initial node), and reports the CEV of
%   the welfare change. PASS if no state loses more than 1e-4 CEV.
%
%   cev(state,t) = (V_free / V_glide)^(1/(1-gamma)) - 1
%   > 0 : free choice raises welfare;  ~0 : indifferent;  < 0 : loss.

% Read the arms from wherever the runners wrote them. This used to derive the
% directory from the script's own location, which meant it ignored
% CGM_OUTPUT_DIR and tested nothing on a cluster run whose outputs went to the
% mounted volume -- and it broke outright once this file moved into tests/.
res_dir = utility.output_dir();

% Dominance is a property of BOTH coordinate systems -- the cube's free-tau
% branch keeps the glide value in its seed grid and polishes from it pinned,
% exactly as the simplex does, and tests/smoke_freetau_dominance_lna checks
% that at the Bellman-step level. This checks it on whichever pair of solved
% production files the active grid names.
gs = utility.grid_suffix();
pairs = {'renter', sprintf('combined_renter%s.mat', gs), ...
                   sprintf('combined_renter_freetau%s.mat', gs); ...
         'owner',  sprintf('combined_owner%s.mat', gs), ...
                   sprintf('combined_owner_freetau%s.mat', gs)};

n_fail = 0;   % accumulated across tenures; raised as an error at the end so
              % tests/run_all sees the failure instead of only the printout

for i = 1:size(pairs, 1)
    G = load(fullfile(res_dir, pairs{i, 2}), 'sol', 'p');
    F = load(fullfile(res_dir, pairs{i, 3}), 'sol', 'p');
    gamma = G.p.gamma;
    Vg = G.sol.V; Vf = F.sol.V;

    mask = isfinite(Vg) & isfinite(Vf) & Vg > -1e14 & Vf > -1e14;
    cev  = (Vf(mask) ./ Vg(mask)).^(1/(1-gamma)) - 1;
    n_bad = nnz(cev < -1e-4);

    fprintf('\n=== %s: free (individually optimal tau) vs glide ===\n', pairs{i, 1});
    fprintf('  comparable states : %d\n', nnz(mask));
    fprintf('  min cev           : %+.3e  (worst welfare change)\n', min(cev));
    fprintf('  median cev        : %+.3e\n', median(cev));
    fprintf('  max cev           : %+.3e\n', max(cev));
    fprintf('  mean cev          : %+.3e\n', mean(cev));
    fprintf('  states losing >1e-4 CEV: %d\n', n_bad);
    if n_bad == 0
        fprintf('  RESULT: PASS -- no household suffers a welfare loss from free tau choice.\n');
    else
        fprintf('  RESULT: FAIL -- %d states with a welfare loss (optimizer shortfall).\n', n_bad);
        cs = sort(cev);
        fprintf('  worst 5 cev: '); fprintf('%+.3e ', cs(1:min(5,end))); fprintf('\n');
        n_fail = n_fail + 1;
    end
end

if n_fail > 0
    error('test_freetau_dominance_prod:fail', ...
          '%d tenure(s) show a welfare loss from free tau choice.', n_fail);
end

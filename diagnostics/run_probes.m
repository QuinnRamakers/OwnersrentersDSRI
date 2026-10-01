% RUN_PROBES  Counterfactuals against the two suspects for an indeterminate pi.
%
%   The ladder (run_ablation) locates which feature moves pi. This asks whether
%   either suspect is actually responsible, by re-running selected rungs with
%   one thing changed:
%
%     base    the ladder rungs that matter, re-run to pick up the
%             liquid-wealth-weighted pi that the first pass did not record.
%     offset  the same rungs with a symmetric CGT (losses rebated). If the
%             no-loss-offset rule is what flattens the equity choice, the
%             age profile should steepen back toward the CGM shape here.
%     floor   the consumption floor raised from 1e-6 to 0.2 of current gross
%             income. If the value cliff at low liquid wealth is what makes
%             retirement pi jump around, retirement roughness should fall.
%             Not 1: phi_floor multiplies CURRENT gross income, so 1 floors
%             consumption at the whole wage during working life and forces
%             C = Y with no saving at all. 0.2 is a real subsistence floor
%             that still leaves the life-cycle problem intact.
%
%   Written for matlab -batch. Results land in diagnostics/ablation_<tag>.mat.

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here);
cd(fileparts(here));

G = struct('dims', [16 12 10], 'gh_n', 5, 'gh_n_reit', 3, 'N_sim', 4000);

fprintf('\n################ BASE (wealth-weighted pi added) ################\n');
o = G; o.tag = 'base';
run_ablation([0 4 5 6], o);

fprintf('\n################ PROBE: symmetric CGT (loss offset) ################\n');
o = G; o.tag = 'offset'; o.cg_loss_offset = true;
run_ablation([5 6], o);

fprintf('\n################ PROBE: consumption floor at 0.2 of income ################\n');
o = G; o.tag = 'floor'; o.phi_floor = 0.2;
run_ablation([0 5], o);

fprintf('\nAll probes done.\n');

function step16_lifecycles()
%STEP16_LIFECYCLES  Life cycles at step 16 as each axis of the grid is refined.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       step16_lifecycles
%
%   Draws grid_lifecycles for the cases of the step-16 grid-size study
%   (HANDOFF.md, 18 October 2026): one figure per tenure, a row for u1 x u2
%   (u3 at 10 points) and a row for u3. The ladder's evenly spaced grid is the
%   grey dashed line. Writes lifecycles_16_<tenure>.png into the grid study's
%   results folder.

num = ladder.numerics('standard');
out = fullfile(num.dir, 'pension_grid');

o(1).name = 'u1 x u2 (u3 10, q 8)';
o(1).cases = {'pow3_20x20_lim_u3p2', 'pow3_24x24_lim_u3p2', 'pow3_32x32_lim_u3p2'};
o(1).labels = {'20x20', '24x24', '32x32'};
o(1).extra = 'standard'; o(1).extra_label = 'ladder grid, evenly spaced 16x16';
o(2).name = 'u3 points (24x24)';
o(2).cases = {'pow3_24x24_lim_u3p2_u3n6', 'pow3_24x24_lim_u3p2_qn4_u3n8', ...
              'pow3_24x24_lim_u3p2_qn4', 'pow3_24x24_lim_u3p2_qn4_u3n20'};
o(2).labels = {'u3 6 (q 8)', 'u3 8 (q 4)', 'u3 10 (q 4)', 'u3 20 (q 4)'};
o(2).extra = ''; o(2).extra_label = '';
grid_lifecycles(16, 'owner', o, fullfile(out, 'lifecycles_16_owner.png'), ...
    'Owner, step 16: the simulated life cycle as the grid is refined');

t(1).name = 'u1 x u2 (u3 10)';
t(1).cases = {'pow3_16x16_lim_u3p2', 'pow3_20x20_lim_u3p2', 'pow3_24x24_lim_u3p2', ...
              'pow3_32x32_lim_u3p2', 'pow3_48x48_lim_u3p2'};
t(1).labels = {'16x16', '20x20', '24x24', '32x32', '48x48'};
t(1).extra = 'standard'; t(1).extra_label = 'ladder grid, evenly spaced 16x16';
t(2).name = 'u3 points (16x16)';
t(2).cases = {'pow3_16x16_lim_u3p2_u3n6', 'pow3_16x16_lim_u3p2', ...
              'pow3_16x16_lim_u3p2_u3n20', 'pow3_16x16_lim_u3p2_u3n40'};
t(2).labels = {'u3 6', 'u3 10', 'u3 20', 'u3 40'};
t(2).extra = 'pow3_16x16_lim_u3p3'; t(2).extra_label = 'u3 10 at power 3';
grid_lifecycles(16, 'renter', t, fullfile(out, 'lifecycles_16_renter.png'), ...
    'Renter, step 16: the simulated life cycle as the grid is refined');
end

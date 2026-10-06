# Demo package

Small fork of the code that only shows the non-legacy parts to run the model for a given strategy and make the plots.

## Run it

From this folder in MATLAB (needs the Optimization and Parallel Computing toolboxes):

```matlab
run_combined      % solves + simulates renter and owner -> gives combined_{renter,owner}_lna.mat
make_plots        % reads those .mat files -> fig_dashboard_*.png, fig_renter_vs_owner_lna.png
```

`run_combined` solves on the grid that currently is running on dsri cube (`[28 20 20]`, `gh_n = 7`). 

If you want to run it much quicker, set the grid variables like so
```matlab
setenv('CGM_STATE_GRID','8 6 6'); setenv('CGM_GH_N','3');
run_combined
setenv('CGM_STATE_GRID',''); setenv('CGM_GH_N','');   
```

Outputs go to the current folder, or to `CGM_OUTPUT_DIR` if set manually.

## What the solver does

`solver.bellman_step_lna` performs the backward induction step. The household chooses
consumption `c` and the liquid equity share `pi`; the DC equity share `tau`
follows the fund strategy (`config.tau_effective`) and is not a choice. Each
interior state is seeded from next period's policy at the same point as a warm start, then optimised with `fmincon`, before finishing finished with a short local search (`refine_cpi_u`). 
As the stock decision only leads to very small movements in the value function this helps with smoothing it out and preventing stalling of the optimiser.

## Files

| Package        | Files |
|----------------|-------|
| `+config`      | `params`, `income_profile`, `income_table_bkv`, `survival`, `kappa_path`, `h_process`, `tau_effective` |
| `+grids`       | `shock_grid` |
| `+pension`     | `annuity_price` |
| `+solver`      | `solve`, `solve_lifecycle_lna`, `bellman_step_lna` |
| `+simulate`    | `forward`, `paths_lna` |
| `+utility`     | `active_grid`, `grid_suffix`, `output_dir`, `production_grid`, `grid_override`, `build_state_grids` |
| (root)         | `run_combined`, `make_plots` |
| data           | `CBSunisexmortality21-26.csv` (unisex mortality, default survival table) |

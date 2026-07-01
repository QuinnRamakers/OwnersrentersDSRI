CGM life-cycle model with DC pension and housing
=================================================

Requirements: MATLAB R2024b+, Optimization Toolbox, Parallel Computing Toolbox.

To run:
    1. Open MATLAB.
    2. Set the current folder to this directory.
    3. Run run_combined.m.

This solves the model for two scenarios, renter and owner, and saves the
results to combined_renter.mat and combined_owner.mat in this directory.
Each .mat file contains the calibration (p), income/survival profile,
shock grid, annuity prices, the solved value/policy functions (sol), and
5,000 simulated household paths (sim).

At the production grid (40x40x40 states, 7x7x7 shock nodes per period),
each scenario takes roughly 1-2 hours on a 16-core machine; the script
runs both scenarios sequentially, so budget 2-4 hours total.

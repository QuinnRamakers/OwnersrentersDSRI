# Session notes — DC REIT asset, dashboard, solver reframe, and the π-indeterminacy finding

Branch: `solver-active-set`. **Everything below is in the working tree and NOT committed.**
Author handoff written 2026-09-07.

---

## 1. What was done (in order)

1. Added a **REIT asset to the DC/retirement account** (a 4th lognormal shock, DC-only).
2. Verified its **comparative statics** (return / vol / share sweeps).
3. Integrated the REIT into the **`make_plots` dashboard**; added a **private-account size panel**.
4. Reframed the solver so the **fmincon step is named the optimiser, not a "polish"**, and flagged `skip_polish` as unsafe; added `polish_algo` / `use_refine` switches.
5. Ran an **optimiser comparison** (active-set vs interior-point × refine on/off).
6. Diagnosed the **jagged π(age)** — the main analytical result of the session.

---

## 2. The REIT asset

**Model.** The DC fund return is now a three-leg split (was stock/bond):

```
R_A = ((1 - tau_S - tau_REIT)·Rf + tau_S·R_S + tau_REIT·R_REIT) / p_t
```

REIT is **DC-only** (no REIT in the liquid account). It does **not** add a state — only the return on `A` changes. The "extra dimension" is a 4th shock, not a 4th state.

**Design decisions.**
- `tau_REIT` is a **fixed/imposed allocation** (like the `tau_S` glide), NOT a choice variable. Stored so a scalar (constant) OR a vector (path) both work via `config.reit_effective` — so a glide drops in later without touching the solver.
- Return **level is the single source of truth**: `config.reit_process(p)` derives `[mu,sigma]` from `mu_REIT_level`/`sigma_REIT_level` on demand (NOT cached in `params`, unlike `p.mu_S`/`p.mu_H`). So overriding a REIT level on a p-struct takes effect without re-running `params`. `p.mu_REIT`/`p.sigma_REIT` no longer exist.
- `mu_REIT_level` is an **excess return over r_f** (stock convention).
- The **4th shock is gated** on `config.reit_active(p)` (nonzero share or nonzero REIT correlation). Off ⇒ old `gh_n^3` grid, pre-REIT model reproduced at old cost. On ⇒ `gh_n^3 · gh_n_reit` joint nodes.
- Constraint `tau_S + tau_REIT ≤ 1` (bond leg ≥ 0) asserted in `config.params` AND at both solver entry points (`solve_lifecycle`, `solve_lifecycle_lna`).

**Placeholder calibration (all need real values):**

| param | value | meaning |
|---|---|---|
| `mu_REIT_level` | 0.03 | REIT excess return over r_f |
| `sigma_REIT_level` | 0.12 | REIT return vol |
| `tau_REIT` | 0.10 | constant DC REIT share |
| `corr_RL/RS/RH` | 0 | REIT correlations (income/stock/housing) |
| `gh_n_reit` | = `gh_n` (7) | GH nodes for the REIT shock |

**Performance:** `gh_n_reit = gh_n` is full accuracy (default); dial down to 3–5 to cut the ~7× cost the 4th shock adds when active.

**Verified comparative statics** (`scratchpad/reit_experiments.m`):
- return ↑ (`mu_REIT_level` 0→0.06): E[A₆₇] 918k→1056k, annuity a(t_ret) 17.03→16.06, retirement C 31k→39k. ✓ monotone.
- vol ↑ (`sigma_REIT_level` 0.05→0.40): mean fund flat (~1.007M, excess-return calibration fixes the mean), std/cv rise, annuity flat (prices the mean). ✓
- share ↑ (`tau_REIT` 0→0.20): at 0 the gate is off (reproduces baseline 918k), then fund rises 961k→1107k. ✓

**Files touched for the REIT:**
`+config/params.m`, `+config/reit_effective.m` (new), `+config/reit_active.m` (new), `+config/reit_process.m` (new), `+grids/shock_grid.m`, `+solver/bellman_step.m`, `+solver/bellman_step_lna.m`, `+solver/solve_lifecycle.m`, `+solver/solve_lifecycle_lna.m`, `+simulate/paths.m`, `+simulate/paths_lna.m`, `+pension/annuity_price.m` (linear — REIT mean only), `+utility/param_fingerprint.m`.

---

## 3. Dashboard integration (`make_plots.m`)

All gated on `reit_on = isfield(sim,'reit_A') && any(sim.reit_A(:)~=0)` so old .mat / REIT-off runs render identically.

- **Simulators** now report `sim.reit_A` (applied DC REIT share, N×T-1) alongside `sim.tau_A` (stock share).
- **`equity_exposure`** gained two trailing outputs `reit_pens`, `reit_path` — the STOCK outputs stay stock-only, so the cross-scenario / renter-vs-owner sections are untouched.
- **Panel (i)** → added teal dotted REIT-share line; retitled.
- **Panel (j)** → added teal REIT band → "total risky exposure (stocks + REIT)"; nicely shows the REIT is the only risky exposure left after the stock glide → 0 at retirement.
- **Panel (k)** → REPURPOSED from the redundant "stock exposure vs savings+pension" ratio into **"Private (liquid) account: size and stock content"** — the liquid account in € (stock euros π·X stacked under bond euros), annotated with private stocks as a share of the household's risky holdings. Owner ≈ 38%, renter ≈ 37% → the private account is NOT negligible.
- **Panel (l)** → added a REIT calibration line.
- REIT colour = teal `[0.15 0.60 0.55]` (`REIT_COL`, defined once).
- **Bug fixed:** the `source file:` Windows path's backslashes broke the tex interpreter for the whole calibration box → now `strrep('\','/')`.

Standalone (not in the dashboard): `plot_reit_impact.m` (repo) = with-vs-without REIT diagnostic; `scratchpad/renter_private_panel.m` = enlarged private-account view.

**Open dashboard decision:** panel (k) was *repurposed* rather than expanding 3×4 → 4×4. If the old ratio should stay AND the private-account panel be a 13th tile, switch to 4×4.

---

## 4. Solver reframe (the optimiser is not a "polish")

- Renamed internal locals in `bellman_step_lna.m`: `opts_polish→opts_opt`, `V_polish→V_opt`, `polish_obj→obj_cpi`. Rewrote comments: **fmincon is the actual optimisation**, the seed just starts it, `refine_cpi_u` cleans interpolation ridges after.
- **`skip_polish` is now documented + runtime-warned as producing INVALID output** (it bypasses the optimiser; with `grid_mode='none'` π freezes at the terminal all-bond value = 0). Warning in `solve_lifecycle_lna`; doc in `params.m`. Smoke-test only.
- New switches in `bellman_step_lna`: **`p.polish_algo`** (`'active-set'` default / `'interior-point'`) and **`p.use_refine`** (`true` default). Backward-compatible (defaults = old behaviour). NOT yet mirrored into the simplex `bellman_step.m`.

**Per-node optimisation pipeline (glide arm, production defaults):**
0. budget → 1. corner guards (floor / LW≤0 set policy, no optimisation) → 2. seed = warm start (next period's policy; grid_mode='full' would grid-search instead) → 3. [skip_polish exits here] → 4. fmincon (active-set) on the scaled objective from the seed → 5. `refine_cpi_u` derivative-free shrinking-radius scan → 6. take best of {seed, fmincon, refine}.

**Optimiser comparison results** (renter, full solves):

| config | Δπ(age) vs AS+refine | singular-KKT | note |
|---|---|---|---|
| active-set + refine | reference | none | production default |
| active-set, no refine | up to 0.383 | none | fast but π corrupts |
| interior-point + refine | ≤ 0.004 | yes (RCOND~1e-17) | same answer as AS, slower |
| interior-point, no refine | up to 0.337 | yes | worst |

Takeaways: **with refine on, the algorithm is irrelevant** (AS ≡ IP to 0.004). **Refine is not optional** — without it π drifts up to ~0.38 (compounds over the induction). Active-set is faster and throws no singular-KKT warnings. **Consumption is optimiser-invariant in all four.**

---

## 5. THE MAIN FINDING — the jagged π(age) is economic, not numerical

The liquid stock share π(age) is jagged (sawtooth), worst in retirement. Investigated thoroughly:

- **It is NOT state-interpolation.** Linear interpolation is continuous; a smooth population over a smooth policy gives smooth mean π.
- **It IS temporal.** Holding the state FIXED and varying only age, `π_pol` jumps up to **1.0 age-to-age** (`scratchpad/temporal_test.m`).
- **Root cause = a flat objective in π.** Reconstructing the actual Bellman RHS (validated: reproduces solver V/c*/π* exactly — `scratchpad/objective_surface.m`) shows the objective is **flat in π, sharp in c**: moving π across ALL of [0,1] costs **<0.0074% CE** (retiree) / **<0.012% CE** (accumulator). So π* snaps to a corner (0 or 1) whose sign flips with tiny state/age changes → the sawtooth. The value function itself is smooth in state.
- **Two regions, two components** (grid sweep `scratchpad/render_diag.m`): ACCUMULATION spikes are grid resolution (vanish at 14×12×12, converged at 18×15×15); RETIREMENT sawtooth is the flat-objective floor (persists at all grids). Roughness 0.087(10³)→0.042(14³)→0.039(18³): the drop is accumulation, the plateau is retirement.
- **Economic cause:** the 36% box-3 CGT on the liquid stock leg has **no loss offset** (asymmetric: full downside, 64% upside), which nearly kills the after-tax equity premium for γ=5 → the household is close to indifferent about π. The private account is NOT tiny (peaks ~€40–64k, ~37–38% of risky holdings), so it's the tax-flattened premium, not smallness, that drives the indeterminacy.

**Implication:** this is the model faithfully reporting an indeterminate choice — NOT a solver/grid/algorithm bug. It's optimiser-invariant. The lever is **calibration** (a loss offset / different box-3 treatment restores a determinate π), or report π as an indeterminacy band. (User declined a solver-side continuity tie-breaker.)

---

## 6. Current solved files

`combined_owner_lna.mat` and `combined_renter_lna.mat` (repo root, gitignored):
- Grid `12 × 10 × 8`, `gh_n = 5`, `gh_n_reit = 3`, `N_c = N_pi = 15`, N_sim = 4000.
- Optimiser: **active-set + refine** (`skip_polish=0`, `use_refine=1`, `polish_ver=2`, `grid_mode='none'`).
- This is a **moderate/fast** grid, below the production default `28×20×20` / `gh_n 7` in `params.m`.
- REIT active (`tau_REIT=0.10`).

---

## 7. Open items / next steps

- [ ] **Commit** this session's work (REIT asset + dashboard panels + solver reframe). Nothing is committed yet.
- [ ] **Calibrate the REIT placeholders** (`mu_REIT_level`, `sigma_REIT_level`, `tau_REIT`, `corr_R*`).
- [ ] Decide the **π indeterminacy** response: keep as-is (report band), or change the box-3 CGT treatment (loss offset) to restore a determinate π.
- [ ] Optional: **production-grid re-solve** of owner+renter (`28×20×20`, `gh_n 7/7`, active-set+refine) for definitive dashboards (~40–60 min background). Will smooth accumulation π, not retirement.
- [ ] Decide: **mirror the optimiser reframe + `polish_algo`/`use_refine` into the simplex `bellman_step.m`**?
- [ ] Decide: **remove the `skip_polish` field entirely** vs keep-and-warn?
- [ ] Decide: dashboard **panel (k) repurpose** vs 3×4 → 4×4 for a genuine extra tile.

---

## 8. Reproduction scripts (in the session scratchpad — copy into the repo if you want them kept)

Scratchpad dir: `C:\Users\Quinn\AppData\Local\Temp\claude\C--Users-Quinn-Desktop-claudecodetest\09022b31-1999-4844-b935-dc5896ea19a1\scratchpad\`

- `smoke_reit.m` — minimal end-to-end REIT smoke (gate, solve, sim, annuity).
- `reit_experiments.m` — comparative statics (return/vol/share sweeps).
- `objective_surface.m` — reconstructs & plots the Bellman RHS(c,π) and value surface (the flat-objective evidence).
- `temporal_test.m` — π_pol at fixed states across age (the temporal-noise evidence).
- `render_diag.m` — grid-resolution sweep + 4 optimiser-config dashboards.
- `compare_opt.m` / `compare_full_renter.m` — optimiser comparison (single-step / full-solve).
- `renter_private_panel.m` — enlarged private-account view.

> NOTE: the scratchpad is session-temporary and may be cleaned up. If you want these scripts, copy them into the repo (e.g. a `diagnostics/` folder) before they're gone.

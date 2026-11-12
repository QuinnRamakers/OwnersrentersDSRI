# Running the owners-renters model on the DSRI with Claude Code

How to solve the owners-renters life-cycle model on Maastricht University's Data Science Research Infrastructure, driven by Claude Code on your own laptop. No GitHub: the code and its history stay on the laptop, the runs on the DSRI. Adapted from "Running Code on the DSRI with Claude Code", October 2026.

## 1 Overview

The DSRI is an OpenShift (Kubernetes) cluster, not an ordinary SSH server. You cannot log into it with `ssh user@host`. You control it with the OpenShift command-line tool `oc`.

Claude Code stays on your laptop, in the project folder, and drives a MATLAB pod on the DSRI through `oc`:

1. Commit. Git keeps the project's history in the project folder itself; there is no GitHub and no other server. Every DSRI run starts from a commit, so its log can name the code it ran.
2. Send the code from the laptop to the pod (`oc rsync`).
3. Run MATLAB in batch mode inside the pod, in the background (`oc exec ... nohup matlab -batch ...`).
4. Monitor progress by reading the log (`oc exec ... tail`).
5. Pull the results back next to the code (`oc rsync`). `ladder.compare`, `figures.*` and the diagnostics then find them as if the solve had run on the laptop.
6. Log the run in HANDOFF.md, like any other solve.

```text
  laptop                      oc rsync, oc exec       DSRI MATLAB pod
  Claude Code, git, oc   -------------------------->  cgm-matlab
  MATLAB for figures          over the UM VPN            |
  project folder and                                     |  persistent volume
  its git history                                        v
                                                      /Solutionstorage
```

What runs where:

| Work | Where |
|---|---|
| Long solves: ladder steps with housing, owners on bunched or large grids, `ladder.robustness`, grid studies (`solve_cases`), the full `run_tests` when the laptop is busy | DSRI |
| `run_tests(solve=false)`, quick-grid looks, `ladder.compare`, figures, diagnostics on saved results | laptop |

The code and the results stay on the laptop and the DSRI volume. Nothing is published, and no code host is involved, public or private. As in any Claude Code session, the conversation goes to Anthropic, including the files Claude reads and the output it sees; for this model that is code, parameter values and simulated results.

What you need:

1. A UM account with access to a DSRI project (DSRI support can add you), and the UM VPN.
2. A Claude account, for Claude Code.
3. The UM MATLAB licence on the pod (section 2.5). MATLAB on the laptop is optional, for the quick checks and figures in the table above.
4. No GitHub account, or any other online account for the code. Git is a program on the laptop (section 2.2).

## 2 One-time setup

### 2.1 Network access

The DSRI is only reachable from the UM network. Outside the university, connect to the UM VPN first (client at <https://vpn.maastrichtuniversity.nl>).

> [!WARNING]
> **Watch out.** If the VPN is down, *every* `oc` command fails, even with a valid login. When Claude Code reports connection errors, check the VPN first.

### 2.2 Install Git and `oc` on Windows

Git for Windows: download it from <https://git-scm.com/download/win> and install it with the default options. It needs no account. It brings Git Bash, which Claude Code on Windows uses for its commands, and `git`, which keeps the project's history on the laptop.

Then `oc`:

1. Create a folder, for example `C:\Program Files (x86)\OpenShift`.
2. Download `openshift-client-windows.zip` (link under Further reading) and extract it into that folder.
3. Add the folder to your Path: Control Panel, System, Advanced system settings, Environment Variables.
4. Open a new Git Bash and run `oc version`.

Claude Code on Windows runs its commands in Git Bash. That has two consequences.

1. Git Bash rewrites arguments that look like Unix paths before it hands them to a Windows program. `/Solutionstorage/...` becomes `C:/Program Files/Git/Solutionstorage/...`, and `oc` sends that to the pod. Setting `MSYS_NO_PATHCONV=1` stops it. Section 5.2 sets it for Claude Code; in your own Git Bash, run `export MSYS_NO_PATHCONV=1` first.
2. Windows has no `rsync`. `oc rsync` then falls back to a tar copy, which sends every file each time instead of only the changed ones. The code is a few hundred kilobytes, so that does not matter. For results, pull only the folder you need (section 4).

### 2.3 The MATLAB pod

You need one long-running pod with MATLAB in it. The DSRI has a template for that.

1. Open the DSRI web console at <https://console.dsri.unimaas.nl> and switch to the **Developer** perspective.
2. Click **+Add**, then **Software Catalog** (older documentation calls this *Developer Catalog*; it is the same).
3. Tick the **Templates** filter and choose **Matlab**.
4. Fill in the form:
   - **Application name**: short and lowercase. This guide uses `cgm-matlab`, which becomes the label `app=cgm-matlab` used to find the pod. For a pod you already have, `oc get pods --show-labels` shows its label; use that everywhere below, CLAUDE.md included.
   - **Matlab image version**: the release the toolbox install uses (`--release=R2025a` in section 2.4). The two must match.
   - **Password**: protects only the MATLAB page in your browser. Claude Code never needs it.
5. Click **Instantiate** and wait until the pod is running (dark blue ring in the Topology view).

Two things the template does not set for you:

1. Storage. The template keeps `/home/matlab/persistent` across restarts. The project's scripts use a volume of their own at `/Solutionstorage` (Topology, the deployment, **Add Storage**; see `+utility/output_dir.m`). This guide uses `/Solutionstorage`. If you use the template's folder instead, replace the path everywhere.
2. Cores. The solver sizes its parallel pool to the pod's CPU limit, not to the node (`utility.cpu_quota` reads the limit inside the container). The times in README.md are for 16 cores. Set the limit on the deployment (Actions, **Edit resource limits**). DSRI support can raise the project's quota.

> [!WARNING]
> **Only one folder is persistent.** Anything outside `/Solutionstorage` is lost when the pod restarts. That includes the toolboxes: they are installed into the image's MATLAB under `/opt/matlab`, which is not on the volume. Keep code, results and logs under `/Solutionstorage`, and reinstall the toolboxes after every restart (section 2.4).

### 2.4 Toolboxes

The image has MATLAB only. The model needs the Optimization Toolbox (`fmincon`). The Parallel Computing Toolbox makes it fast; without it the solver runs serially and gives the same numbers. After every pod start, let Claude Code run the install, or run it yourself in Git Bash:

```bash
oc exec $POD -- bash -c 'cd /tmp && \
  wget -q https://www.mathworks.com/mpm/glnxa64/mpm && chmod +x mpm && \
  sudo HOME=$HOME ./mpm install --release=R2025a \
    --destination=$(dirname $(dirname $(readlink -f $(which matlab)))) \
    --products Optimization_Toolbox Parallel_Computing_Toolbox; rm -f mpm'
```

`bootstrap_pod.m` does the same from the MATLAB window, but it first downloads the code from GitHub, so it does not work in this setup. To skip this step for good, `install_matlab.sh` installs the whole of MATLAB on the volume once (set its `MATLAB_RELEASE` first). Every run must then put `/Solutionstorage/matlab/bin` first on its `PATH`.

### 2.5 Licence for batch mode

> [!WARNING]
> **Test the licence before anything else.** Claude Code runs MATLAB with `matlab -batch`, outside the browser session. The MATLAB image licenses batch mode through a network licence server, set as `MLM_LICENSE_FILE=<port>@<server>` in the pod's environment. A login in the browser window may not cover it. The first test run (section 5.3) checks this. If it stops with a licence error, ask DSRI support for the UM licence server and add `MLM_LICENSE_FILE` to the deployment's environment (Topology, the deployment, **Environment**). Commands started with `oc exec` inherit the pod's environment.

### 2.6 The project folder

Put the project folder on the laptop, for example as `C:\Users\<you>\OwnersrentersDSRI`, from a zip or a USB stick. Then, in Git Bash in that folder:

```bash
git init                                # only if the folder has no .git folder yet
git remote -v                           # must print nothing
git remote remove origin                # only if it printed a GitHub address
git config user.name "Your Name"        # any name and address: git only writes
git config user.email "you@example.com" # them into the history in this folder
git add -A
git commit -m "Project as received"     # skip if the folder came with its history
```

If `demo - Copy/` or `demo - Copy.zip` came along, delete them before `git add -A`; they are leftovers. `bootstrap_pod.m` and `setup_cluster.sh` download the code from GitHub and are not used here.

The project's own rules still assume GitHub: CLAUDE.md and the session-end skill tell Claude Code to push. Section 5.1 gives the lines that replace them.

## 3 Logging in with `oc`

Password login is not supported for `oc`. Use a token instead:

1. In the web console, click your name (top right), then **Copy login command**, then **Display Token**.
2. Paste the command into Git Bash. It looks like this (the copied command has the right address):

```bash
oc login https://api.dsri.unimaas.nl:6443 --token=<YOUR_TOKEN>
oc project <your-project>
```

The token is saved in `C:\Users\<you>\.kube\config`. Every terminal and every Claude Code session on the laptop reuses it.

#### How long does the login last?

You log in again only when the token expires (24 hours by default on OpenShift; the DSRI may use another value). Check at any time with:

```bash
oc whoami        # prints your username if the token is valid
```

If it prints an *Unauthorized* error, copy a fresh login command from the web console. Claude Code cannot renew the token for you. A run that is already going does not need the token: it matters only when Claude Code starts, checks or pulls a run.

> [!TIP]
> **Longer-lived access (optional).** A *service account* scoped to your project can get a longer-lived token:
>
> ```bash
> oc create serviceaccount claude-runner
> oc policy add-role-to-user edit -z claude-runner
> oc create token claude-runner --duration=720h
> ```
>
> The cluster may cap the duration. Ask DSRI support (DSRI-SUPPORT-L@maastrichtuniversity.nl) before relying on this.

#### Quick check before using Claude Code

```bash
oc whoami                          # logged in?
oc project                         # correct project?
oc get pods -l app=cgm-matlab      # pod shows 1/1 Running?
```

## 4 The workflow: commit, sync, run, monitor, pull

These are the commands Claude Code runs on your behalf, in Git Bash in the project folder. Knowing them lets you follow along and step in.

```bash
export MSYS_NO_PATHCONV=1          # Git Bash: leave /Solutionstorage paths alone
POD=$(oc get pods -l app=cgm-matlab -o name | head -1 | cut -d/ -f2)
REPO=/Solutionstorage/OwnersrentersDSRI

# 0. the run starts from a commit
git status -sb --untracked-files=no   # nothing uncommitted
COMMIT=$(git rev-parse --short HEAD)

# 1. send the code; never --delete, because the results live in the same folder
oc exec $POD -- mkdir -p $REPO/runs
oc rsync ./ $POD:$REPO/ --exclude=.git --exclude=.claude --exclude=ladder \
    --exclude='*.mat' --exclude='*.png' --exclude='*.pdf' --exclude='*.txt' \
    --exclude='demo - Copy' --exclude='demo - Copy.zip'

# 2. run in the background, so the job survives disconnects
LOG=runs/step16.txt
oc exec $POD -- bash -c "cd $REPO && echo commit $COMMIT, started \$(date) > $LOG && \
    CGM_OUTPUT_DIR=$REPO nohup matlab -sd $REPO -batch 'ladder.run(16)' >> $LOG 2>&1 &"

# 3. monitor
oc exec $POD -- tail -n 30 $REPO/$LOG
oc exec $POD -- bash -c "ps -eo pid,etime,args | grep [-]batch"

# 4. pull the log and the results folder the run wrote to
oc exec $POD -- ls $REPO/ladder
oc rsync $POD:$REPO/runs ./
oc rsync $POD:$REPO/ladder/standard_16x16x10x8_gh5 ./ladder/   # the folder ls showed
```

Notes on these commands:

1. `CGM_OUTPUT_DIR` is the project folder on the pod, as `pwd` is on the laptop, and `-sd` starts MATLAB in it, so the packages are on the path. Results therefore land under `ladder/<numerics folder>/` on both sides, and a pull puts them where `ladder.compare` looks.
2. The first line of every log is the commit the run used. Copy it into the HANDOFF.md entry.
3. The MATLAB statement sits in single quotes inside the double-quoted remote command. Strings inside it take double quotes, escaped: `'ladder.run(16, numerics=\"fine\")'`.
4. Settings that the README sets with `setenv` go on the bash side instead, before `nohup`: for a quick-grid look, `CGM_STATE_GRID='8 6 6 4' CGM_GH_N=3 CGM_OUTPUT_DIR=$REPO nohup matlab -sd $REPO -batch ...`.
5. Do not exclude `*.csv`: the mortality table `CBSunisexmortality21-26.csv` is an input.

> [!WARNING]
> **Always use `nohup` for long runs.** A plain `oc exec ... matlab -batch ...` stops as soon as the connection drops, the laptop sleeps, or Claude Code's command times out (after ten minutes at most). An owner solve at step 16 takes one to several hours. Starting the job with `nohup ... &` keeps it running on the DSRI.

> [!WARNING]
> **Two runs at once.** Each MATLAB sizes its pool to the whole pod, so two runs side by side put twice as many workers as cores and slow each other down. Give each its share with `CGM_N_WORKERS`, for example `CGM_N_WORKERS=8` for each of two runs on 16 cores. `utility.start_pool` then tries a process pool of that size and falls back to threads.

## 5 Configuring Claude Code

### 5.1 Add instructions to CLAUDE.md

Put the following section in the project's CLAUDE.md. With it, a short instruction such as "run ladder step 16 on the DSRI" is enough.

```markdown
## Running on the DSRI

The how-to is `docs/DSRI_HOWTO.md`.

- Only from Claude Code on this laptop, with the UM VPN on.
- No GitHub: the code and its history stay on this laptop, the results on the
  laptop and the pod. Never add a git remote and never push.
- Before any DSRI work, run `oc whoami`. If it fails, stop and ask me to log in
  again and to check the VPN. Do not retry.
- Pod: `oc get pods -l app=cgm-matlab -o name`. Never hard-code the pod name; it
  changes on every restart.
- Remote folder: `/Solutionstorage/OwnersrentersDSRI`, the only persistent place.
  Run there with `CGM_OUTPUT_DIR` set to it, so results land under `ladder/` as on
  the laptop.
- `MSYS_NO_PATHCONV=1` must be set, or Git Bash rewrites the `/Solutionstorage`
  paths: in the `env` of `.claude/settings.json`, or with `export MSYS_NO_PATHCONV=1;`
  at the start of each command (shell state does not carry over between commands).
- Sync only a committed tree (`git status -sb --untracked-files=no` shows no
  changes), with
  `oc rsync ./ <pod>:/Solutionstorage/OwnersrentersDSRI/ --exclude=.git
  --exclude=.claude --exclude=ladder --exclude='*.mat' --exclude='*.png'
  --exclude='*.pdf' --exclude='*.txt' --exclude='demo - Copy'
  --exclude='demo - Copy.zip'`. Never `--delete`: the results live in the same folder.
- Long runs: inside `oc exec <pod> -- bash -c "..."`, write
  `commit <hash>, started <date>` as the first line of `runs/<name>.txt`, then
  `CGM_OUTPUT_DIR=<folder> nohup matlab -sd <folder> -batch '<statement>'
  >> runs/<name>.txt 2>&1 &`. MATLAB strings in the statement take escaped
  double quotes.
- Two runs at once: give each `CGM_N_WORKERS` equal to its share of the pod's cores.
- Progress: `tail` on the log. Running jobs: `ps -eo pid,etime,args | grep [-]batch`.
- When a run ends: read `model.checks` in the log (`c_bound_25_39`, `ce_entry`,
  `offgrid`), pull `runs/` and the results folder with `oc rsync`, and log the run
  in HANDOFF.md: that it ran on the DSRI, the commit, the pod's cores, the wall
  time and the checks.
- `Undefined function 'fmincon'` or "No parallel pool" means the pod restarted:
  reinstall the toolboxes (docs/DSRI_HOWTO.md, section 2.4) and start the run
  again. `ladder.run` skips steps already saved.
- A licence error: stop and tell me.
- Never run `oc delete`, and never delete anything under `/Solutionstorage`,
  without asking first.
```

Then replace the lines that assume GitHub:

1. CLAUDE.md, "Where things live", item 4, becomes: "The git repository in this folder, branch main, is the single source of truth. It has no remote."
2. CLAUDE.md, "Starting and finishing a session": "blocks the end of a session while changes are uncommitted or unpushed. Work only counts once it is pushed, because chat reads GitHub, not this PC." becomes "blocks the end of a session while changes are uncommitted. Work counts once it is committed."
3. `.claude/skills/session-end/SKILL.md`, step 5, becomes: "Commit to main. There is no remote, so nothing is pushed. Run `git status -sb` and confirm nothing is left uncommitted." In step 6, "that it is pushed" becomes "that it is committed".
4. HANDOFF.md stays the log that Claude Code reads at the start of every session. Without GitHub, Claude on claude.ai cannot read it, so you write the specs into it yourself.

The two hooks need no change. Without a remote, the start hook's `git fetch` does nothing, and the end hook checks only for uncommitted changes.

### 5.2 Pre-approve the `oc` commands

To avoid a permission prompt for every sync, add the routine commands to `.claude/settings.json`, next to the hooks that are already there. The `env` line sets `MSYS_NO_PATHCONV` for every command Claude Code runs.

```json
{
  "env": {
    "MSYS_NO_PATHCONV": "1"
  },
  "permissions": {
    "allow": [
      "Bash(oc whoami:*)",
      "Bash(oc project:*)",
      "Bash(oc get:*)",
      "Bash(oc rsync:*)",
      "Bash(oc exec:*)"
    ]
  },
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-end-check.sh\""
          }
        ]
      }
    ]
  }
}
```

Leave `oc delete` off the list on purpose, so Claude Code always has to ask before removing anything on the DSRI.

### 5.3 A first test run

Before a real run, check the whole loop with something small. Ask Claude Code:

> Test the DSRI connection. Run `oc whoami`, find the pod with `oc get pods -l app=cgm-matlab`, and sync the project to `/Solutionstorage/OwnersrentersDSRI`. In the background, with the log in `runs/dsri_test.txt`, run `matlab -sd /Solutionstorage/OwnersrentersDSRI -batch 'disp(version); disp(utility.cpu_quota); assert(exist("fmincon") > 0); addpath tests; run_tests(solve=false)'`. Then, the same way, a quick-grid solve with `CGM_STATE_GRID='8 6 6 4'`, `CGM_GH_N=3` and `CGM_OUTPUT_DIR=/Solutionstorage/OwnersrentersDSRI/runs/dsri_test`: `run_model(config.params(), tag="dsri_test")`. Pull `runs/` back here.

Everything works if:

1. the log shows the MATLAB release, the number of cores you asked for, and `0 of ... checks failed.`;
2. the quick solve printed `model.checks` for the renter and the owner;
3. `runs/dsri_test/` on the laptop holds `results_renter_dsri_test.mat` and `results_owner_dsri_test.mat` with their dashboards.

A licence error at the first step means section 2.5. A missing `fmincon` means section 2.4.

### 5.4 Example prompts for daily use

- "Run `ladder.run(16)` on the DSRI at standard numerics and tell me when the renter arm is saved."
- "Check the DSRI run and show the last 30 lines of the log."
- "The step-16 run on the DSRI has finished. Pull the results, read `model.checks`, draw `ladder.compare(16)` here and log the run in HANDOFF.md."
- "Run these two `solve_cases` lists from `diagnostics/pension_grid` on the DSRI as two processes, half the cores each, smallest grids first."
- "Commit my `+solver` change, then run the full `run_tests` on the DSRI and report what it printed."

## 6 Troubleshooting

| Symptom | Fix |
|---|---|
| `Unauthorized` / `You must be logged in` | Token expired. Copy a new login command from the web console. |
| Timeouts, `no route to host` | The UM VPN is not connected. |
| `No resources found` for `oc get pods` | Wrong project (`oc project <name>`), wrong label, or the pod is not running. Check the Topology view. |
| A path like `C:/Program Files/Git/Solutionstorage/...` in an error | Git Bash rewrote it. Set `MSYS_NO_PATHCONV=1` (section 5.2). |
| A licence error from `matlab -batch` | Batch mode needs the network licence (section 2.5). |
| `Undefined function 'fmincon'`, or "No parallel pool ... solving serially" | The pod restarted and lost the toolboxes. Reinstall them (section 2.4). |
| Files missing after a restart | They were stored outside `/Solutionstorage`. Always use the persistent folder. |
| Job stopped when the laptop slept | It was not started with `nohup ... &`. |
| Job gone, the log ends in the middle of a solve | The pod restarted. Reinstall the toolboxes and start the same command; `ladder.run` skips the steps already saved. |
| `git commit` says "Please tell me who you are" | Set `user.name` and `user.email` (section 2.6). They stay in the local history. |
| `git remote -v` prints a GitHub address | The folder came with a link to GitHub. Remove it with `git remote remove origin`. |
| Pod name changed | Normal after a restart. Always look it up with the label `app=cgm-matlab` instead of hard-coding it. |
| A solve far slower than the times in README.md | Two runs each sized to the whole pod, or a low CPU limit. Check the core count in the log; set `CGM_N_WORKERS` per run. |
| `ladder.run` on the laptop re-solves a step the DSRI already solved | The saved result has another calibration (`ladder.same_calibration`), usually because the pod had older code. Sync, and run it on the DSRI again. |
| `ladder.compare` cannot find a result pulled from the DSRI | It was pulled into another folder. Results sit under `ladder/<numerics folder>/` of `CGM_OUTPUT_DIR`, the project folder on the laptop. |

## 7 Notes and good practice

- **Keep a safe copy.** Without GitHub, the laptop holds the only copy of the code's history, and the DSRI volume the only copy of most solves. The DSRI is compute, not archive storage. Back up the history as one file, onto the volume (it stays at UM) or a USB disk: `git bundle create ../owners-renters.bundle --all`, then `oc cp` it to `/Solutionstorage/backup/` (section 8). `git clone owners-renters.bundle` restores it.
- **Code lives in git on the laptop.** Never edit code on the pod. Change it on the laptop, commit, then sync. The pod's copy is for running only.
- **Log every DSRI run** in HANDOFF.md like any other solve: the commit, the cores, the wall time and `model.checks`. Say it ran on the DSRI, since times differ from the laptop.
- **Restarts.** A pod restart stops a running job and removes the toolboxes. `ladder.run` reuses saved steps, so the same command again loses only the step in progress.
- **Usage.** Claude Code and the Claude app share the same usage limits. Check them with `/usage` in Claude Code. A job running in the background on the DSRI uses none.
- **Secrets.** Never put the `oc` token or the MATLAB password in CLAUDE.md, HANDOFF.md, scripts or chat messages.
- **GPUs.** Not useful here: the solver is `fmincon` in a `parfor` on CPU cores.

## 8 Quick reference

```bash
export MSYS_NO_PATHCONV=1                                             # Git Bash
oc login https://api.dsri.unimaas.nl:6443 --token=<TOKEN>             # log in
oc whoami                                                             # check login
POD=$(oc get pods -l app=cgm-matlab -o name | head -1 | cut -d/ -f2)  # find pod
REPO=/Solutionstorage/OwnersrentersDSRI
oc rsync ./ $POD:$REPO/ --exclude=.git ... (section 4)                # send code
oc exec $POD -- bash -c "cd $REPO && CGM_OUTPUT_DIR=$REPO \
    nohup matlab -sd $REPO -batch 'ladder.run(16)' >> runs/step16.txt 2>&1 &"   # run
oc exec $POD -- tail -n 30 $REPO/runs/step16.txt                      # monitor
oc rsync $POD:$REPO/runs ./                                           # pull logs
oc rsync $POD:$REPO/ladder/<folder> ./ladder/                         # pull results
oc rsh $POD                                                           # shell
git bundle create ../owners-renters.bundle --all                      # back up history
oc exec $POD -- mkdir -p /Solutionstorage/backup
oc cp ../owners-renters.bundle $POD:/Solutionstorage/backup/owners-renters.bundle
```

## Further reading

- DSRI documentation: <https://dsri.maastrichtuniversity.nl/docs/>
- Installing `oc`: <https://dsri.maastrichtuniversity.nl/docs/openshift-install/>
- Loading data with `oc rsync`: <https://dsri.maastrichtuniversity.nl/docs/openshift-load-data>
- MATLAB on the DSRI: <https://dsri.maastrichtuniversity.nl/docs/deploy-matlab>
- The MATLAB container image, batch mode and the licence server: <https://github.com/mathworks-ref-arch/matlab-dockerfile>
- Git for Windows: <https://git-scm.com/download/win>
- In the project folder: README.md ("Running it"), `install_matlab.sh`, `+utility/cpu_quota.m`, `+utility/start_pool.m`.

function n_fail = run_all(opts)
%RUN_ALL  Run the acceptance checks and report one pass/fail summary.
%
%   run_all                       % the fast checks (no solve)
%   run_all(slow=true)            % everything, including the solving checks
%   run_all(only=["smoke_spline_tau"])
%   n_fail = run_all(...)         % suppress the closing error, inspect instead
%
%   From the repo root:  addpath tests; run_all
%   Headless:            matlab -batch "addpath tests; run_all(slow=true)"
%
%   FAILURE IS AN ERROR. Every check here signals failure by raising one --
%   either an assert or an explicit error(...) after tallying its own counter.
%   That is the only convention they share, and it is enough: this wraps each
%   in try/catch, so a raised error is a failed check and a clean return is a
%   passed one. Two checks used to print "FAIL" and return normally, which
%   made them invisible to any runner; both now raise.
%
%   With an output argument requested the closing error is suppressed and the
%   failure count is returned instead, so a caller can decide what to do.
%   Without one -- the interactive and -batch cases -- a non-zero count raises,
%   which is what makes `matlab -batch` exit non-zero for CI.
%
%   FAST vs SLOW. The fast set touches no solver and finishes in seconds, so
%   there is no excuse not to run it. The slow set solves on coarse grids
%   (minutes each) and one member, test_freetau_dominance_prod, needs solved
%   PRODUCTION files on disk -- it is skipped, not failed, when they are
%   absent, since "you have not run the production solve" is not a defect.

arguments
    opts.slow (1,1) logical = false
    opts.only (1,:) string  = string.empty(1,0)   % 1x0, not 0x0: (1,:) wants a row
end

% Self-locating: tests/ for the siblings, the repo root for +config, +solver
% and the rest. Lets this be launched from either directory.
here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

%   name                          slow   needs production .mat files
CHECKS = {
    'smoke_spline_tau',             false, false
    'verify_income_profile',        false, false
    'smoke_rent_process',           true,  false
    'smoke_fill_fix',               true,  false
    'smoke_freetau_dominance_lna',  true,  false
    'test_freetau_dominance_prod',  true,  true
};

names = string(CHECKS(:,1));
slow  = cell2mat(CHECKS(:,2));
needs = cell2mat(CHECKS(:,3));

sel = true(size(names));
if ~isempty(opts.only)
    [tf, ~] = ismember(names, opts.only);
    unknown = setdiff(opts.only, names);
    assert(isempty(unknown), 'run_all:unknown', ...
        'Not a check in this folder: %s', strjoin(unknown, ', '));
    sel = tf;
elseif ~opts.slow
    sel = ~slow;
end

idx = find(sel);
fprintf('\n%s\n', repmat('=', 1, 64));
fprintf('run_all  %d check(s)%s\n', numel(idx), ...
    ternary(opts.slow || ~isempty(opts.only), '', '  [fast only -- pass slow=true for the rest]'));
fprintf('%s\n', repmat('=', 1, 64));

status  = strings(numel(idx), 1);
detail  = strings(numel(idx), 1);
secs    = zeros(numel(idx), 1);

for k = 1:numel(idx)
    i    = idx(k);
    name = names(i);
    fprintf('\n--- %s ---\n', name);

    if needs(i) && ~production_files_present()
        status(k) = "SKIP";
        detail(k) = "no solved production files in " + string(utility.output_dir());
        fprintf('SKIP: %s\n', detail(k));
        continue
    end

    t0 = tic;
    try
        % Not all checks are functions -- some are scripts, and MATLAB refuses
        % feval on a script ("Attempt to execute SCRIPT as a function"). run()
        % is the script path and feval the function one, so pick by reading
        % the file rather than by remembering which is which.
        target = which(char(name));
        if is_script(target), run(target); else, feval(char(name)); end
        status(k) = "PASS";
        secs(k)   = toc(t0);
    catch err
        status(k) = "FAIL";
        secs(k)   = toc(t0);
        % identifier when there is one, message otherwise: the tallying checks
        % raise a bare "%d check(s) failed", where the message is the useful half.
        if isempty(err.identifier), detail(k) = string(err.message);
        else,                       detail(k) = string(err.identifier) + " -- " + string(err.message);
        end
        fprintf('FAIL: %s\n', detail(k));
    end
end

fprintf('\n%s\n', repmat('=', 1, 64));
fprintf('%-32s %-6s %8s   %s\n', 'CHECK', 'RESULT', 'SECONDS', 'DETAIL');
fprintf('%s\n', repmat('-', 1, 64));
for k = 1:numel(idx)
    fprintf('%-32s %-6s %8.1f   %s\n', names(idx(k)), status(k), secs(k), detail(k));
end
fprintf('%s\n', repmat('=', 1, 64));

n_fail = sum(status == "FAIL");
n_skip = sum(status == "SKIP");
fprintf('%d passed, %d failed, %d skipped\n\n', ...
    sum(status == "PASS"), n_fail, n_skip);

if n_fail > 0 && nargout == 0
    error('run_all:fail', '%d check(s) failed -- see the table above.', n_fail);
end
end

% -------------------------------------------------------------------------
function tf = production_files_present()
% The dominance check on production files needs a glide/freetau pair for at
% least one tenure, in whichever coordinate system is active.
gs = utility.grid_suffix();
d  = utility.output_dir();
tf = isfile(fullfile(d, sprintf('combined_renter%s.mat', gs))) ...
  && isfile(fullfile(d, sprintf('combined_renter_freetau%s.mat', gs)));
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

function tf = is_script(path)
% First line that is neither blank nor a comment: a function file opens with
% 'function', a script does not.
tf = true;
if isempty(path) || ~isfile(path), return; end
fid = fopen(path, 'r');
if fid < 0, return; end
closer = onCleanup(@() fclose(fid));   %#ok<NASGU>
while ~feof(fid)
    ln = strtrim(fgetl(fid));
    if isempty(ln) || startsWith(ln, '%'), continue; end
    tf = ~startsWith(ln, 'function');
    return
end
end

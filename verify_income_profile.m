%VERIFY_INCOME_PROFILE  Sanity-check the new p.income_source='table' path.
%
%   Run from the repo root (where +config lives):
%       matlab -batch verify_income_profile
%   or from inside MATLAB:
%       run verify_income_profile
%
%   This was written and its expected numbers were computed with a
%   Python re-implementation of the same logic (no MATLAB was available
%   in that environment) -- it has NOT been run against the real
%   income_profile.m / income_table_bkv.m. Please run it for real before
%   trusting the new code path. If anything fails, the assertion message
%   will say which (age, sex) pair and by how much.

fprintf('--- verify_income_profile ---\n');

p = config.params();

% Expected exp(logY) at check ages, by p.sex (1=men, 2=women, 3=pooled),
% computed independently in Python from the same table + extrapolation
% logic. Tolerance is loose (0.5%) since these are cross-checking logic,
% not bit-for-bit reproduction.
%
% Ages 20 and 24 dropped from this list: with the current default
% p.age0=25 they fall outside the modeled age range (20 < age0; 24 is the
% table's omitted reference age, one year before work_ages starts) and
% would not be found in the model's age grid.
check_ages = [25, 45, 54, 55, 64];
expected = struct( ...
    's1', [33000, 59532, 63213, 63213, 51239], ...  % men
    's2', [30000, 49462, 51480, 50968, 43432], ...  % women
    's3', [31500, 54325, 57110, 56826, 47228]);     % pooled

expected_peak_age = struct('s1', 54, 's2', 51, 's3', 51);

tol_rel = 0.005;  % 0.5% relative tolerance
all_ok = true;

for sex = 1:3
    p.sex = sex;
    p.income_source = 'table';

    [logY, mu_growth, sigma_l_log] = config.income_profile(p); %#ok<ASGLU>

    ages = (p.age0 : p.age0 + p.T - 1).';
    Y = exp(logY);

    fname = sprintf('s%d', sex);
    exp_vals = expected.(fname);

    fprintf('\nsex=%d:\n', sex);
    for k = 1:numel(check_ages)
        a = check_ages(k);
        idx = find(ages == a, 1);
        if isempty(idx)
            error('verify:ageNotFound', 'age %d not found in model age grid', a);
        end
        got = Y(idx);
        exp_v = exp_vals(k);
        rel_err = abs(got - exp_v) / exp_v;
        status = 'OK';
        if rel_err > tol_rel
            status = 'MISMATCH';
            all_ok = false;
        end
        fprintf('  age %2d: got %8.0f, expected %8.0f  (%s)\n', a, got, exp_v, status);
    end

    % Peak age over the working span
    work_idx = 1:(p.t_ret - 1);
    [~, peak_rel_idx] = max(Y(work_idx));
    peak_age = ages(peak_rel_idx);
    exp_peak = expected_peak_age.(fname);
    fprintf('  peak age: got %d, expected %d  (%s)\n', peak_age, exp_peak, ...
        ternary(peak_age == exp_peak, 'OK', 'MISMATCH'));
    if peak_age ~= exp_peak
        all_ok = false;
    end

    % mu_growth / sigma_l_log basic sanity: right length, sigma zero at
    % and after retirement transition.
    assert(numel(mu_growth) == p.T - 1, 'mu_growth wrong length for sex=%d', sex);
    assert(numel(sigma_l_log) == p.T - 1, 'sigma_l_log wrong length for sex=%d', sex);
    assert(all(sigma_l_log(p.t_ret - 1:end) == 0), ...
        'sigma_l_log should be zero from the retirement transition onward (sex=%d)', sex);
end

% Confirm 'poly' mode still runs without error (backward compatibility).
p.income_source = 'poly';
try
    [~, ~, ~] = config.income_profile(p);
    fprintf('\n''poly'' mode: OK (still runs)\n');
catch ME
    all_ok = false;
    fprintf('\n''poly'' mode: FAILED -- %s\n', ME.message);
end

fprintf('\n--- %s ---\n', ternary(all_ok, 'ALL CHECKS PASSED', 'SOME CHECKS FAILED -- see above'));
if ~all_ok
    error('verify_income_profile:failed', 'One or more checks failed, see log above.');
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end

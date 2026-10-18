function T = size_table(step, arm, cases, ref)
%SIZE_TABLE  Grid size against accuracy: each case's largest gap to a reference, by age band.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       T = size_table(16, 'owner', ["pow3_20x20_lim_u3p2", "pow3_24x16_lim_u3p2"], ...
%                      "pow3_32x32_lim_u3p2")
%
%   One row per case: the realised nodes on (u1, u2, u3, q), the nodes solved
%   per age while q is a state and after, the solve time, and the largest gap
%   to the reference in mean consumption (share of the reference) and in the
%   mean liquid equity share, in each of the age bands 25-39, 40-54, 55-66,
%   67-89 and 90-95, over the same simulated households. A band passes when
%   both gaps are inside the ladder's stop rule (2% and 0.02). The last
%   column says whether every band from 40 on passes. A second block gives
%   the equity share of liquid saving (case_load's piw), which gives no weight
%   to households that save nothing. A third reads each case's policies at
%   the reference's households (policy_gaps), which leaves out the wealth
%   households bring to an age from earlier, unconverged years. A fourth
%   gives each case's roughness,
%   reference included: the largest second difference over age of mean
%   consumption (% of mean income) and of the mean equity share, inside each
%   band. Bands end at the mortgage's end (55) and retirement (67), so those
%   kinks are not counted. A grid rougher than the reference is suspect; a
%   smooth one is not thereby accurate. Cases not solved yet are skipped.

arguments
    step
    arm (1,:) char
    cases (1,:) string
    ref (1,1) string
end

bands = {[25 39], [40 54], [55 66], [67 89], [90 95]};
names = cellfun(@(b) sprintf('%d-%d', b), bands, 'UniformOutput', false);
r0 = case_load(step, arm, char(ref));
assert(~isempty(r0), 'size_table:ref', 'the reference %s (%s) is not solved.', ref, arm);

rows = {};
for c = unique([ref, cases], 'stable')
    r = case_load(step, arm, char(c));
    if isempty(r), fprintf('%s (%s) not solved, skipped\n', c, arm); continue; end
    p = r.p;
    n3 = p.N_u1 * p.N_u2 * p.N_u3;
    G = case_gaps(r, r0, bands);
    ok = G.C <= 0.02 & G.pi <= 0.02;
    [rC, rpi] = roughness(r.summary, bands);
    P = policy_gaps(r, r0, bands);
    okP = P.C <= 0.02 & P.pi <= 0.02;
    rows(end + 1, :) = {char(c), sprintf('%dx%dx%dx%d', p.N_u1, p.N_u2, p.N_u3, p.N_q), ...
        n3 * p.N_q, n3, r.timing.solve_sec / 60, r.checks.ce_entry, r.checks.floored_share, ...
        100 * G.C, G.pi, G.piw, all(ok(2:end)), 100 * rC, rpi, ...
        100 * P.C, P.pi, all(okP(2:end))}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'case', 'nodes', 'per_age_q', 'per_age', 'minutes', ...
    'entry', 'floored', 'C_pct', 'pi', 'piw', 'pass_40', 'rough_C_pct', 'rough_pi', ...
    'pol_C_pct', 'pol_pi', 'pol_pass_40'});

fprintf('\n%s, step %s, against %s. Largest gap by age band: consumption %% / mean liquid equity share\n', ...
    arm, string(step), ref);
fprintf('| case | nodes | per age (q state / after) | minutes | entry | floored |');
fprintf(' %s |', names{:}); fprintf(' from 40 |\n');
fprintf('|---|---|---|---|---|---|'); fprintf('%s', repmat('---|', 1, numel(bands) + 1)); fprintf('\n');
for i = 1:height(T)
    fprintf('| %s | %s | %d / %d | %.0f | %.4f | %.2f%% |', T.case{i}, T.nodes{i}, ...
        T.per_age_q(i), T.per_age(i), T.minutes(i), T.entry(i), 100 * T.floored(i));
    for b = 1:numel(bands)
        flag = '';
        if T.C_pct(i, b) > 2 || T.pi(i, b) > 0.02, flag = ' *'; end
        fprintf(' %.1f / %.3f%s |', T.C_pct(i, b), T.pi(i, b), flag);
    end
    yes = 'no'; if T.pass_40(i), yes = 'yes'; end
    fprintf(' %s |\n', yes);
end
fprintf('(* outside the stop rule)\n');
fprintf('\nEquity share of liquid saving (piw), largest gap by band:\n');
fprintf('| case |'); fprintf(' %s |', names{:}); fprintf('\n');
fprintf('|---|'); fprintf('%s', repmat('---|', 1, numel(bands))); fprintf('\n');
for i = 1:height(T)
    fprintf('| %s |', T.case{i}); fprintf(' %.3f |', T.piw(i, :)); fprintf('\n');
end
fprintf('\nPolicies on the reference''s households (policy_gaps): consumption %% / mean liquid equity share\n');
fprintf('| case |'); fprintf(' %s |', names{:}); fprintf(' from 40 |\n');
fprintf('|---|'); fprintf('%s', repmat('---|', 1, numel(bands) + 1)); fprintf('\n');
for i = 1:height(T)
    fprintf('| %s |', T.case{i});
    for b = 1:numel(bands)
        flag = '';
        if T.pol_C_pct(i, b) > 2 || T.pol_pi(i, b) > 0.02, flag = ' *'; end
        fprintf(' %.1f / %.3f%s |', T.pol_C_pct(i, b), T.pol_pi(i, b), flag);
    end
    yes = 'no'; if T.pol_pass_40(i), yes = 'yes'; end
    fprintf(' %s |\n', yes);
end
fprintf('\nRoughness, largest second difference over age inside each band: consumption (%% of income) / equity share\n');
fprintf('| case |'); fprintf(' %s |', names{:}); fprintf('\n');
fprintf('|---|'); fprintf('%s', repmat('---|', 1, numel(bands))); fprintf('\n');
for i = 1:height(T)
    fprintf('| %s |', T.case{i});
    fprintf(' %.2f / %.3f |', [T.rough_C_pct(i, :); T.rough_pi(i, :)]);
    fprintf('\n');
end
end

function [rC, rpi] = roughness(s, bands)
% Largest |second difference| over age inside each band, of mean consumption
% (share of mean income at that age, which stays readable where consumption
% is near 0) and of the mean liquid equity share. Only ages whose two
% neighbours are in the same band count.
a = s.ages;
C = s.C.mean(:).'; P = s.pi(:).'; Y = s.Y.mean(:).';
d2C = abs(C(3:end) - 2 * C(2:end-1) + C(1:end-2)) ./ Y(2:end-1);
d2P = abs(P(3:end) - 2 * P(2:end-1) + P(1:end-2));
mid = a(2:end-1);
rC = nan(1, numel(bands)); rpi = rC;
for b = 1:numel(bands)
    w = mid > bands{b}(1) & mid < bands{b}(2);
    if any(w), rC(b) = max(d2C(w)); rpi(b) = max(d2P(w)); end
end
end

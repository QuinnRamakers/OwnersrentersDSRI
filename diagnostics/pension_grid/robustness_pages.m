function robustness_pages(steps, arms, ref_name, groups, out_dir)
%ROBUSTNESS_PAGES  figures.robustness pages of the grid study, one per step and arm.
%
%   robustness_pages([9 10 11 12], {'renter', 'owner'}, 'pow3_96x96', ...
%       struct('name', {'Uniform', 'Bunched, power 3'}, ...
%              'cases', {{'standard', 'uniform_32x32', 'uniform_64x64'}, ...
%                        {'pow3_16x16', 'pow3_32x32', 'pow3_64x64'}}), out_dir)
%
%   The reference (black) is the case ref_name; each group is a row with its
%   cases in colour. Cases not solved are left out. Pages are written as
%   grid_NN_<step>_<arm>.png in out_dir.

S = ladder.steps();
if ~isfolder(out_dir), mkdir(out_dir); end
for st = steps
    k = ladder.index(st, S);
    for a = arms
        ref = case_load(st, a{1}, ref_name);
        if isempty(ref), continue; end
        G = struct('name', {}, 'rs', {}, 'labels', {});
        for g = 1:numel(groups)
            rs = {}; labels = {};
            for c = groups(g).cases
                r = case_load(st, a{1}, c{1});
                if isempty(r), continue; end
                rs{end+1} = r; %#ok<AGROW>
                labels{end+1} = sprintf('%s: %d x %d points, %.0f s', c{1}, r.p.N_u1, r.p.N_u2, r.timing.solve_sec); %#ok<AGROW>
            end
            if ~isempty(rs)
                G(end+1) = struct('name', groups(g).name, 'rs', {rs}, 'labels', {labels}); %#ok<AGROW>
            end
        end
        if isempty(G), continue; end
        ttl = sprintf('Step %s, %s: %s. Grid study of the DC branch', ladder.number(k, S), S(k).label, a{1});
        lab = sprintf('%s (%d x %d points, gh_n %d)', ref_name, ref.p.N_u1, ref.p.N_u2, ref.p.gh_n);
        out = fullfile(out_dir, sprintf('grid_%s_%s_%s.png', ladder.number(k, S, true), S(k).name, a{1}));
        figures.robustness(ref, lab, G, ttl, out);
        fprintf('Wrote %s\n', out);
    end
end
end

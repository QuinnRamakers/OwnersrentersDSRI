function [dims, gh_n] = production_grid(~)
%helper function to make a specific grid
dims_default = [28 20 20];
gh_default   = 7;
[dims, gh_n] = utility.grid_override(dims_default, gh_default);
end

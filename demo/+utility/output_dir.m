function d = output_dir()
% Output directory helper function
d = getenv('CGM_OUTPUT_DIR');
if isempty(d)
    d = pwd;
end
if ~isfolder(d)
    mkdir(d);
end
end

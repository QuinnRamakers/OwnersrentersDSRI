function d = output_dir()
%OUTPUT_DIR  Directory for run outputs (.mat / .png / .txt logs).
%
%   Set CGM_OUTPUT_DIR so cluster runs write to a mounted persistent volume
%   rather than the pod's ephemeral filesystem, which is wiped on restart.
%   Attach a PVC via Topology > Add Storage and point CGM_OUTPUT_DIR at the
%   mount path, e.g. `setenv CGM_OUTPUT_DIR /data` before launching MATLAB.
%   Falls back to the current directory when unset.

d = getenv('CGM_OUTPUT_DIR');
if isempty(d)
    d = pwd;
end
if ~isfolder(d)
    mkdir(d);
end
end

function d = output_dir()
%OUTPUT_DIR  Directory for run outputs (.mat / .png / .txt logs).
%
%   Overridable via the CGM_OUTPUT_DIR environment variable so runs write to
%   a mounted OpenShift persistent volume instead of the pod's ephemeral
%   filesystem (which is wiped on pod restart -- see the DSRI storage docs:
%   attach a PVC to the pod via Topology > Add Storage, note the mount path
%   you choose there, then set CGM_OUTPUT_DIR to that same path, e.g.
%   `setenv CGM_OUTPUT_DIR /data` before launching MATLAB, or export it in
%   the pod's start script). Falls back to the current directory when unset
%   (e.g. local runs).

d = getenv('CGM_OUTPUT_DIR');
if isempty(d)
    d = pwd;
end
if ~isfolder(d)
    mkdir(d);
end
end

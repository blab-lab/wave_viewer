function [option_names,option_values] = make_option_specs(varargin)

if mod(nargin,2) ~= 0, error('must have even number of args (args are key/value pairs)'); end

nopts = nargin/2;

for iopt = 1:nopts
  iarg_opt_name = 2*(iopt-1) + 1;
  iarg_opt_val  = 2*iopt;
  option_names{iopt} = varargin{iarg_opt_name};
  if ~ischar(option_names{iopt}), error('expecting option arg(%d) to be an option name',iarg_opt_name); end
  option_values{iopt} = varargin{iarg_opt_val};
end

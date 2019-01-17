function [option_names,option_values] = make_option_specs(varargin)
%MAKE_OPTION_SPECS  Separate keys and values from key-value pairs.

if mod(nargin,2)
    error('Must have even number of args (args are key/value pairs)');
end

nopts = nargin/2;
option_names = cell(1,nopts);
option_values = cell(1,nopts);

for iopt = 1:nopts
    iarg_opt_name = 2*(iopt-1) + 1;    
    option_names{iopt} = varargin{iarg_opt_name};
    if ~ischar(option_names{iopt})
        error('expecting option arg(%d) to be an option name',iarg_opt_name);
    end
    
    iarg_opt_val  = 2*iopt;
    option_values{iopt} = varargin{iarg_opt_val};
end

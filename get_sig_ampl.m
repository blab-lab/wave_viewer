function amplsig = get_sig_ampl(sig,fs,ms_akern,expon,yes_verbose)
% function amplsig = get_sig_ampl(sig,fs,[ms_akern],[expon],[yes_verbose])
% for example:
% ms_akern = 30; % milliseconds (the default)
% expon = 2 (the default)

if nargin < 5 || isempty(yes_verbose)
  yes_verbose = 0;
end
if nargin < 4 || isempty(expon)
  expon = 2;
end
if nargin < 3 || isempty(ms_akern)
  ms_akern = 30;
end

if yes_verbose, fprintf('getting sig ampl...'); end
akern = hann(round(fs*ms_akern/1000));
cahsig = conv((abs(hilbert(sig))).^expon,akern);
lencsig = length(cahsig);
klen = length(akern);
istart = round(klen/2);
excesslen = klen - istart;
amplsig = cahsig(istart:(lencsig-excesslen));
if yes_verbose, fprintf('done\n'); end

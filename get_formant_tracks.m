function [ftrack_out,ftrack_mstaxis,ftrack_lpc_coeffs] = get_formant_tracks(y,fs,faxis,ms_framespec,nlpc_coeffs,yes_preemph,nformants,ftrack_method,yes_verbose)

frames_per_dot = 10;
dots_per_line = 50;

if nargin < 2 || isempty(fs), fs = 11025; end
if nargin < 3 || isempty(faxis), faxis = linspace(0,fs/2,1025); end
if nargin < 4 || isempty(ms_framespec), ms_framespec = 'narrowband'; end
if nargin < 5 || isempty(nlpc_coeffs), nlpc_coeffs=14; end
if nargin < 6 || isempty(yes_preemph), yes_preemph = 1; end
if nargin < 7 || isempty(nformants), nformants = 0; end
if nargin < 8 || isempty(ftrack_method), ftrack_method = 'mine'; end
if nargin < 9 || isempty(yes_verbose), yes_verbose = 0; end

params.fs = fs;
params.nlpc = nlpc_coeffs;
switch ftrack_method
  case 'colea', ftrack_func = @colea_ftrack_func; params.nformants_max = 3; 
  case 'mine',  ftrack_func = @my_ftrack_func;    params.nformants_max = 3;
  case 'mine2', ftrack_func = @my_ftrack_func2;   params.nformants_max = 4;
  otherwise, error('formant tracking method(%s) unrecognized',ftrack_method);
end
if ~nformants, nformants = params.nformants_max; end
if nformants > params.nformants_max, error('nformants(%d) > nformants_max(%d)',nformants,nformants_max); end
params.nformants = nformants;
params.faxis = faxis;

starting_formants = [500 1500 2500 3500];

[nsamps,yes_y_is_rowvec] = get_len_yvec(y);
[ms_awin,ms_astep,nsamps_frame,nsamps_astep] = get_ms_framespec(ms_framespec,fs);
win = hann(nsamps_frame)/sum(hann(nsamps_frame));
if ~yes_y_is_rowvec, win = win'; end
y = my_preemph(y,yes_preemph);
nframes = floor((nsamps - nsamps_frame)/nsamps_astep);
ftrack = zeros(nformants,nframes);
ftrack_mstaxis = zeros(1,nframes);
lpc_coeffs = zeros((nlpc_coeffs+1),nframes);
for iframe = 1:nframes;
  yframe = y((iframe-1)*nsamps_astep + (1:nsamps_frame));
  ftrack_mstaxis(iframe) = 1000*mean((iframe-1)*nsamps_astep + (1:nsamps_frame))/fs;
  ywinframe = win .* yframe;
  if iframe > 1, params.Fprev = ftrack(:,iframe-1); else params.Fprev = starting_formants; end
  output = ftrack_func(ywinframe,params);
  ftrack(:,iframe) = output{1};
  lpc_coeffs(:,iframe) = output{2};
  if yes_verbose
    if ~rem(iframe,frames_per_dot), fprintf('.'); end
    if ~rem(iframe,frames_per_dot*dots_per_line), fprintf('%d\n',iframe); end
  end
end
ftrack_out(1:nformants,1:nframes) = ftrack(1:nformants,1:nframes);
if yes_verbose
  fprintf('%d\n',iframe);
end
if nargout >= 3, ftrack_lpc_coeffs = lpc_coeffs; end


% must have colea on matlab path to use this function
function output = colea_ftrack_func(ywinframe,params)

fs = params.fs;
nlpc_coeffs = params.nlpc;
nformants = params.nformants;

lpc_coeffs = lpc(ywinframe,nlpc_coeffs);
[frmnt(1),frmnt(2),frmnt(3)] = frmnts(lpc_coeffs,fs);
formant(1:nformants) = frmnt(1:nformants);

output{1} = formant;
output{2} = lpc_coeffs;

function output = my_ftrack_func(ywinframe,params)

fs = params.fs;
nlpc_coeffs = params.nlpc;
nformants = params.nformants;

lpc_coeffs = lpc(ywinframe,nlpc_coeffs);
[frmnt(1),frmnt(2),frmnt(3)] = my_frmnts(lpc_coeffs,fs);

formant(1:nformants) = frmnt(1:nformants);

output{1} = formant;
output{2} = lpc_coeffs;


function output = my_ftrack_func2(ywinframe,params)

fs = params.fs;
faxis = params.faxis;
nlpc_coeffs = params.nlpc;
nformants = params.nformants;
Fprev = params.Fprev;

lpc_coeffs = lpc(ywinframe,nlpc_coeffs);
lpc_magspec = get_lpc_magspec(lpc_coeffs,faxis,fs);
[lpc_magspec_peaks,nlpc_magspec_peaks] = peakfind(lpc_magspec);
for iformant = 1:nformants
  if iformant < nlpc_magspec_peaks
    formant(iformant) = faxis(lpc_magspec_peaks(iformant));
  elseif iformant == nlpc_magspec_peaks
    formant(iformant) = faxis(lpc_magspec_peaks(iformant));
    if abs(Fprev(iformant)-formant(iformant)) > 75
        formant(iformant) = Fprev(iformant);
    end
  else
    formant(iformant) = Fprev(iformant);
  end
end

output{1} = formant;
output{2} = lpc_coeffs;


% my version of the colea frmnts function,
% orinally copyright (c) 1998 by Philipos C. Loizou
function [F1,F2, F3]=my_frmnts(lpc_coeffs,fs)

global F1prev F2prev F3prev

min_formant_freq =   90;
max_formant_freq = 4000;
max_formant_bw   =  500;
defaultF1 = 300; defaultF2 = 1200; defaultF3 = 3000;

max_allowable_F1dev     = 150;
max_allowable_F2dev     = 150;
min_initial_formant_sep =  80;
min_formant_sep         =  50;

const = fs/(2*pi);
rts = roots(lpc_coeffs);
k = 1;
for i=1:length(lpc_coeffs)-1
  re = real(rts(i)); im = imag(rts(i));
  the_formant_cand = const*atan2(im,re);   %--formant frequencies
  formant_bw = -0.5*const*log(abs(rts(i)));%--formant bandwidth
  if (the_formant_cand < max_formant_freq) & ...
     (the_formant_cand > min_formant_freq) & ...
     (formant_bw < max_formant_bw)
    unsort_candidate_formant(k) = the_formant_cand;
    bandw(k) = formant_bw;
    k = k + 1;
  end
end
candidate_formant = sort(unsort_candidate_formant);
ncand_formants = length(candidate_formant);

if isempty(F1prev) %++++++++++++++++ the first frame ++++++++++++++++++
  if 2 > ncand_formants
    F1 = defaultF1; F2 = defaultF2; F3 = defaultF3;
  elseif abs(candidate_formant(1)-candidate_formant(2)) < min_initial_formant_sep
    F1 = candidate_formant(2); F2 = candidate_formant(3);
    if 3 > ncand_formants, F3 = candidate_formant(4); else F3 = defaultF3; end
  elseif 4 == ncand_formants
    F1 = candidate_formant(2); F2 = candidate_formant(3);
    F3 = candidate_formant(4);
  else
    F1 = candidate_formant(1); F2 = candidate_formant(2); 
    if 3 > ncand_formants, F3 = defaultF3; else F3 = candidate_formant(3); end
  end
else %++++++++++++++++ all frames after the first ++++++++++++++++++
     %----Impose some formant continuity constraints -------------------
  in1 = find(abs(F1prev-candidate_formant) < max_allowable_F1dev);
  in2 = find(abs(F2prev-candidate_formant) < max_allowable_F2dev);
  if length(in1) > 1, i1 = in1(2); else i1 = in1; end;
  if length(in2) > 1, i2 = in2(2); else i2 = in2; end;
  
  switch (10*(~isempty(i1)) + (~isempty(i2)))
    case 11,
      if i1 == i2
        if 1 > ncand_formants, F1 = F1prev; else F1 = candidate_formant(1); end
        if 2 > ncand_formants, F2 = F2prev; else F2 = candidate_formant(2); end
        if 3 > ncand_formants, F3 = F3prev; else F3 = candidate_formant(3); end
      else
        F1 = candidate_formant(i1); F2 = candidate_formant(i2); 
        if i2 + 1 > ncand_formants, F3 = F3prev; else F3 = candidate_formant(i2 + 1); end
      end;
    case 10,
      F1 = candidate_formant(i1);
      if i1 + 1 > ncand_formants, F2 = F2prev; else F2 = candidate_formant(i1 + 1); end
      if i1 + 2 > ncand_formants, F3 = F3prev; else F3 = candidate_formant(i1 + 2); end
    otherwise
      F1 = candidate_formant(1);
      if 2 > ncand_formants, F2 = F2prev; else F2 = candidate_formant(2); end
      if 3 > ncand_formants, F3 = F3prev; else F3 = candidate_formant(3); end
  end
end

% --last check .. --------
if abs(F2-F3) < min_formant_sep, F2 = F2prev; F3 = F3prev; end
if abs(F2-F1) < min_formant_sep, F2 = F2prev; F3 = F3prev; end

F1prev = F1; F2prev = F2; F3prev = F3;

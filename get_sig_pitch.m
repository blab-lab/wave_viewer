function [pitchsig,yanalframelen_out,ystep_out,nframes_out] = ...
    get_sig_pitch(sig,fs,pitchlimits,yanalframe_ms,yanalstep_ms,yes_verbose)
% function [pitchsig,[yanalframelen_out],[ystep_out],[nframes_out]] = ...
%     getwavepitch(sig,fs,pitchlimits,[yanalframe_ms],[yanalstep_ms],[yes_verbose])
% for example:
% pitchlimits = [150 300]; % Hz limits for pitch for isubj = 1
% yanalframe_ms = 30; % milliseconds (the default)
% yanalstep_ms  = 10; % milliseconds (the default)

if nargin < 6 || isempty(yes_verbose)
  yes_verbose = 0;
end
if nargin < 5 || isempty(yanalstep_ms)
  yanalstep_ms = 10;
end
if nargin < 4 || isempty(yanalframe_ms)
  yanalframe_ms = 30;
end

[rows_sig,cols_sig] = size(sig);
yes_transpose = 0;
if cols_sig > 1
  if rows_sig > 1
    error('sig cannot be a matrix');
  else
    yes_transpose = 1;
  end
end

if yes_transpose
  sig = sig';
end

yanalframelen = round(fs*yanalframe_ms/1000);
ystep = round(fs*yanalstep_ms/1000);
nsamps = length(sig);
nframes = floor(nsamps/ystep);

nfft_choices = 2.^(9:15);
idx_choices = find(nfft_choices > 2*yanalframelen);
nfft = nfft_choices(idx_choices(1));
nchan = nfft/2;
freqsep = (fs/2)/nchan;

yacfft_ifreq_llim = round(pitchlimits(1)/(2*freqsep)); % try limiting llim to half the lowest pitch limit
if yacfft_ifreq_llim < 1, yacfft_ifreq_llim = 1; end
if yacfft_ifreq_llim > nchan, yacfft_ifreq_llim = nchan; end
yacfft_ifreq_ulim = round(pitchlimits(2)/freqsep);
if yacfft_ifreq_ulim < 1, yacfft_ifreq_ulim = 1; end
if yacfft_ifreq_ulim > nchan, yacfft_ifreq_ulim = nchan; end
ishortest_period = round(fs/pitchlimits(2));
ilongest_period = round(fs/pitchlimits(1));

Yanalframe = zeros(yanalframelen,1);
zeroimag = zeros(nfft,1);
pitch = zeros(1,nframes);
if yes_verbose
  fprintf('getting sig pitch:\n');
  fprintf('%d frames to process\n',nframes);
end
for ifr = 1:nframes
  if yes_verbose
    if ~rem(ifr, 100), fprintf('.'); end
    if ~rem(ifr,5000), fprintf('%d\n',ifr); end
  end
  Ynewchunk = sig(((ifr-1)*ystep + 1):(ifr*ystep));
  imidframe(ifr) = mean(((ifr-1)*ystep + 1):(ifr*ystep));
  Yanalframe = [Yanalframe((ystep+1):yanalframelen); Ynewchunk];
  
  % following is based on e:/acad/fusp/matlab/harm_noise_quat/getpitch5.m
  yfft = fft(Yanalframe,nfft);
  fullmagyfft = abs(yfft);          % the word 'full' indicates nfft sized,
  fullpspecy = fullmagyfft.^2;      % instead of the usual nchan sized
  filt_fullpspecy = fullpspecy;                 % don't try to use only half of fullpspecy:
  filt_fullpspecy(1:(yacfft_ifreq_llim-1)) = 0; % it won't give an accurate pitch period
  filt_fullpspecy((end-yacfft_ifreq_llim+1):end) = 0;
  filt_fullpspecy((yacfft_ifreq_ulim+1):(end-yacfft_ifreq_ulim)) = 0;
  yacfft = complex(filt_fullpspecy,zeroimag);
  pre_acorr = ifft(yacfft);
  yac = real(pre_acorr(1:yanalframelen)); % real(...) gets rid of tiny imaginary values
  yacsel = yac(ishortest_period:ilongest_period);
  [ipyac,npyac] = peakfind(yacsel);
  if npyac > 0
    apyac = yacsel(ipyac);
    [max_apyac,imax_apyac] = max(apyac);
    ipyac2use = ipyac(imax_apyac);
    [pyac2use,duh] = fitpeak(yacsel,ipyac2use);
    % the final '- 1' below is because yac(1) represents lag 0 in the autocorrelation
    pitch_period = (pyac2use + ishortest_period - 1) - 1; 
    pitch(ifr) = fs/pitch_period;
    % in magspec, ipitch = pitch/freqsep (ipitch is a fractional number)
    % then pitch harmonics at n*ipitch + 1, for n = 1,2,...
    % use this to compute harmonics-to-noise ratio from magspec
  else
    apyac = [];
    max_apyac = 0;
    imax_apyac = 0;
    ipyac2use = 0;
    pyac2use = 0;
    pitch_period = NaN;
    pitch(ifr) = NaN;
  end
end
if yes_verbose
  fprintf('%d\n',ifr);
end

if yes_verbose, fprintf('interpolating...'); end
imidframe4interp = [1 imidframe nsamps];
pitch4interp = [0 pitch 0];
w = warning('off','MATLAB:interp1:NaNinY'); % turns off warning
pre_pitchsig = interp1(imidframe4interp,pitch4interp,1:nsamps);
warning(w);                                 % restores old warning prefs
if yes_verbose, fprintf('done\n'); end

if yes_verbose, fprintf('lowpass filtering...'); end
[B,A] = butter(5,((1000/(2*yanalframe_ms))/(fs/2)));
% pitchsig = filtfilt(B,A,pre_pitchsig);
pitchsig = pre_pitchsig;
if yes_verbose, fprintf('done\n'); end
if yes_verbose, fprintf('done getting sig pitch\n'); end

if nargout >= 2, yanalframelen_out= yanalframelen; end
if nargout >= 3, ystep_out = ystep; end
if nargout >= 4, nframes_out = nframes; end

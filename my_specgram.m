function [absS_out,F_out,msT_out,nsamp_window_out,nsamp_frame_advance_out] = ...
    my_specgram(y,msToffset,fs,ms_framespec,nfft,yes_preemph,yes_plot)
% function [[absS],[F],[msT],[nsamp_window],[nsamp_frame_advance]] = ...
%     my_specgram(y,msToffset,fs,ms_framespec,nfft,yes_preemph,yes_plot)

if nargin < 2 || isempty(msToffset), msToffset = 0; end
if nargin < 3 || isempty(fs), fs = 11025; end
if nargin < 4 || isempty(ms_framespec), ms_framespec = 'broadband'; end
if nargin < 5 || isempty(nfft), nfft = 4096; end
if nargin < 6 || isempty(yes_preemph), yes_preemph = 1; end
if nargin < 7 || isempty(yes_plot), yes_plot = 1; end

[ms_window,ms_frame_advance,nsamp_window,nsamp_frame_advance] = ...
    get_ms_framespec(ms_framespec,fs);
nsamp_overlap = nsamp_window - nsamp_frame_advance;

ypr = my_preemph(y,yes_preemph);
[S,F,T] = spectrogram(ypr,nsamp_window,nsamp_overlap,nfft,fs);
msT = 1000*T + msToffset;
absS = abs(S);

if yes_plot
  hpl = imagesc(msT,F,20*log10(absS));
  set(get(hpl,'Parent'),'YDir','normal');
  xlabel('time (ms)');
  ylabel('freq (Hz)');
end



if nargout >= 1, absS_out = absS; end
if nargout >= 2, F_out = F; end
if nargout >= 3, msT_out = msT; end
if nargout >= 4, nsamp_window_out = nsamp_window; end
if nargout >= 5, nsamp_frame_advance_out = nsamp_frame_advance; end

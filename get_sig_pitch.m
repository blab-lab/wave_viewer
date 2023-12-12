function [pitchsig,varargout] = ...
    get_sig_pitch(sig,fs,pitchlimits,yanalframe_ms,yanalstep_ms,yes_verbose, params)
% Takes in a signal and returns its pitch (f0). 
%
% If params.ptrack_method is set to 'praat' (the default), other Praat
% settings stored in input arg `params` will be used during the Praat call.
% If params.ptrack_method is not 'praat', the legacy functionality will be
% used: pitch is calculated within this function.
%
% In the Praat method, the `pitchlimits` input argument is igored, and
% params.pitchlimits determines the pitch floor and ceiling.
%
% In the Praat method, the output arguments are like this:
% 1.) `pitchsig`. pitch values. Where Praat did not detect pitch, value is NaN
% 2.) vector of time points (in seconds) aligned with output arg 1
%
% In the non-Praat method, the output arguments are like this:
% 1.) pitch values
% 2.) yanalframelen
% 3.) ystep
% 4.) nframes

if nargin < 7
    params = struct;
end
if nargin < 6 || isempty(yes_verbose)
    yes_verbose = 0;
end
if nargin < 5 || isempty(yanalstep_ms)
    yanalstep_ms = 10;
end
if nargin < 4 || isempty(yanalframe_ms)
    yanalframe_ms = 30;
end

% these same pitch tracking settings are also stored in:
%   free-speech\speech\get_sigproc_defaults.m 
%   wave_viewer\wave_viewer.m\get_sigproc_params
defaultParams.pitchlimits = [50 300];
defaultParams.ptrack_method = 'praat';
defaultParams.max_candidates = 15;
defaultParams.pitch_very_accurate_checkbox = 'no';
defaultParams.silence_thresh = 0.03;
defaultParams.voicing_thresh = 0.45;
defaultParams.octave_cost = 0.01;
defaultParams.octave_jump_cost = 0.35;
defaultParams.voiced_unvoiced_cost = 0.14;
params = set_missingFields(params, defaultParams, 0);

%%
switch params.ptrack_method
    case 'praat'
        % execute Praat script using params
        %must be in git repo folder to run praat function, so save current location and go there
        curr_dir = pwd;
        temp_str = which('get_pitch_tracks.praat');
        praat_path = fileparts(temp_str);
        cd(praat_path)

        %% Praat wrapper code here
        % write y to file (this will be deleted later, it is just written to the
        % current directory)
        audiowrite('temp_wav.wav',sig,fs)

        if ismac
            status = system(['"/Applications/Praat.app/Contents/MacOS/Praat" --run get_pitch_tracks.praat "' pwd '" "temp_wav" ' ...
                num2str(params.pitchlimits(1)) ' ' num2str(params.max_candidates) ' ' params.pitch_very_accurate_checkbox ' ' ...
                num2str(params.silence_thresh) ' ' num2str(params.voicing_thresh) ' ' num2str(params.octave_cost) ' ' ...
                num2str(params.octave_jump_cost) ' ' num2str(params.voiced_unvoiced_cost) ' ' num2str(params.pitchlimits(2))]);
        else
            status = system(['"C:\Users\Public\Desktop\Praat.exe" --run get_pitch_tracks.praat "' pwd '" "temp_wav" ' ...
                num2str(params.pitchlimits(1)) ' ' num2str(params.max_candidates) ' ' params.pitch_very_accurate_checkbox ' ' ...
                num2str(params.silence_thresh) ' ' num2str(params.voicing_thresh) ' ' num2str(params.octave_cost) ' ' ...
                num2str(params.octave_jump_cost) ' ' num2str(params.voiced_unvoiced_cost) ' ' num2str(params.pitchlimits(2))]);
        end
        if status ~= 0
            error('Something went wrong in Praat analysis')
        end

        % load pitch track from file written by Praat 
        ptrack_table = readtable('temp_wav_pitch.txt', 'Delimiter', ',', 'TreatAsMissing', '--undefined--');

        % put in 'pitch' output
        pitchsig = round(ptrack_table.pitch', 2); % TODO decide if we want to keep pitch as floats or to reduce down        
        if nargout <= 2
            varargout{1} = round(ptrack_table.time', 5);  %round to 100s place of ms, which is praat's actual precision
        end

        % clean up by deleting files that were created and return to previous
        % directory
        delete temp_wav.wav temp_wav_pitch.txt
        cd(curr_dir)
    

    otherwise
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

        if nargout >= 2, varargout{1} = yanalframelen; end
        if nargout >= 3, varargout{2} = ystep; end
        if nargout >= 4, varargout{3} = nframes; end

end


end %EOF

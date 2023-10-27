function [ptrack_out,ptrack_mstaxis] = get_pitch_tracks(y,fs,params)
% TODO add header

if nargin < 2
    fs = 11025;
end

defaultParams.pitchlimits = [50 300];
defaultParams.max_candidates = 15;
defaultParams.silence_thresh = 0.03;
defaultParams.voicing_thresh = 0.45;
defaultParams.octave_cost = 0.01;
defaultParams.octave_jump_cost = 0.35;
defaultParams.voiced_unvoiced_cost = 0.14;
params = set_missingFields(params, defaultParams, 0);

% execute Praat script using params
%must be in git repo folder to run praat function, so save current location and go there
curr_dir = pwd;
temp_str = which('get_formant_tracks.praat');
praat_path = fileparts(temp_str);
cd(praat_path)

%% Praat wrapper code here
% write y to file (this will be deleted later, it is just written to the
% current directory)
audiowrite('temp_wav.wav',y,fs)

if ismac
    status = system(['"/Applications/Praat.app/Contents/MacOS/Praat" --run get_pitch_track.praat "' pwd '" "temp_wav" ' ...
        num2str(params.max_candidates) ' ' num2str(params.silence_thresh) ' ' num2str(params.voicing_thresh) ' ' ...
        num2str(params.octave_cost) ' ' num2str(params.octave_jump_cost) ' ' num2str(params.voiced_unvoiced_cost)]);
else
    status = system(['"C:\Users\Public\Desktop\Praat.exe" --run get_pitch_track.praat "' pwd '" "temp_wav" ' ...
        num2str(params.max_candidates) ' ' num2str(params.silence_thresh) ' ' num2str(params.voicing_thresh) ' ' ...
        num2str(params.octave_cost) ' ' num2str(params.octave_jump_cost) ' ' num2str(params.voiced_unvoiced_cost)]);
end
if status ~= 0
    error('Something went wrong in Praat analysis')
end

% clean up praat output text file to eliminate uniterpretable characters
A = regexp( fileread('temp_wav_pitch.txt'), '\n', 'split');
headers = strsplit(A{1},'\t');
if length(headers) == 1 %for some reason Praat sometimes uses a space to separate headers
    headers = strsplit(A{1},' ');
end
for i = 1:length(headers)
    curTxt = headers{i};
    startUnits = strfind(curTxt,'(');
    if ~isempty(startUnits)
        curTxt = curTxt(1:startUnits-1);
        headers{i} = curTxt;
    end
end
A{1} = strjoin(headers,'\t');
fid = fopen('temp_wav_pitch.txt','w');
fprintf(fid, '%s\n', A{:});
fclose(fid);

% load pitch track from file written by Praat and put in 'pitch' output
ptrack_out = readtable('temp_wav_pitch.txt','Delimiter','\t');
ptrack_mstaxis = ptrack_out.time' *  1000; %covert from s to ms

% clean up by deleting files that were created and return to previous
% directory
delete temp_wav.wav temp_wav_pitch.txt %temp_wav_lpc.txt
cd(curr_dir)

end %EOF

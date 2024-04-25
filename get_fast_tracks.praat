# get_fast_tracks.praat by Henry Nomeland, 21 Mar 2024
# adapted from get_formants.praat by Ben Parrell, 18 Dec 2017
#
# measures formants for a .wav file utilizing tools and utils of FastTrack
# FastTrack code available here: https://github.com/santiagobarreda/FastTrack/
# for use with wave_viewer

#Inputs
form Measure formant values for segments in a textgrid
    sentence dir: /Users/Ben/Documents/MATLAB/wave_viewer
    sentence file_name: temp_wav
endform

include utils/trackAutoselectProcedure.praat
@getSettings

formants = 3
time_step = 0.002
steps = 20
coefficients = 5
out_formant = 2
fastTrackMinimumDuration = 0.030000000000001
lowestAnalysisFrequency = 0
highestAnalysisFrequency = 5500

method$ = "burg"
wav_name$ = file_name$ + ".wav"
Read from file... 'dir$'/'wav_name$'
soundID1$ = selected$("Sound")
select Sound 'soundID1$'

@trackAutoselect: selected(), dir$, lowestAnalysisFrequency, highestAnalysisFrequency, steps, coefficients, formants, method$, 0, selected(), 0, 4000, 2, 0, 0

formant = selected ("Formant")

#write formants
formant_name$ = file_name$ + "_formants.txt"
Down to Table... yes yes 6 no 3 yes 3 no 
Save as tab-separated file... 'dir$'/'formant_name$'

#extract LPC parameters
#selectObject: formant
#To LPC... fs
#Down to Matrix (lpc)

#save LPC parameters
#lpc_name$ = file_name$ + "_lpc.txt"
#Save as headerless spreadsheet file... 'directory_name$'/'lpc_name$'

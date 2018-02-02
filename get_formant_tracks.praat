# get_formants.praat
# BEN PARRELL 18 DEC 2017
#
# Measure formants for whole .wav file
# For use with wave_viewer

#Inputs
form Measure formant values for segments in a textgrid
    sentence directory_name: /Users/Ben/Documents/MATLAB/wave_viewer
	sentence file_name: temp_wav
    positive maximum_formant 5500
    positive number_of_formants 5
	positive window_size 0.025
    positive time_step 0.005
	positive preemphasis 50
	positive fs 11025
endform

#open the sound and select it
wav_name$ = file_name$ + ".wav"
Read from file... 'directory_name$'/'wav_name$'
soundID1$ = selected$("Sound")

#extract formants
To Formant (burg)... 'time_step' 'number_of_formants' 'maximum_formant' 'window_size' 'preemphasis'
formant = selected ("Formant")

#write formants
formant_name$ = file_name$ + "_formants.txt"
Down to Table... yes yes 6 no 3 yes 3 no 
Save as tab-separated file... 'directory_name$'/'formant_name$'

#extract LPC parameters
selectObject: formant
To LPC... fs
Down to Matrix (lpc)

#save LPC parameters
lpc_name$ = file_name$ + "_lpc.txt"
Save as headerless spreadsheet file... 'directory_name$'/'lpc_name$'

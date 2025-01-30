# 2-Colour Exocytosis Detection and Analysis <!-- omit in toc -->
This workflow was edited from code previously written by S Royle and M Sittewelle to detect and analyse exocytic events in cells expressing two, differently coloured, pH-sensitive fluorescent reporters simultaneously recorded with two cameras. In other words, this workflow is used to detect exocytic events in two separate channels.

## Contents <!-- omit in toc -->
- [How this works](#how-this-works)
  - [Simplified summary](#simplified-summary)
  - [Detailed summary](#detailed-summary)
- [Usage](#usage)
  - [def-cell-ROI](#def-cell-roi)
  - [exo-analysis](#exo-analysis)
  - [exo-script](#exo-script)
  - [show-peaks](#show-peaks)
- [Questions/Information](#questionsinformation)

## How this works
This following section will describe how this workflow was employed in my MSc thesis (J Poylo 2024). The fluorescent proteins used were superecliptic pHluorin (channel 1) and pHmScarlet (channel 2).

### Simplified summary
***recycle 0***
Spots/puncta of potential exocytosis events are detected in the sepHluorin channel and a region of interest (ROI) is created around it.
- The average fluorescence intensity of sepHluorin within the defined ROI is recorded for the duration of the film, and exocytosis analysis is performed on the collected data.
- The average fluorescence intensity of pHmScarlet with the defined ROI is recorded and exocytosis analysis is performed.

***recycle 1***
The process is repeated and spots/puncta in the pHmScarlet channel get detected.
- The average fluorescence intensity of pHmScarlet with the defined ROI is recorded and exocytosis analysis is performed.
- The average fluorescence intensity of sepHluorin with the defined ROI is recorded and exocytosis analysis if performed.

### Detailed summary
<p align="center">
<img src="supp_info/recycles.png?raw=true" alt="Diagram of FIJI workflow and recycles" width="500"/>
</p>

<!-- After clearing the area outside the cell (outline drawn by the user), a Z projection for maximum intensity in channel 1 is to the image. This will reveal in 2D the brightest value of each pixel across the entire movie. Then, Fiji will apply the `Find Maxima...` tool to identify the brightest spots (where vesicles may have fused with the membrane). A small ROI is drawn around all of these identified spots and the average intensities of the ROI in both channels is recorded for the whole movie. -->
<!-- Then, the process is repeated with the channels inversed, which maximum intensity and spot detection carried out in channel 2. -->

<!-- With these two datasets, analysis of intensities is  -->

A more detailed summary can be in the sections below, or in even deeper detail in the thesis extract under `supp_info/sec2-5.pdf`.

## Usage
The following sections provide instructions to use this code.
**Preface: ** All files used in this project employed the following nomenclature: `{yymmdd}_{protein1}-pHmS_{protein2}-pHl_100x-SoRa.nd2`

Below is the sequential order of programs to run.
1. FIJI
  1.1 `def-cell-ROI.ijm` - Draw ROI around cells in each movie. 
  1.2 `exo-analysis.ijm` - Detect puncta and record intensity.
2. R
  2.1 `exo_script.R` with `exo_functions.R` providing necessary functions. Performs analysis on ROI intensity and returns sparklines as well as csv files including *xy* and *time* coordinates for each peak.
3. FIJI
  3.1 `show-peaks.ijm` - Add ROI around each detected peak in the respective image and save a movie of it if wanted.

### def-cell-ROI
This script is used to create the mask for detecting the puncta of exocytic events later on. This will cycle through all the images in the specified directory and with the right suffix.

All that is needed to be done is to draw with the 'freehand' tool around the desired ROI/cell.
Then click 'OK' in the small pop-up panel, this will save this specified ROI as `{$filename}_cell.ROI` into the output directory.

**Note**: if 'cancel' is clicked at anytime, re-running the macro will skip all files matching its respecive output name. E.g. if image1_cell.ROI exists, it will not be opened.
This macro can also be run as a standalone and re-used for other purposes.

### exo-analysis 
Run this macro when all desired ROIs have been defined. This macro offers the option between selecting exocytosis detection in one or two channel images, select the option as necessary.
The macro will then run silently, with no input is necessary.

**Note**: this macro is dependent on a files named `{$input_imagename}_cell.ROI` being found in the output directory. This macro, as above, will also skip all image which have already been analysed (see lines 35-47).

#### Changing puncta density <!-- omit in toc -->
The density of puncta detected can be modified by changing the value in line 185 (currently 0.55). Currently, lines 172-185 cycle through an increasing higher prominence value until the number of puncta goes below the set threshold. This can be inversed by starting with a high prominence (low number of puncta detected), and lowering the prominence value until the number of puncta exceeds the threshold. To do this, set the desired prominence on line 172, change line 184 to `promi -= 1;`, and line 185 accordingly.

### exo-script
This script will analyse the intensity data from all ROIs recorded with `exo-analysis.ijm` and uses the `findpeaks` package to determine whether these are true exocytic events or not.

Firsty, set up an R project with the following structure/directories:
- Data/
  - *Add all output data from previous steps here*
- Script/
  - `exo_functions.R`
  - `exo_script.R`
- Output/
  - Data/
    - peaks-xyt/
  - Plots/

\***Note**: data from different experiments/repeats were pooled together in this step, so the prefix below was added to all file names. #If I remember this correctly
`JEP{expt_num}-{pHmS_prot}-{pHl_prot}_`

Then, `exo_script.R` can be run. The parameters that can be modified are the following:
- `exo_script.R`
  - `minpeakheight` - minimum height of peak necessary to be detected as an exocytic event.
  - `threshold` - a threshold for peak detection.
  - `threshold2` - a threshold for peak detection. Input as a percentage #percentage of the peak value?
- `exo_functions.R`
  - Look at line 133 & 135 (within the `findpeaks` function)
  - `nups` - number of points before the peak that must follow incremental increase.
  - `ndowns` - number of points after the peak that must succeedingly decrease.

Analysis happens in line 53 & 54.
Intensity data filtered for detected peaks are then saved to `Output/Data/`, with *recycle 0* and *recycle 1* data separate.
The *x*, *y*, and *time* coordinates of each detected peak are also saved to `Output/Data/peaks-xyt`line 63 & 64. This creates a 'master' `.csv` file with the coordinates of each spot detected in all images, but also individual `.csv` files for each image containing a detected peak as well as their coordinates.

### show-peaks
This final script will allow you to see the detected peaks and helps you confirm whether they are indeed exocytic events. It will also allow you to save a small movie of the event as a `.tiff` if desired.

#### Script modes <!-- omit in toc -->
Two different modes to run this script can be run:
 - Show all peaks
 - Open peaks individually

**Show All Peaks**
Show all peaks opens images containing previously detected peaks sequentially (only one image is opened at a time). For each image, each detected peak will be saved into the ROI manager under its peak ID assigned previously. By selecting this ROI, for example by clicking on it in the ROI manager, the movie's frame will be set to that of the peak and an oval ROI will be drawn with the detected event at its center. *(I need to confirm if it is set to the right channel too)*. A dialog box with all the identified peaks will also appear. Check the boxes of the peaks for which you would like to save a movie (see image below).

<p align="center">
<img src="supp_info/show-all-peaks.png?raw=true" alt="Diagram of ROI manager and save image dialog box of Show All Peaks mode" width="400"/>
</p>

**Open Peaks Individually**
Opens each detected peak in a cropped version individually. This mode needs to be updated. It was initially designed to save time by not needing to open each movie entirely and only ~15 frames and about 30x30 px, but the code is not structured in this way at the moment.

This mode has also two further options:
*Visual* - The movie for each peak (with the final formatting) opens one by one, with a dialog box asking you to select whether you want to save it or not.
*Silent* - Movies for all detected peaks are saved. This is run with batchmode set to TRUE, meaning that none of the images appear, thus running silently. *(I forgot if this was fully functional, I will need to check again)*

<p align="center">
<img src="supp_info/open_peaks_indiv.png?raw=true" alt="Diagram of Open Peaks Individually in Visual mode" width="400"/>
</p>

#### Saving the movies <!-- omit in toc -->
The current format for the saved movies is the following:
start: 10 frames before the peak (or frame 1 if the detected peak is before frame 1)
end: 15 frames after the peak (or 15 frames before the end, if the original movie ends before)

The saved movie by default has the dimentions of 37 px by 37 px. The size of this framce can be modified in lines 247 and 248 of the script. Their values must be odd to ensure that the pixel where the peak was initially detected remains perfectly centred.
As with the start and end frames, these values are buffered to not have capture 'out of bounds' pixels.

Selected images will be saved as `{spotID}.tif`into `{output}/{movie-name}_show-peaks-out/`.

## Questions/Information
For any questions, please feel free to create an issue/discussion (or click [here](https://github.com/j-pyl/exo-2-clr/issues/new?template=Blank+issue)).

JEP 01.2025
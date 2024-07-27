// Adaptation of ms105 FIJI script 1
// JEP 07/2024

// V3 - analyse for exocytic events
// Code currently copied over from V2-8_cleaned

// need to insert define global variables and other stuff here.
// maybe do line 9 instead of line 10?
// #@ String (label = "File suffix", value = "_cell.roi") suffix
// #@ String (label = "File suffix", value = ".tif") suffix


function processFile(input, output, file) {
	// Leave the print statements until things work, then remove them.
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);
	
	//// Skip if file exists because it will be run in def-cell-ROI and this will depend on its results?
	
	open(input+File.separator+file);
	origft = getTitle(file);							//// is this redundant with origfn?
	run("Clear Results");
	roiManager("reset");


	//// Below has been copy-pasted from V2-8_cleaned. Need to quickly check all is correct.

	for (i = 0; i < 2; i++) {
		recycle = i
		if (recycle == 0) {
			// Make named duplicates
			run("Duplicate...", "title=template duplicate channels=1");
			run("Duplicate...", "title=subject duplicate channels=2");
			
			// Detect puncta on template
			template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle);
			exo_analysis_general(output, "subject", origfn, recycle);
			
		} else if (recycle == 1) {
			// Make named duplicates
			run("Duplicate...", "title=template duplicate channels=2");
			run("Duplicate...", "title=subject duplicate channels=1");

			// Detect puncta on template
			template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle);
			exo_analysis_general(output, "subject", origfn, recycle);
			// I know this code is doubled and not 'pretty'/conventional, but this is the way I can integrate recycle number into the sequence
			
		} else {
			print("Too many recycles! Recycles >= 1");
			return;
		}
		

		selectImage(origft);	////If I delete origft above, replace with selectImage(file);. origfn WILL NOT work.
		close("\\Others");

	}
	run("Close All");		//// I think this is in the right place.
}
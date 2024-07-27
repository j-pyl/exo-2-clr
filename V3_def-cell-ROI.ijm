// Adaptation of ms105 FIJI script 1
// JEP 07/2024

// V3 - define ROI around cell
// Code currently copied over from V2-8_cleaned

function processFile(input, output, file) {
	// Leave the print statements until things work, then remove them.
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);

	open(input+File.separator+file);
	origft = getTitle(file);							//// is this redundant with origfn?
	run("Clear Results");
	roiManager("reset");

	// Draw ROI around cell and save it	
	cellROI(output, origfn);		// output file name = origfn + "_cell.roi
}




	//------------------------------------------------------------------------------------------------------------------------------------
// THIS FUNCTION WORKS. DO NOT MODIFY FOR THE MOMENT.
// Save ROI of shape drawn around cell. This most probably can get shortened a decent bit.
function cellROI(output, fn) {
	selectImage("template");
	run("Z Project...", "projection=[Max Intensity]");		//// Need to make sure that the correct image is selected at this point.
	run("Enhance Contrast", "saturated=0.35");

	// Draw around the cell and save that ROI
	waitForUser("Draw around the cell", "Draw around the cell");
	roiManager("add");
	roiManager("Save", output + "/" + fn + "_cell.roi");
	
	// A bunch of junk that can be removed? Probably need to keep 'select none' and a final 'close' to close the Z profile result window.
	run("Set Measurements...", "area redirect=None decimal=3");
	run("Measure");
	Area = getResult("Area", 0);
	run("Close" );
	print("area="+Area);
	run("Clear Results");
	run("Clear Outside");
	run("Select None");
	run("Close");
	run("Close");
}
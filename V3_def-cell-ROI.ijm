// Adaptation of ms105 FIJI script 1
// JEP 07/2024

// V3 - define ROI around cell
// Code currently copied over from V2-8_cleaned

// Using process folder FIJI template
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix

processFolder(input);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}


function processFile(input, output, file) {
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);

	// Skip original/parent file if it has already been analysed
	if (File.Exists(output + File.separator + origfn + "-" + 1 + "_IntensityData.csv")) {
		print(origfn + "-" + 1 + "_IntensityData.csv already exists. Image skipped.");
		return;		
	}

	// Open file and set up workspace
	open(input+File.separator+file);
	run("Clear Results");
	roiManager("reset");

	run("Duplicate...", "title=template duplicate channels=1");

	// Draw ROI around cell and save it	
	cellROI(output, origfn);		// output file name = origfn + "_cell.roi

	run("Close All");
}




//------------------------------------------------------------------------------------------------------------------------------------
// Save ROI of shape drawn around cell. This most probably can get shortened a decent bit.
function cellROI(output, fn) {
	selectImage("template");
	run("Z Project...", "projection=[Max Intensity]");
	run("Enhance Contrast", "saturated=0.35");

	// Draw around the cell and save that ROI
	waitForUser("Draw around the cell", "Draw around the cell");
	roiManager("add");
	roiManager("Save", output + "/" + fn + "_cell.roi");
	
	//// A bunch of junk that can be removed?
	//// Probably need to keep 'select none' and a final 'close' to close the Z profile result window. Don't even need this with V3? Final close all does the job?
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
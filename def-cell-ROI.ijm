// Adaptation of ms105 FIJI script 1
// JEP 09/2024

// V4 - define ROI around cell
// Current version: V4

// Using process folder FIJI template
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".nd2") suffix

processFolder(input);
showMessage("Process Folder", "Process folder complete.\nWhole folder processed.");

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
	if (File.exists(output + File.separator + origfn + "_cell.roi")) {
		print(origfn + "_cell already exists. Image skipped.");
		return;		
	}
	if (origfn=="0-tetraspeck") return; // Skip registration file

	// Open file and set up workspace
	s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT";
	run("Bio-Formats Importer", s);
	run("Clear Results");
	roiManager("reset");

	run("Duplicate...", "duplicate channels=1");

	// Draw ROI around cell and save it	
	cellROI(output, origfn);		// output file name = origfn + "_cell.roi"

	run("Close All");
}


//---------------------------------------------------------------------------------------------------------------
// Save ROI of shape drawn around cell. This most probably can get shortened a decent bit.
function cellROI(output, fn) {
	run("Z Project...", "projection=[Max Intensity]");
	run("Enhance Contrast", "saturated=0.35");

	// Draw around the cell and save that ROI
	setTool("freehand");
	waitForUser("cellROI", "Draw around the cell");
	roiManager("add");
	roiManager("Save", output+File.separator+fn+"_cell.roi");
}

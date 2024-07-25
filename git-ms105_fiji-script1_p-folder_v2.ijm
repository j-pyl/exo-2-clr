// MS105 Fiji Script 1
// Modified for batch by JEP 07/2024
// Replaced code with V2-3

/*
 * Macro template to process multiple images in a folder
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix

// See also Process_Folder.py for a version of this code
// in the Python scripting language.

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
	// Do the processing here by adding your own code.
	// Leave the print statements until things work, then remove them.
	print("Processing: " + input + File.separator + file);
	
	open(input+File.separator+file);
	origfn = File.getNameWithoutExtension(file); // possibly need to delete this line?
	origft = getTitle(file);
	
//	for (i = 1; i < 3; i++) {
//		// Duplicate channel i
//		run("Duplicate...", "duplicate channels=" + i);
//		fdup = origfn + "-" + i + ".nd2";
//		selectImage(fdup);
//		
//		// Run exo analysis script of MS105
//		exo_analysis(input, output)
//		
//		// Close all images except original file
//		selectImage(origftitle);
//		close("\\Others");
//	}

	// Testing alternative code idea out
	if (File.Exists(origfn + "-" + 1 + "_IntensityData.csv")) {		// Skips original/parent file if it has already been analysed
		print(origfn + "-" + 1 + "_IntensityData.csv already exists. Image skipped.");
		return ("1")
	}
	else{
		for (i = 1; i < 3; i++) {
			// Duplicate channel i
			run("Duplicate...", "duplicate channels=" + i);
			fdup = origfn + "-" + i + ".nd2";
			selectImage(fdup);
		
			// Run exo analysis script of MS105 on duplicate i
			exo_analysis(input, output, i)
		
		
//			if (i == 1) {
//				exo_analysis(input, output)
//			}
//			else {
//				exo_analysis2(input, output)
//			}

		
			// Close all images except original file
			selectImage(origft);
			close("\\Others");
		}
		
	}
	
	run("Close All");
	print("Saving to: " + output);
}



function exo_analysis(input, output, j) { // Maybe I need to replace 'j' here with another variable to prevent confusion?
	//Modified from Macro of Steve 

	//Clean the environment
	run("Clear Results");
	if (j == 1) {
		roiManager("reset") // Keeps ROIs for analysis in channel 2 (red)
	}

	// Get information of the file open
	title = getTitle();
	getDimensions(width, height, channels, slices, frames);
	//dir = getDirectory("image");		// Commented this line out. It may run a problem if using a duplicated image. It also has no use anymore.
	imageName= File.getNameWithoutExtension(title);


	if (j == 1) {		// Runs ROI detection on first channel (green). Does not create ROI list for channel 2 (red).
		//Do zstack, select the cell and find maxima - add to ROI
		run("Z Project...", "projection=[Max Intensity]");
		run("Enhance Contrast", "saturated=0.35");

		waitForUser("Draw around the cell", "Draw around the cell");
		run("Set Measurements...", "area redirect=None decimal=3");
		run("Measure");
		Area = getResult("Area", 0);
		run("Close" );
		print("area="+Area);
		run("Clear Results");
		run("Clear Outside");
		run("Select None");

		run("Find Maxima..."); 
		roiManager("Add");
		
		roiManager("Save", output + "/" + imageName + ".roi");					////
	}
	
	//Work on original image
	selectImage(title);
	roiManager("Select", 0);

	// get array of x and y coords
	getSelectionCoordinates(xCoords, yCoords);

	run("Select None");
	f = File.open(output + "/" + imageName+ "_IntensityData.csv");			////
	str = "";
	for (i = 0; i < xCoords.length; i++) {
		str = str + "spot_" + i + ",";
	}
	str = str + "frame\n";
	print(f, str);


	for (i = 0; i < frames; i++) {
		Stack.setFrame(i+1);
		str = "";
		for (j = 0; j < xCoords.length; j++) {
			makeOval(xCoords[j] - 2, yCoords[j] - 2, 4, 4);
			getStatistics(area, mean, min, max, std, histogram);
			str = str + mean + ",";
		}
		str = str + i + "\n";
		print(f, str);
	}
	File.close(f);

	//Get coordinates of all points 
	f = File.open(output + "/" + imageName+ "_CoordData.csv");				////
	str = "";
	x = ""; 
	y= "";
	for (i = 0; i < xCoords.length; i++) {
		str = str + "spot_" + i + ",";
		x = x + xCoords[i]+ ","; 
		y = y + yCoords[i] + ",";
	}
	str = str + "\n";
	x = x + "\n";
	y = y + "\n";
	print(f, str);
	print(f, x);
	print(f, y);
	File.close(f);
	

	//Get informations 
	getPixelSize(unit, pixelWidth, pixelHeight);
	print("SCALE" + unit + "," +pixelWidth+ "," +pixelHeight);
	frameInterval=Stack.getFrameInterval();
	frameInterval = "interval (in s)"+","+ frameInterval + "\n" ; 
	Totspot = xCoords.length; 
	Totspot = "Totspot" +","+ Totspot+ "\n" ; 
	Area = "area (in unit)" +","+ Area+ "\n";
	scaleunit =  "ScaleUnit" +","+ unit + "\n";
	pixelScale =  "pixelScale" +","+ pixelWidth + "\n";
	head = "Info, Value\n";
	
	f = File.open(output + "/" + imageName+ "_CellInfo.csv");				////
	print (f, head);
	print(f, Area); 
	print(f, frameInterval); 
	print(f, Totspot); 
	print (f, scaleunit);
	print (f, pixelScale);
	File.close(f);
}
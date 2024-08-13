// Adaptation of ms105 FIJI script 1
// JEP 07/2024

// V3 - analyse for exocytic events
// Code currently copied over from V2-8_cleaned


// Using process folder FIJI template
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".nd2") suffix
//#@ Boolean (label = "2-channel analysis", value = true) twoclr //// Add this in V4

// NEED TO ADD IMAGE REGISTRATION FOR SLIDES.
// Maybe with global variable?
// #@ Boolean (label = "Register images", value = false) regi

//setBatchMode(true);
processFolder(input);
//setBatchMode(false);

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
	// Leave the print statements until things work, then remove them.
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);
	
	//// Skip if file exists because it will be run in def-cell-ROI and this will depend on its results?
	if (File.exists(output + "/" + origfn + "_cell.roi") == false) {
		print(output + "/" + origfn + "_cell.roi does not exist. Unable to run analysis on this image.");
		return;
	}
	if (File.exists(output + "/" + origfn + "_recy-0_s_IntensityData.csv") == true) {
		print(output + "/" + origfn + "_rcy-0_s_IntensityData.csv already exists. Skipping analysis of this image.");
		return;
	}
	
	open(input+File.separator+file);
	origft = getTitle();
	run("Clear Results");
	roiManager("reset");


	for (i = 0; i < 2; i++) {
		recycle = i;
		selectImage(origft);
		if (recycle == 0) { // Detect ROIs on channel 1, analyse these in channel 1&2
			// Make named duplicates
			run("Duplicate...", "title=template duplicate channels=1");
			selectImage(origft);
			run("Duplicate...", "title=subject duplicate channels=2");
			
			// Detect puncta on template
			template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle);
			exo_analysis_general(output, "subject", origfn, recycle);
			
		} else if (recycle == 1) { // Detect ROIs on channel 2, analyse these in channel 1&2
			run("Duplicate...", "title=template duplicate channels=2");
			selectImage(origft);
			run("Duplicate...", "title=subject duplicate channels=1");

			template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle);
			exo_analysis_general(output, "subject", origfn, recycle);
			// I know this code is doubled and not 'pretty'/conventional, but this is the way I can integrate recycle number into the sequence
			
		} else {
			print("Too many recycles! Recycles >= 1");
			return;
		}
		
		// Close all images except original: set up for next recycle.
		selectImage(origft);
		close("\\Others");
	}
	run("Close All");
}



//------------------------------------------------------------------------------------------------------------------------------------
// Detect ROIs on template image that will be used for analysis.
function template_spot_detection (output, fn, recycle) {
	selectImage("template");
	roiManager("reset");
	
	run("Z Project...", "projection=[Max Intensity]");
	run("Enhance Contrast", "saturated=0.35");

	// Load cell outline ROI
	roiManager("open", output + "/" + fn + "_cell.roi");
	roiManager("select", 0);
	roiManager("measure");				//// Need to make sure results table is empty before running?
	cellArea = getResult("Area", 0);	//// Or maybe run [cellArea = getResult("Area", nResult - 1]? That code works, but if num ROI > 1, measure will done on all ROIs in manager, and only the last result will be assigned to variable
	
	// Clear all but selection
	run("Clear Results");
	run("Clear Outside");
	run("Select None");
	// Remove cell outline ROI
	roiManager("reset");
	
//	// Find puncta and save results
//	run("Find Maxima...");
//	roiManager("Add");
//	roiManager("Save", output + "/" + fn + "_recy-" + recycle + ".roi");					////
	
	// Set appropriate maxima number and save results
	promi = 12;
	do { 
		// Clear ROI manager and results table
		run("Clear Results");
		run("Select None");			//// Need to sort out kinks with lines above as they might be more or less redundant now
		roiManager("reset");
		
		// Perform spot detection and count maxima
		run("Find Maxima...", "prominence=" + promi);
		roiManager("Add");
		roiManager("select", 0);
		roiManager("measure");
		promi = promi + 1;
	} while ((nResults/cellArea) > VALUE_WE_DECIDE);	
	
	roiManager("Save", output + "/" + fn + "_recy-" + recycle + ".roi");					////
	close("MAX_template");
}

//------------------------------------------------------------------------------------------------------------------------------------
// This function runs without error. No need to change
function exo_analysis_general (output, base, fn, recycle) { //// base = base file name (input template or subject when calling this function).
	selectImage(base);										
	getDimensions(width, height, channels, slices, frames);
	if (base == "template") {
		imageName = fn + "_recy-" + recycle + "_t";
	} else if (base == "subject") {							//// this bit might be wrong. i.e. Assigning these values to imageName
		imageName = fn + "_recy-" + recycle + "_s";
	}
	
	
	selectImage(base);
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
	// when running this section alone, a log window is open at the end. Maybe add the two following lines?
//	selectWindow("Log");
//	run("Close");
}
//------------------------------------------------------------------------------------------------------------------------------------
// Adaptation of ms105 FIJI script 1
// JEP 08/2024

// V3 - analyse for exocytic events
// Current version: V3-11-6 (or V3-13-1?)


// Using process folder FIJI template
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".nd2") suffix
#@ Boolean (label = "2-channel analysis", value = true) twoclr //// Add this in V4

// NEED TO ADD IMAGE REGISTRATION FOR SLIDES.
// Maybe with global variable?
// #@ Boolean (label = "Register images", value = false) regi

setBatchMode(true);
processFolder(input);
setBatchMode(false);
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

	s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT";
	run("Bio-Formats Importer", s);
	origft = getTitle();
	run("Clear Results");
	roiManager("reset");

//	// Register image
//	if (regi == true) { //// Need to uncomment this bit in global variable area
//		if (File.exists(input + "/0-tetraspeck-regi.tif")) {
//			print("Cannot perform registration:\n" + input + "/0-tetraspeck-regi.tif\ndoes not exist")
//		}
//		// Run Registration – need NanoJ-core plugin?
//		run("Register Channels - Apply", "open=" + input + "/0-tetraspeck-regi.tif"); //// This seems to work? I ran above on my computer and it began to do so normally?
//		////Had some warnings/errors about using hyperstack(?) but then was running registration? I aborted the operation because it was taking very long on my computer.
//		// Reorganise images & titles
//		regi-img = getTitle();
//		selectImage(origft);
//		close();
//		selectImage(regi-img);
//		rename(origft);
//		
//		// Convert back to 16-bit (this is what needs to be done when applying correction to unregistered tetraspeck image). Is this the correct way for time stack?
//		setOption("ScaleConversions", true);
//		run("16-bit");
//	}

	// Create summary log file
	f = File.open(output + "/" + origfn + "_exo-log.txt");	
	print(f, "EXO-ANALYSIS VERSION 3-11-6\n");
	getDateAndTime(yr, mo, dOfW, dOfMo, hr, minu, sec, msec);
	currDate = ""+ yr +"."+ IJ.pad((mo+1),2) +"."+ IJ.pad(dOfMo,2);
	currTime = IJ.pad(hr,2) +":"+ IJ.pad(minu,2) +":"+ IJ.pad(sec,2);
	print(f, "Date & Time: "+currDate+" - "+currTime+"\n");
	print(f, origfn + "\n");
	print(f, "Output path = " + output + "\n");
	//if (regi == true) {
	//	print(f, "Registered = Yes\n");
	//} else {
	//	print(f, "Registered = No\n");
	//}
	print(f, "Channels analysed: " + (twoclr + 1) + "\n\n");
	File.close(f);



	// SINGLE CHANNEL ANALYSIS
	if (twoclr == false) {
		selectImage(origft)
		recycle = 0;				//// This is necessary to keep with the current code, without adding tons more lines
		run("Duplicate...", "title=template duplicate channels=1"); //// Does this work even when only one channel is available?
		
		// Detect puncta on template
		cArea = template_spot_detection(output, origfn, recycle);
		// Analyse puncta detected
		exo_analysis_general(output, "template", origfn, recycle, cArea);
		
		run("Close All");
		return							//// Does this return out of the 'if' loop or out of 'processFile'?
	}

	// TWO CHANNEL ANALYSIS
	for (i = 0; i < 2; i++) {
		recycle = i;
		selectImage(origft);
		if (recycle == 0) { // Detect ROIs on channel 1, analyse these in channel 1&2
			// Make named duplicates
			run("Duplicate...", "title=template duplicate channels=1");
			selectImage(origft);
			run("Duplicate...", "title=subject duplicate channels=2");
			
			// Detect puncta on template
			cArea = template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle, cArea);
			exo_analysis_general(output, "subject", origfn, recycle, cArea);
			
		} else if (recycle == 1) { // Detect ROIs on channel 2, analyse these in channel 1&2
			run("Duplicate...", "title=template duplicate channels=2");
			selectImage(origft);
			run("Duplicate...", "title=subject duplicate channels=1");

			cArea = template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle, cArea);
			exo_analysis_general(output, "subject", origfn, recycle, cArea);
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
	run("Clear Results");
	
	run("Z Project...", "projection=[Max Intensity]");
	run("Enhance Contrast", "saturated=0.35");

	// Load cell outline ROI & get area
	roiManager("open", output + "/" + fn + "_cell.roi");
	roiManager("select", 0);
	roiManager("measure");
	cellArea = getResult("Area", 0);

	// Clear everything outside of ROI (pixel value = 0)
	run("Clear Outside");
	
	// Set appropriate maxima number and save results
	promi = 12;
	do { 
		// Clear ROI manager and results table
		run("Clear Results");
		run("Select None");
		roiManager("reset");
		
		// Perform spot detection and count maxima
		run("Find Maxima...", "prominence=" + promi);
		roiManager("Add");
		roiManager("select", 0);
		roiManager("measure");
		promi += 1;
	} while (((nResults/cellArea) > 0.55) && (promi < 35)); //// Value approximately calculated from JEP042 IRAP-pHl dish1_001, with ROI drawn around cell, measure area, and then find maxima with promi >14-15 //// Can do this way, or by starting with a high prominence going down
	//showMessage("Maxima Result", fn + "\nRecycle = " + recycle + "\n\nProminence > " + (promi - 1) + "\nMaxima detected: " + nResults); //// Remove line when done (when finalising/completing code)
	File.append("Recycle = " + recycle + "\nProminence > " + (promi - 1) + "\nMaxima detected: " + nResults + "\n\n", output + "/" + fn + "_exo-log.txt");
	
	run("Clear Results");
	
	roiManager("Save", output + "/" + fn + "_recy-" + recycle + ".roi");					////
	close("MAX_template");
	return cellArea;
}

//------------------------------------------------------------------------------------------------------------------------------------
// This function runs without error. No need to change
function exo_analysis_general (output, base, fn, recycle, cell_area) { //// base = base file name (input template or subject when calling this function).
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
	Area = "area (in unit)" +","+ cell_area+ "\n";
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
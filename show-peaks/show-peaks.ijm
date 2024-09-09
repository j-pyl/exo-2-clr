// Show detected peaks
// Used scripts in ms105 to for the very seed of this code.
// More or less just got the Table.getColumn from there.
// JEP 09/2024


// FIJI process folder template
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ File (label = "CSV directory", style = "directory") csvdir
#@ String (label = "Image file suffix", value = ".nd2") suffix 
//#@ String (label = "File prefix", value = "") prefix		//// Maybe need to strip prefix 'JEP0??_' from filename.
															//// Inversely, it might be simpler to just add prefix to csv file when searching.

// Choose mode to use
message = "Select program mode:"
script_mode = getBoolean(message, "Open peaks individually", "    Show all peaks    "); // 1/true = opi; 0/false = sap
if (script_mode==true) {
	print("Running open peaks individually");
	processFolder(input, script_mode);
} else {
	print("Running show all peaks");
	processFolder(input, script_mode);
	//// For a later update, include opi silent mode dialog here before running processFolder
	//// Therefore be able to include setBatchMode(true);
}
waitForUser("Macro/processFolder done");


// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input, script_mode) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i], script_mode);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i], csvdir, script_mode);
	}
}

function processFile(input, output, file, csvdir, script_mode) {
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);
	csv_suffix = "_t_peak-xyt.csv";
	csvf_0t = origfn+"_recy-"+0+csv_suffix;
	csvf_1t = origfn+"_recy-"+1+csv_suffix;
	
	
	// Check if either csv exists and open relevant ones
	csvf_0t_exists = File.exists(csvdir+File.separator+csvf_0t);
	csvf_1t_exists = File.exists(csvdir+File.separator+csvf_1t);
		
	// Import csv data into array
	if (csvf_0t_exists==true) {
		open(csvdir+File.separator+csvf_0t);
		
		// 0t data
		selectWindow(csvf_0t);
		xcoords_0t = Table.getColumn("x_coord");
		ycoords_0t = Table.getColumn("y_coord");
		frm_no_0t = Table.getColumn("frame");
		spot_n_0t = Table.getColumn("spot_no");
		for (i=0; i<spot_n_0t.length; i++) {
			spot_n_0t[i] =  spot_n_0t[i] + "_0t";
		}
		run("Close");
	}
	if (csvf_1t_exists==true) {
		open(csvdir+File.separator+csvf_1t);
		
		// 1t data
		selectWindow(csvf_1t);
		xcoords_1t = Table.getColumn("x_coord");
		ycoords_1t = Table.getColumn("y_coord");
		frm_no_1t = Table.getColumn("frame");
		spot_n_1t = Table.getColumn("spot_no");
		for (i=0; i<spot_n_1t.length; i++) {
			spot_n_1t[i] =  spot_n_1t[i] + "_1t";
		}
		run("Close");
	}
	
	// Bring arrays together
	if ((csvf_0t_exists==true) && (csvf_0t_exists==true)) {
		xcoords = Array.concat(xcoords_0t, xcoords_1t);
		ycoords = Array.concat(ycoords_0t, ycoords_1t);
		frm_no = Array.concat(frm_no_0t, frm_no_1t);
		spot_n = Array.concat(spot_n_0t, spot_n_1t);
	} else if ((csvf_0t_exists==true) && (csvf_1t_exists==false)) {
		xcoords = xcoords_0t;
		ycoords = ycoords_0t;
		frm_no = frm_no_0t;
		spot_n = spot_n_0t;
	} else if ((csvf_0t_exists==false) && (csvf_1t_exists==true)) {
		xcoords = xcoords_1t;
		ycoords = ycoords_1t;
		frm_no = frm_no_1t;
		spot_n = spot_n_1t;
	} else { // In case neither file exists.
		print("In "+csvdir+"\nNeither file below exists.\n"+csvf_0t+"\n"+csvf_1t);
		return
	}
	
	// Run selected script mode
	if (script_mode==1) open_peaks_indiv(input, output, file, xcoords, ycoords, frm_no, spot_n, origfn);
	else show_all_peaks(input, output, file, xcoords, ycoords, frm_no, spot_n, origfn);
}



//------------------------------------------------------------------------------------------------------------------------------------
// Open each peak individually
function open_peaks_indiv(input, output, file, xcoords, ycoords, frm_no, spot_n, origfn) {
	
	// Create dialog box to ask what you want to do
	Dialog.create("Open Peaks Individually Settings");
	opi_setting1 = newArray(" Visual       "," Silent");
	opi_setting2 = newArray("No","Yes");
	Dialog.addMessage("Choose how to run Open Peaks Individually:\n1) Visual: see image before deciding to save films\n2) Silent: creates films for all peaks");
	Dialog.addRadioButtonGroup("    Run mode:", opi_setting1, 1, 2, "Visual");
//	Dialog.addRadioButtonGroup("    Make montage (silent mode)", opi_setting2, 1, 2, "No");
	Dialog.show();
	opi_mode = Dialog.getRadioButton();
//	opi_montage = Dialog.getRadioButton();
	
	if (opi_mode == " Visual       ") {
		for (i=0; i<xcoords.length; i++) {
//			frm = frm_no[i];
//			if (frm < 11) frm = 11;
//			x = xcoords[i];
//			if (x < 37) x = 37;
//			y = ycoords[i];
//			if (y < 37) y = 37;
//			
//			// Specify time and space coordinates of peak
//			frm_range = "c_begin=1 c_end=2 c_step=1 t_begin="+ (frm - 10) +" t_end="+ (frm+15) +" t_step=1 "; // Frame range (from peak - 10 to peak + 15)
//			xy_range = "x_coordinate_l="+ (x - 18) +" y_coordinate_l="+ (y - 18) +" width_l=37 height_l=37";  // Image box size (37px x 37px)
//			s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite crop rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT ";
//			// Open Image
//			run("Bio-Formats Importer", s+frm_range+xy_range);

			// Set up figure coordinates & dimensions
			fig_coords = fig_coord_setup(i, xcoords[i], ycoords[i], frm_no[i]);
			f_start = fig_coords[0];
			f_end = fig_coords[1];
			x_strt = fig_coords[2];
			y_strt = fig_coords[3];
			wl = fig_coords[4];
			hl = fig_coords[5];
			
			// Specify time and space coordinates of peak
			s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite crop rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT ";
			frm_range = "c_begin=1 c_end=2 c_step=1 t_begin="+f_start+" t_end="+f_end+" t_step=1 "; // Frame range (from peak - 10 to peak + 15)
			xy_range = "x_coordinate_l="+x_strt+" y_coordinate_l="+y_strt+" width_l="+wl+" height_l="+hl;  // Image box size (37px x 37px)
			// Open Image
			run("Bio-Formats Importer", s+frm_range+xy_range);
			
			
			// Choose if you want to save image
			Dialog.createNonBlocking("Save film");
			Dialog.addRadioButtonGroup("Save film", opi_setting2, 1, 2, "No");
//			Dialog.addRadioButtonGroup("Make montage", opi_setting2, 1, 2, "No");
			Dialog.show();
			save_film = Dialog.getRadioButton();
//			visumode_savefilm = Dialog.getRadioButton();
			
			// Save film
			if (save_film=="Yes") {										//// Make sure that spot_n is saved into name
				
				save_img_dir = output+File.separator+origfn+"_show-peaks-out"; 				//// make sure directory and path is correct
				if (File.isDirectory(save_img_dir)==false) File.makeDirectory(save_img_dir);
				
				saveAs ("Tiff",  save_img_dir+File.separator+spot_n[i]+ ".tif"); //// Make sure directory is correct
				
				//Dont need this block anymore?
				//imgname = getTitle();
				//orig_fn = File.getNameWithoutExtension(imgname);
				//new_fn = orig_fn +"_"+ spot_n[i] +".tif";
				//saveAs("tiff", output+File.separator+new_fn));
				
				// Make montage 			Will move this out of here/this macro.
				//if (visumode_savefilm=="Yes") {
				//	//// Need to insert make montage stuff here.
				//}
			}
		}
	} else { // opi_mode silent
		//// I think this whole thing can be removed & can all be run without if/else.
		////	The idea would be to have a dialog box before processFolder structured like the dialog at the start of this function,
		////	radio buttons 1 = select mode (opi or sap)
		////	radio buttons 2 = message('Silent mode (opi)?') yes/no
		////	I just need to bypass the dialog box and set save_film to == "Yes"
		
		exit("Sorry, Open Peaks Individually silent mode is currently unavailable");
		
////		setBatchMode(true);
//			//// This probably shouldn't work. Or maybe this shouldn't be within a processFolder/processFile function
//			//// Remember to add setBatchMode(false); at the end
//		for (i=0; i<xcoords.length; i++) {
//			fig_coords = fig_coord_setup(i, xcoords[i], ycoords[i], frm_no[i]);
//			f_start = fig_coords[0];
//			f_end = fig_coords[1];
//			x_strt = fig_coords[2];
//			y_strt = fig_coords[3];
//			wl = fig_coords[4];
//			hl = fig_coords[5];
//
//			
//			// Specify time and space coordinates of peak
//			frm_range = "c_begin=1 c_end=2 c_step=1 t_begin="+ (frm - 10) +" t_end="+ (frm+15) +" t_step=1 "; // Frame range (from peak - 10 to peak + 15)
//			xy_range = "x_coordinate_l="+ (x - 18) +" y_coordinate_l="+ (y - 18) +" width_l=37 height_l=37";  // Image box size (37px x 37px)
//			s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite crop rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT ";
//			// Open Image
//			run("Bio-Formats Importer", s+frm_range+xy_range);
//			
//			// Save film
//			imgname = getTitle();
//			orig_fn = File.getNameWithoutExtension(imgname);
//			new_fn = origfn +"_"+ spot_n +".tif";
//			saveAs("tiff", output+File.separator+new_fn));
//		}
//	}
}


//------------------------------------------------------------------------------------------------------------------------------------
// Show all detected peaks as ROIs
// Use: click on the ROI name in ROI manager and an ROI will be drawn around the peak and the frame will be set to the peak.
function show_all_peaks (input, output, file, xcoords, ycoords, frm_no, spot_n, origfn) {
	
	// Open image
	s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite crop rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT";
	run("Bio-Formats Importer", s);
	
	// Make ROIs
	roiManager("reset");
	for (i=0; i<xcoords.length; i++) {
		Stack.setFrame(frm_no[i]); //// No need anymore? Delete?
		makeOval(xcoords[i]-15, ycoords[i]-15,31,31);
		Roi.setPosition(1,1,frm_no[i]);
		roiManager("add");
		roiManager("select", i);
		roiManager("rename", spot_n[i]);
	}
	
	
	// Select ROIs to make films with
	Dialog.createNonBlocking("Save ROIs");
	Dialog.addMessage("Select which ROIs to save");
	dlab = newArray(xcoords.length); // Dialog label
	ddef = newArray(xcoords.length); // Dialog default
	for (i=0; i<xcoords.length; i++) {
		dlab[i] = spot_n[i];
		ddef[i] = false;
	}
	drow = Math.ceil(xcoords.length/5);
	Dialog.addCheckboxGroup(drow, 5, dlab, ddef);
	Dialog.show();
	
	// Make films with selected ROIs
	for (i = 0; i < xcoords.length; i++) {
		temp = Dialog.getCheckbox();
		if (temp == true) {
			
			// Create a new subdirectory with files to save
			save_img_dir = output+File.separator+origfn+"_show-peaks-out"; 				//// make sure directory and path is correct
			if (File.isDirectory(save_img_dir)==false) File.makeDirectory(save_img_dir);
			
			// Set up figure coordinates & dimensions
			fig_coords = fig_coord_setup(i, xcoords[i], ycoords[i], frm_no[i]);
			f_start = fig_coords[0];
			f_end = fig_coords[1];
			x_strt = fig_coords[2];
			y_strt = fig_coords[3];
			wl = fig_coords[4];
			hl = fig_coords[5];
			
			// Create & save image
			roiManager("deselect");
			makeRectangle(x_strt, y_strt, wl, hl); //// could simplify wih just fig_coords[x]
			run("Duplicate...", "title="+ spot_n[i] +" duplicate frames="+ f_start +"-"+ f_end); //// NEED TO UPDATE TITLE?
			saveAs ("Tiff",  save_img_dir+File.separator+spot_n[i]+ ".tif"); //// Make sure directory is correct
			
			close(spot_n[i]+".tif");
		}
	}
}


//------------------------------------------------------------------------------------------------------------------------------------
// Set up for cropped figure size and coordinates
function fig_coord_setup (indx, x, y, frm) {
	Stack.getDimensions(img_width, img_height, img_channels, img_slices, img_frames);
	
	// Image dimensions
	len_w = 37;
	len_h = 37;
	if (!(len_w%2 && len_h%2)) exit("Image dimensions are not odd numbers.\n \nlen_w AND len_h in fig_coord_setup need to be odd numbers.");
	hlen_w = floor(len_w/2);
	hlen_h = floor(len_h/2);
	
	// Modify peak coordinates if the resultant ROI is 'out of bounds'
//	frm = frm_no[indx];
	if (frm < 11) frm = 11;
	if (frm > (img_frames - 15)) frm = img_frames - 15;

	x = parseInt(x);
	if (x < (hlen_w + 1)) x = hlen_w + 1;
	if (x > (img_width - hlen_w )) x = img_width - hlen_w;

	y = parseInt(y);
	if (y < (hlen_h + 1)) y = hlen_h + 1;
	if (y > (img_height - hlen_h)) y = img_height - hlen_h;
	
	
	frm_start = frm-10;
	frm_end = frm+15;
	
	// Define top-left corner of ROI box
	x_start = x - ((len_w -1)/2);
	y_start = y - ((len_h -1)/2);
	
	// Return figure coordinates & dimensions
	return newArray(frm_start, frm_end, x_start, y_start, len_w, len_h);
}

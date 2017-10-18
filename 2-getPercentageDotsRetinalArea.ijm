//getPercentageDotsRetinalArea.ijm macro
this_version = "v0.45"; 
//19/09/2017 Daan van den Brink

//
//Macro to automatically draw an ROI around dots in an image.
//Tries to exlude areas without dots and isolated dots
//Then Measures the Int, Area and %Area of dots.
//requires a directory of images; images with two channels; dots on the first channel
//
//Requires RoiManagerSplit.ijm	ReturnDateTime.ijm
//This traps errors that sometimes occur for no reason during ROI-split


ignoreChannelError = true; //sometimes saving images messes up information on channels/slices, try to repair?
swapChannels = false //Spots are assumed to be on Channel 1
run("ROI Manager...");
fileExtension = "tif";
nImage = 0;	//Start with image nImage+1
nImageMeasured = 0; //Keep track of images measured for row number in results table.
run("Clear Results");
skipFirstImages = 0;	//put 0 to start with first.
ROItool = "freehand"; //"oval" "rectangle" "brush"

returnedDateTime = runMacro("ReturnDateTime",0);
print("Quantification Macro started: ", returnedDateTime);
if (skipFirstImages > 0 ) {
	waitForUser("Skipping first " + skipFirstImages + " images.");
}
print("\\Clear");

run("Threshold..."); //to diplay the dialog.
closeExceptions();	//Some Java errors cause exception windows to be created that clutter the desktop.
//print("Closing " + windowList[w]);
run("Set Measurements...", "area mean integrated area_fraction display redirect=None decimal=3");
//roiManager("Show None");

print("Begin (", returnedDateTime, ")" );
//Get the files, iterate and apply a Threshold to each. Then call functions.
//list=newArray();
inputDir = getDirectory("Input Directory");
list = orderList(inputDir);
	
for (l = skipFirstImages; l < list.length; l++) {
	if (endsWith(list[l], fileExtension)) {
		print("\nReading file: " + list[l]);
		setBatchMode(true);
		roiManager("reset");
		//open(list[l]);
		run("Bio-Formats Windowless Importer", "open=["+ inputDir + list[l] + "] autoscale color_mode=Default");
		//check if images contains 2 channels, try to repair
		Stack.getDimensions(x, y, channels, slices, frames);
		//print("Now here");
		if(channels < 2 && ignoreChannelError ==true) {
			run("Re-order Hyperstack ...", "channels=[Slices (z)] slices=[Channels (c)] frames=[Frames (t)]");
			Stack.getDimensions(x, y, channels, slices, frames);
			print(" Changed dimensions, which are now (channels; slices; frames): " + channels + slices + frames );
		}
		//Look at the image and select a good bit of retina:
		Stack.setDisplayMode("composite");
		Stack.setChannel(1);
		run("Enhance Contrast", "saturated=0.35");
		run("Green");		
		Stack.setChannel(2);
		run("Enhance Contrast", "saturated=0.35");
		run("Red");
		setBatchMode("show");
		
		useImage = yesNo("Check Retina", "Does this retina look OK?", "Use image");
		open_image = getTitle();
		//Start processing the image for dot-detection.
		if ( useImage == true) {
			setBatchMode("hide");
			retinaRoi();	//To hand-draw the area of retina containing the Dots.
			//Make a selection of the Dots:
			selectWindow(open_image);
			run("Split Channels");
			if (swapChannels == true) {
				print("Swapping Channel 1 and 2");
				selectWindow("C1-" + open_image);
				rename("temp_name");
				selectWindow("C2-" + open_image);
				rename("C1-" + open_image);
				selectWindow("temp_name");
				rename("C2-" + open_image);				
			}
			//Close the red channel (Phalloidin).
			close("C2-*");
			roiManager("select", 0);
			//Select green channel, remove background and Threshold.
			selectWindow("C1-" + open_image);
			open_image = getTitle();
			//Find the Dots
			run("Subtract Background...", "rolling=10");
			//On first run do auto Threshold
			print(" nImage is:", nImage+1, "en skipFirstImages is:",skipFirstImages, "out of", list.length, "files.");
			if(nImage==0) {	setAutoThreshold("Otsu dark");}
			else { 
				getMinAndMax(bin, MaxPixel);
				setThreshold(minThreshold, MaxPixel);
			}
			setBatchMode("show");
			waitForUser("Please Check Threshold");
			//remember Threshold
			getThreshold(minThreshold, maxThreshold);
			print(" Threshold set at:", d2s(minThreshold, 0), "-", d2s(maxThreshold, 0) + ".");
			selectWindow(open_image);
			setBatchMode("hide");
			//Make the large ROI surrounding the dots, and measure for dot-area wihtin it.
			//createROI();	//To automatically make an area around the Dots.
			createDots();	//To make a selection of Dots
			manageROIs();
			close(open_image);
			nImage ++;
		} else { 
			open_image = getTitle();
			print(" User skipped image " + open_image); 
			close(open_image);
		}
			//waitForUser("This was image nr: " + nImage);
			close(open_image);
	}
}
//Save results to file
if (nImage>0) { saveResults() ;}
closeExceptions();
showMessage("Einde, images processed: " + nImage);
//End of macro


function retinaRoi () {
//Create an outline around complete area of retina that has Dots.
	//Wait for a ROI to be drawn by user.
	roiType =-1; 
	setBatchMode("show");
	while (roiType == -1 ) {
		setTool(ROItool);
		waitForUser("Draw a ROI around a good bit of retina and press OK\n make sure there is at least one dot!");
		roiType = selectionType();
	}
	//selectWindow("ROI Manager")
	if (roiType !=-1) { //If (not no) selection was made
		setBatchMode("hide");
		roiManager("Add");
		roiManager("select",roiManager("count")-1);
		wait(100);
		roiManager("Rename", "retinaArea");
		//wait(100);
		//waitForUser("Updated roi name?");
		setTool("hand");
	} else { yesNo("Error", "There was no selection made\nignoring image",""); 	}
}

function createDots() {
	//Make a selection out from the Thresholded image
	run("Create Selection");
}

function createROI() {	//Automatically makes a large ROI surrounding the dots
	//setBatchMode(true);
	enlargeBy = "75 pixel";
	decreaseBy = 10;//times
	run("Create Selection");
	run("Enlarge...", "enlarge=" + enlargeBy);
	for (d=0;d<decreaseBy;d++) {
		run("Enlarge...", "enlarge=-5 pixel");
	}
	//setBatchMode(false);
}

function manageROIs() {
	setBatchMode(false);
	//yesNo("Continue?","go on?","well?");
	//Set the Cut-off value (in pixels) for the minimum area of a Dot.
	getPixelSize(pixelUnit, pixelWidth, pixelHeight);
	//Using Pixels:
		//areaCutOffPx = 50; //(pixels^2). This determines the minumum size of dots-positivearea. 
		//areaCutOff	 = areaCutOffPx*pow(pixelWidth,2);	//Calculates the actual physical cut-off area in units.
	//Using units:
		areaCutOff = 0.05;	//units (microns)
		areaCutOffPx = areaCutOff/pow(pixelWidth,2);
	
	//Visualize the cut-off Area
	//radiusCutOffPx = sqrt(areaCutOffPx/PI);//r = sqrt(A/pi)
	//makeOval((getWidth()/2)-((radiusCutOffPx)/2), (getWidth()/2)-((radiusCutOffPx)/2),(radiusCutOffPx)*2,(radiusCutOffPx)*2);
	//yesNo("Check", "Is this a good Area cut-off?","");
	//print(" Handling window: " + getTitle() );
	print(" Resolution is: " + pixelWidth + pixelUnit + "/pixel.\tROI cut-off is " + areaCutOff + pixelUnit +"^2 (" + areaCutOffPx + "^2 pixels)."); 
	roiManager("Add");	//Adding all Dots in the frame
	wait(100);
	//waitForUser("Check, Did the Dots get added to selection?");
	//Get dots within Retina-area.
	roiManager("Select",newArray(0,1));
	roiManager("And");	//get subset of Dots within area of interest
	if (selectionType() == -1) {exit("Error: \nNo Dots found within selected area,\n have to abandon macro...")};	
	roiManager("Add");
	roiManager("deselect");	//otherwise will delete too much next.
	roiManager("select",roiManager("count")-2);	//delete Dots found wherever.
	wait(100);
	roiManager("delete");
	roiManager("select",roiManager("count")-1);	//Selection of Dots within retinaArea
	wait(100);
	roiManager("rename", "retinaDots");
	//waitForUser("Check,Are there 2 ROIs?");
	//print("ROI count is " + roiManager("count"));
	roiManager("select",1);//roiManager("count")-1);	//to be sure retinaDots is selected, does is consist of multiple things (composite).
	//Make indvidual areas for each Dot in retinaDots
	if(Roi.getType == "composite" ) {
		//Sometimes the command 'roiManager("split")' gives an error: 'No selection bladibla' causing the process to crash ;
		//running it in an external macro prevents the crash.
		didItWork = runMacro("roiManagerSplit");
		if (didItWork !=1) {
			print(" Something went wrong splitting the ROI, usually no problem: " + didItWork);
		} 
	} else { exit("Not a good ROI type (composite): " + Roi.getType);}
	deleteArray = newArray();		//This will contain all Dots below cut-off.
	keepArray = newArray();		//Will contain all Dots off sufficient size (passing cut-off).
	myCount = roiManager("count");
	//waitForUser(" " + myCount + " ROIs found");
	//Go over all Dot-ROIs (ignoring 1st retinaArea ROI).
	for (r=1; r<myCount; r++) {
		showProgress(-r/(myCount-1));		
		roiManager("Select",  r);
		//waitForUser("In loop");
		getStatistics(area);
		//print("\nArea " + r + " is: " + area);
		if (area < areaCutOff) {
			deleteArray = Array.concat(deleteArray,r); 
			//print("Area " + r + " is: " + area + " -> should delete: " + r + " (is smaller than " + areaCutOff + ").");
		} else {
			//print("Area " + r + " is: " + area + " -> should keep: " + r);
			keepArray = Array.concat(keepArray,r); 
		}
	}
	//print(" This is in deleteArray (n=" + deleteArray.length + ") & keepArray (n=" + keepArray.length + ")");
	//Array.print(deleteArray);
	//Array.print(keepArray);
	run("Select None");
	roiManager("Select", keepArray);
	//yesNo("Check:", "Combine these for keep","");
	if (keepArray.length > 1) {
		roiManager("Combine");
		roiManager("Add");
		//print("Done the >1 if");	
	}
	else if (keepArray.length == 1) {
		roiManager("Add");
		//print("Done the ==1 if");
	} 
	else { 
		waitForUser("No good Dots-area found in ManageROIs()."); 		
	}
	
	roiManager("Select", Array.concat(deleteArray,keepArray));
	roiManager("Delete");
	roiManager("Select",0);
	//Measure Area and Mean of everything within Retina Area - nonThresholded Area.
	getStatistics(totalArea, totalMean);
	//waitForUser("This is the area to be measured for Total Area and Mean: " + totalArea + "; " + totalMean);
	if (keepArray.length!=0) {	//avoid error when no Dots found after cut-off
		roiManager("Select",1);
		validDots=true;
	} else {
		validDots=false;
		run("Select None");
	}
	setBatchMode("show");
	includeImage = yesNo("Check","This is the selection.","Include in results?");
	selectWindow(open_image);
	
	if (includeImage == true) {
		//roiManager("Measure");
		//Perform an additional more precise count of Dots (Better Dots)
		roiManager("Select",1);
		run("Find Maxima...", "noise=5 output=[Point Selection]");
		waitForUser("Found these maxima within the Dots-ROI");
		getSelectionCoordinates(xCoordinates, yCoordinates);
		findMaximaCount =xCoordinates.length;
		print(" " + keepArray.length + " ROIs found with", xCoordinates.length, "maxima.");	//in keepArray") 
		//waitForUser("Found Maxima above threshold");
		//Measure statistics for Retina
		roiManager("Select",1);
		showStatistics(totalArea, totalMean, validDots);
		nImageMeasured ++;
	} else {
		print("User didn't include results for: " + open_image);
	}
}

function showStatistics(areaOfRetina, meanOfRetina, validTest) {
      if (validTest == true ) {
      	roiManager("Select",1); 
      	getStatistics(area, mean, min, max);
      	//waitForUser("This is the area to be measured for Dot Area and Mean: " + area + "; " + mean);
      } else {
      	area = 0;
      	mean = 0;
      	min = 0;
      	max = 0;
      }
      //IntDen = area * mean;
      //"IntDen" (the product of Area and Mean Gray Value) and "RawIntDen" (the sum of the values of the pixels in the image or selection).
      IntDenOfRetina = areaOfRetina*meanOfRetina;
      IntDenDots = mean * area; 
      IntDenDotsPerRetinaA = IntDenDots / areaOfRetina;
      nDots_size = area / findMaximaCount;
      setResult("Dir",			nImageMeasured, replace(inputDir, " ", "_"));
      setResult("File",			nImageMeasured, replace(open_image, " ", "_"));
      setResult("retinaArea",	nImageMeasured ,areaOfRetina);
      setResult("IntDenDots_per_Retina_Area",	nImageMeasured, IntDenDotsPerRetinaA);
      setResult("Dots_IntDen",	nImageMeasured, IntDenDots);
      setResult("retinaIntDen",	nImageMeasured, IntDenOfRetina);
	  setResult("Area", 		nImageMeasured, area);
      setResult("%Area", 		nImageMeasured, 100*area/areaOfRetina);
      setResult("Mean ", 		nImageMeasured, mean);
      setResult("Min ", 		nImageMeasured, min);
      setResult("Max ", 		nImageMeasured, max);
      setResult("nDots ", 		nImageMeasured, keepArray.length);
      setResult("better_nDots ",nImageMeasured, findMaximaCount);
      setResult("nDots_size ",	nImageMeasured, nDots_size);
      updateResults();
  }

function orderList(inputDir) {
	//Makes a list of file names and sorts by userinputted prefix.
	//Variable is input directory
	//Dialog.create("Sort File List");
	//Dialog.addMessage("If you want to start with a file, type a prefix");
	//Dialog.addMessage("(Otherwise leave empty)");
	//Dialog.addString("file prefix:", "", 10);
	//Dialog.show();
	//prefixSort = Dialog.getString();
	prefixSort = getString("If you want to start with a specific file, type a prefix", "");
	list = getFileList(inputDir);
	Array.print(list);
	if (prefixSort == "") {
		return list;	
	}
	print("Sorting list by", prefixSort, "...");
	orderedList = newArray();
	unorderedList = newArray();
	for (l=0; l < list.length; l++) {
		if(startsWith(list[l], prefixSort)==true) {
			orderedList = Array.concat(orderedList, list[l]);
		} else {
			unorderedList = Array.concat(unorderedList, list[l]);
		}
	}
	list=Array.concat(orderedList, unorderedList);
	Array.print(list);
	return list;
}

function yesNo(title, message, checkbox) {
	Dialog.create(title);
	Dialog.addMessage(message);
	if (checkbox != "") {
		Dialog.addCheckbox(checkbox, true);
	}
	Dialog.show();
	return Dialog.getCheckbox();
}

function closeExceptions() {
	setBatchMode(true);
	windowList = getList("window.titles");
	//print("Open windows: ");
	//Array.print(windowList) ;
	exceptionCount=0;
	for (w = 0; w < windowList.length; w++) {
		//print("Checking window: " + windowList[w]);
		if (windowList[w] == "Exception") {
			exceptionCount++;
			selectWindow(windowList[w]);
			run("Close");
		}
	}
	setBatchMode(false);
	//print("Closed " + exceptionCount + " Exception windows");
}

function saveResults() {
	//Save results table as CSV file
	outputFile = inputDir+returnedDateTime + "Quant-" + this_version + ".csv";
	if (File.exists(outputFile) == false ) {
		f = File.open(outputFile);
		File.close(f);
	}
	String.copyResults;
	commaSeperatedResults = replace(String.paste,"\\h+",","); //replace all horizontal whitespace (not newlines) with comma's.
	File.append(commaSeperatedResults, outputFile);
}

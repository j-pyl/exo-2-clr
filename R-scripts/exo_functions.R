# FUNCTIONS ----

#' read_intensity_data - Reshape and normalised dataframes coming from imageJ macro "ExocytosisAnalysis"
#' 
#' @param flist list of intensity csv files
#' @param filt character string to filter the files to read
#' @return reshaped and normalised dataframe.

read_intensity_data <- function(flist, filt = "recy-0_t") {
  df <- data.frame()
  for (fname in flist) {
    if(!grepl(filt, fname)) {
      next
    }
    temp <- read.csv(fname)
    temp <- temp %>% 
      relocate(frame)
    temp <- pivot_longer(data = temp, cols = contains("spot"))
    temp <- temp %>%
      group_by(name) %>%
      mutate(norm = value - median(value))
    temp$file <- basename(fname)
    # extract the image name
    temp$img <- gsub(paste0("_",filt,"_IntensityData.csv"), "", temp$file)
    temp$kind <- filt
    temp$UniqueIDspot <- paste0(temp$img, "_", temp$name)
    
    df <- rbind(df, temp)
  }
  return (df)
}

#' find_peaks_and_pair - Wrapper for FINDPEAK that also apirs the peaks from the subject data frame
#'
#' @param tdf template data frame
#' @param sdf subject data frame
#' @param idf info data frame
#' @param minpeakheight A numeric value to determine the minimum value of the peak height. See pracma::findpeaks.
#' @param threshold A numeric value to determine a threshold for peak detection.  See pracma::findpeaks.
#' @param threshold2 A numeric value to determine a threshold for peak detection. The second time it is taking a pourcentage of the peak value.

#' @return A dataframe with peaks for each spot. It has columns: spotname = V1, val = V2, index = V3, start = V4, end = V5.

find_peaks_and_pair <-  function(tdf, sdf, idf, minpeakheight, threshold, threshold2) {
  # find unique spots
  unique_spot_list <- unique(tdf$UniqueIDspot)
  
  # loop through each spot and find peak
  AllNormdataCentered <- data.frame()
  for (i in 1:length(unique_spot_list)){
    # filter one unique spot
    spot <- unique_spot_list[i]
    SubsetAllNormdata <- tdf %>% filter (UniqueIDspot == spot)
    
    # find Peak and center at zero around the peak
    peaks <- FINDPEAK(Normdata = SubsetAllNormdata, minpeakheight = minpeakheight, threshold = threshold, threshold2 = threshold2)
    if (length(peaks) > 0) {
      max <- as.numeric(peaks$val[1])
      index <- as.numeric(peaks$index[1]) 
      newFrameZero <- SubsetAllNormdata$frame[index]
      
      # create new Frame column with Max centered to 0 and another with intensities scaled to 1
      SubsetAllNormdata <- SubsetAllNormdata %>%
        mutate(NewFrame = frame - newFrameZero, NewNorm = norm / max )
      
      # reconcatenate everything
      AllNormdataCentered <- rbind(AllNormdataCentered, SubsetAllNormdata)
    }
  }
  
  newdf <- merge(AllNormdataCentered, sdf, by = c("frame", "UniqueIDspot"), all.x = TRUE, sort = FALSE)
  unique_spot_list <- unique(newdf$UniqueIDspot)
  
  alldf <- data.frame()
  for (i in 1:length(unique_spot_list)){
    # filter one unique spot
    spot <- unique_spot_list[i]
    subsetdf <- newdf %>% filter (UniqueIDspot == spot)
    # find the norm_0s value at frame 0
    max <- subsetdf$norm.y[subsetdf$NewFrame == 0]
    subsetdf <- subsetdf %>% mutate(NewNorm.y = norm.y / max)
    alldf <- rbind(alldf, subsetdf)
  }
  
  # create a new column from NewFrame with the time in seconds, we will get the calibration by
  # looking up the value in infodf$`interval (in s)` for the corresponding file
  # file is in the file column in infodf, whereas the file is in alldf$file_0t
  alldf <- alldf %>% mutate(RelativeTime = NewFrame)
  for (i in 1:nrow(alldf)){
    file <- alldf$file.x[i]
    file <- gsub("IntensityData", "CellInfo", file)
    interval <- as.numeric(idf$`interval (in s)`[idf$file == file])
    alldf$RelativeTime[i] <- alldf$NewFrame[i] * interval
  }
  # after merge rename any columns that are .x with 0t and .y with 0s or 1s and 1t
  nm <- deparse(substitute(tdf))
  
  if (grepl("0t",nm)) {
    colnames(alldf) <- gsub("\\.x", "_0t", colnames(alldf))
    colnames(alldf) <- gsub("\\.y", "_0s", colnames(alldf))
    colnames(newdf) <- gsub("NewNorm", "NewNorm_0t", colnames(newdf))
  } else {
    colnames(alldf) <- gsub("\\.x", "_1t", colnames(alldf))
    colnames(alldf) <- gsub("\\.y", "_1s", colnames(alldf))
    colnames(newdf) <- gsub("NewNorm", "NewNorm_1t", colnames(newdf))
  }
  
  return(alldf)
}

#' FINDPEAK - Reshape and find peaks in dataframe coming from the function DATANORM.
#'
#' @param Normdata Data frame coming from DATANORM function. The df from DATANORM has a column: frame, name(spotsname), value(intensity), norm(intensity normalised).
#' @param minpeakheight A numeric value to determine the minimum value of the peak height. See pracma::findpeaks.
#' @param threshold A numeric value to determine a threshold for peak detection.  See pracma::findpeaks.
#' @param threshold2 A numeric value to determine a threshold for peak detection. The second time it is taking a pourcentage of the peak value.

#' @return A dataframe with peaks for each spot. It has columns: spotname = V1, val = V2, index = V3, start = V4, end = V5.

FINDPEAK <- function (Normdata, minpeakheight, threshold = 1, threshold2 = 0.65) {
  # Reshape the data frame----
  NormdataWide <- Normdata %>%
    select(frame, name, norm) %>%
    pivot_wider(names_from = name, values_from = norm)
  
  # findpeak works only on numeric class, not dataframe. So need to change the dataframe into numeric using lapply
  NumNormData <<- lapply(select(NormdataWide, !contains("frame")), as.numeric)
  
  # Find peaks ----
  allpeaksNorm <- tibble()
  
  for(i in 1 : length(NumNormData)) {
    peakstemp1 <- findpeaks(NumNormData[[i]], nups = 1, ndowns = 3, minpeakdistance = 10, minpeakheight = minpeakheight,  threshold =  threshold)
    #Do double check of findpeak with threshold half of the value found!
    peakstemp <- findpeaks(NumNormData[[i]], nups = 1, ndowns = 3, minpeakdistance = 10, minpeakheight = minpeakheight,  threshold =peakstemp1[1]*threshold2 )
    if (!is.null(peakstemp)) {
      peakstemp <- cbind(names(NumNormData[i]), peakstemp)
    }
    allpeaksNorm <- rbind (allpeaksNorm, peakstemp)
  }
  #rename columns
  if (length(allpeaksNorm) > 0) {
    allpeaksNorm <- allpeaksNorm %>%
      rename(spotname = V1, val = V2, index = V3, start = V4, end = V5)
  }
  
  return(allpeaksNorm)
}


#' average_waves - a function that is analolgous to IgorPro's average waves.
#' 
#' Resamples each "wave" at constant time steps using linear interpolation, to allow averaging.
#'
#' @param df Data frame from exo_script it needs Condname, UniqueIDspot, RelativeTime, NewNorm columns
#' @param s string to subset the data by Condname
#' @return data frame of summary data per resampled timepoint

average_waves <- function(df,s) {
  # in order to average the traces we need to array each into a column according to time
  intensities <- df %>% 
    filter(Condname == s) %>% 
    select(c(UniqueIDspot,RelativeTime,NewNorm)) %>% 
    pivot_wider(
      names_from = UniqueIDspot,
      values_from = NewNorm,
      names_glue = "int_{UniqueIDspot}"
    )
  # reorder by t as the order may be messed up during pivot_wider
  intensities <- intensities[order(intensities$RelativeTime), ]
  # make a desired length dataframe
  newdf <- data.frame(t = seq(from = -2, to = 4, length.out = 61))
  for(i in 2:ncol(intensities)) {
    subdf <- cbind(intensities[,1],intensities[,i])
    subdf <- subdf[complete.cases(subdf),]
    temp <- approx(x = subdf[,1], y = subdf[,2], xout = seq(from = -2, to = 4, length.out = 61))
    newdf <- cbind(newdf,temp[[2]])
  }
  names(newdf) <- names(intensities)
  # # average all columns except first one (t). We use an.approx from zoo to fill in gaps
  # resampled <- na.approx(intensities[, 2:ncol(intensities)])
  avg <- rowMeans(newdf[,-1], na.rm = TRUE)
  stdev <- apply(newdf[,-1], 1, sd, na.rm = TRUE)
  # count valid tracks per time point
  nv <- rowSums(!is.na(newdf[, -1]))
  # assemble simple df for plotting
  avgDF <- data.frame(t = newdf$RelativeTime,
                      avg = avg,
                      sd = stdev,
                      n = nv,
                      sem = stdev / sqrt(nv),
                      Condname = s)
  return(avgDF)
}


#' extract_peak_xyt - Get the XY and time coordinates of a detected peak
#' 
#' @param indf Input dataframe. What will be used to find filename and extract peak coordinates.
#' @param frecy File recycle. Input '0t' or '1t'. String to specify whether the current data is from recy-0 or recy-1.
#' @param xydf Dataframe containing all xy coordinates (Coorddf).
#' 
#' @return Create .csv files for each dish with xy and frame coordinates of each peak detected in with findpeaks

extract_peak_xyt <- function(indf,frecy,xydf) {
  img <- paste0("img_",frecy)
  knd <- paste0("kind_",frecy)
  nm <- paste0("name_",frecy)
  
  # Make new df with necessary data
  allpeaks_df <- indf %>% 
    filter(NewFrame == 0) %>% 
    select(img,knd,'frame',nm) %>%
    rename(spot_no = nm)
  allpeaks_df$condname <- paste0(allpeaks_df[[img]],"_",allpeaks_df[[knd]])
  
  # Merge in xy coordinates
  xyt_df <- merge(allpeaks_df, xydf, by = c("condname","spot_no"))
  
  # Save all peaks into a single df
  write.csv(xyt_df, paste0("Output/Data/peak-xyt/all-peaks-xyt_",frecy,".csv"), row.names = FALSE)
  
  # Save new file with detected spot for each dish
  uniqueCond <- unique(xyt_df$condname)
  for (obj in uniqueCond) {
    temp <- xyt_df %>% 
      filter(condname == obj)
    write.csv(temp, paste0("Output/Data/peak-xyt/",obj,"_peak-xyt.csv"), row.names = FALSE)
  }
}

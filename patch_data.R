
# This script loads in the filtered patch data and checks for invalid rows, as well as changes the
# neighborhood names to be compatible with the neighborhoods table in the data base.
# It then inserts the patch data into the data base, and patches the rows that have already
# been there.

# General setup------

library(RPostgreSQL)
con <- dbConnect(PostgreSQL(), user=stat_user, password = stat_password, 
                 dbname= stat_dbname, host= stat_host)

# Change the schema that I will access with the connection
set.schema <- dbSendStatement(con, "set search_path to 'schemacrime';")

library(testthat)
library(assertthat)

# For logging the error messages and warnings
sink("All_Output.log", type=c("output", "message"), append=TRUE, split=TRUE)

# Reading in the data from the shell
patch.input <- read.csv("stdin")
# And the data that is already in the data base
previous.weeks <- dbGetQuery(con, "select * from schemaCrime.blotter;")


# It takes the times as a factor, and we don't want that
previous.weeks$arrest_time <- as.character(previous.weeks$arrest_time)
# as before we need to convert to lowercase
names(patch.input) <- tolower(x = names(patch.input))



# Function to adjust the neighborhood names as in the ingest data frame-----

# This is exactly the same as in the ingest data frame

# First we need a function that can match misspelled neighborhoods to the real neighborhood
# name used and stored in the data base:
accepted.hoods <- dbGetQuery(con, "select * from schemaCrime.hoods;")$hood


# We need to make the data frame neighborhoods not factors but just strings
patch.input$neighborhood <- as.character(patch.input$neighborhood)

# This will look for misspellings or fragments of names. 
# It will not add Golden Triangle/Civic Arena to the list. 

changed.count <- 0 #Initializing global counter for number of rows changed

replace.neighborhood.name <- function(input.name, input.rowid){
  if(!(input.name %in% accepted.hoods) && 
     input.name!="Golden Triangle/Civic Arena"){ 
    # we don't need to see Golden Triangle here
    
    print(input.name)
    
    # We replace it with the first one of the similar neighborhoods, 
    # but print a warning if there are several
    replacement.hoods <- accepted.hoods[grepl(substr(tolower(input.name), 
                                                     start = 3, stop = 7), tolower(accepted.hoods))]
    
    if(length(replacement.hoods)>1){
      print(paste("For ID", input.rowid, "there are multiple matching neighborhoods, which are", replacement.hoods))
    }
    print(paste("replaced with", replacement.hoods[1]))}
  if(input.name=="Golden Triangle/Civic Arena"){
    return(input.name)
  }else if(is.na(replacement.hoods[1])){
    return(input.name)
  }else{
    assign("changed.count", changed.count+1, envir = .GlobalEnv) # counting that instance
    return(replacement.hoods[1])
  }
}



# Filtering the rows that have invalid data as in the ingest data frame-----

# Vector numbers to be filtered out
row.exeptions <- vector()

# Function to catch ill-formatted data
# Input: crime-data frame
# Output: cleaned crime-data frame
well.formatting <- function(data.input){
  for(i in 1:nrow(data.input)){
    # Before everything, we run the names through the replacement
    if(!(data.input$neighborhood[i] %in% accepted.hoods)){
      print(i)
      data.input$neighborhood[i] <- replace.neighborhood.name(data.input$neighborhood[i], data.input$x_id[i])
    }
    result <- tryCatch({
      expect_false(is.na(data.input$x_id[i]), info = i)
      expect_false(is.na(data.input$zone[i]), info = i)
      expect_true(data.input$neighborhood[i] %in% accepted.hoods, info = c(i,data.input$neighborhood[i]))
    }, 
    expectation_failure=function(e) {
      cat(conditionMessage(e))
      #invokeRestart("continue_test")
    })
    # there is a more elgant way to do this I'm sure
    # I just wish I could handle that in try catch
    if(!(is.na(data.input$x_id[i]) ||
         is.na(data.input$zone[i]) || 
         data.input$neighborhood[i] %in% accepted.hoods)){
      row.exeptions <- append(row.exeptions, i)
    }
  }
  # return the frame that only has the valid rows
  # it needs to handle cases where there are no excluded rows
  if(length(row.exeptions)==0){
    return(data.input)
  }else{
    return(data.input[-row.exeptions, ])}
}

# Get the cleaned data frame by executing the function
clean.patch.input <- well.formatting(patch.input)

# Record how many we skipped
number.skipped.invalid <- nrow(patch.input) - nrow(clean.patch.input)

# R is case-sensitive, so to insert it into the crime database that I created with SQL, I need
# to make the column names lower case.
names(clean.patch.input) <- tolower(x = names(clean.patch.input))



# Patching the data--------

# Now we check if we already have the rows in the data base
# This function replaces those rows with the new rows
# We load all of the ID's from the data base
previous.IDs <- dbGetQuery(con, "select x_id from schemaCrime.blotter;")


# Vector of IDs that were already in the data base
already.inData <-  vector()
#initializing the frame for the case where there is no data in the data base
noDuplicate.clean.patch.input <- clean.patch.input

# Function of checking for duplicates and patching them
# only run the function if there is data in the data base
# It removes the old row and inserts the updated one directly into the data base
# Input: data frame
# Output: data frame without duplicates, so we do not insert them again
if(nrow(previous.IDs)!=0){
  # We create the function of previous IDs
  patch.duplicates <- function(data.input){
    names(data.input) <- tolower(names(data.input)) # to work with SQL
    for(i in 1:length(data.input$x_id)){
      #print(i)
      result <- tryCatch({
        expect_false(data.input$x_id[i] %in% previous.IDs, info = i)
      }, 
      expectation_failure=function(e) {
        cat(conditionMessage(e))
        #invokeRestart("continue_test")
      })
      # there is a more elgant way to do this I'm sure
      # I also need all the other conditions here. I just wish I could handle that in try catch
      if(data.input$x_id[i] %in% previous.IDs$x_id){
        
        print(paste0("ID ",data.input$x_id[i], " is already in data frame"))
        # If this were patching, we would need to delete first
        # To insert the more recent row directly
        # We need to delete first
        query.delete <- sqlInterpolate(con, "DELETE FROM schemaCrime.blotter WHERE x_id = ?inputid;", 
                                       inputid = as.character(data.input[i, "x_id"]))
        delete.id <- dbGetQuery(con, query.delete)
        # And then add it again
        query.insert <- sqlAppendTable(con = con, table = "blotter", 
                                       values = data.input[i,], row.names = FALSE)
        insert.data <- dbGetQuery(con, query.insert)
        
        # We also need to define exceptions otherwise we insert them double
        already.inData <- append(already.inData, i)
      }
    }
    # return the frame that only has the valid rows
    # it needs to handle cases where there are no excluded rows
    if(length(already.inData)==0){
      return(data.input)
    }else if(length(already.inData)==nrow(data.input)){
      return(0)
    }else{
      return(data.input[-already.inData, ])}
  }
  
  # Applying the function
  rm(noDuplicate.clean.patch.input)
  noDuplicate.clean.patch.input <- patch.duplicates(clean.patch.input)
}



# Loading the new data into our crime database in schemaCrime.sql----


# Only insert if there is anything to insert
if(class(noDuplicate.clean.patch.input)!="numeric"){
  # directly inserting the data into the table called blotter, that contains all of the crime history
  query <- sqlAppendTable(con = con, table = "blotter", 
                          values = noDuplicate.clean.patch.input, row.names = FALSE)
  insert.data <- dbGetQuery(con, query)
}



# Report the modifications that we did, including the patching------

# first we need to read the old one to be able to append the data frame
log.frame <- read.csv("crime_log.csv")

skipping.string <- paste0("Number of skipped rows because they are invalid is ", number.skipped.invalid)
# print it on the console
print(skipping.string)
# also write that in our log file
# it just adds the new ones to it. We count the invalid as not patched
log.frame[1, "not.patched"] <- log.frame[1, "not.patched"] + number.skipped.invalid

# number of inserted rows
number.inserted <- ifelse(class(noDuplicate.clean.patch.input)=="numeric", 0, 
                          nrow(noDuplicate.clean.patch.input))
log.frame[1, "inserted"] <- log.frame[1, "inserted"] + number.inserted
print(paste0("The script inserted ", number.inserted, " rows into the data."))

# number of patched row, which are the valid ones that were not inserted in the final step
number.patched <- nrow(clean.patch.input)-number.inserted
log.frame[1, "patched"] <- log.frame[1, "patched"] + number.patched
print(paste0("The script patched ", number.patched, " rows of the data."))

# And the number of corrected rows due to wrong neighborhood names
log.frame[1, "corrected"] <- log.frame[1, "corrected"] + changed.count
print(paste0("Neighborhood names have been adjusted ", changed.count, " times."))

# Writing it into the file
write.csv(x = log.frame, "crime_log.csv", row.names = F)





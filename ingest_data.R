# This script loads in the filtered data and checks for invalid rows, as well as changes the
# neighborhood names to be compatible with the neighborhoods table in the data base.
# It then inserts the data into the data base.

# General setup-----

library(RPostgreSQL)
con <- dbConnect(PostgreSQL(), user=stat_user, password = stat_password, 
                 dbname= stat_dbname, host= stat_host)

# Change the schema that I will access with the connection
set.schema <- dbSendStatement(con, "set search_path to 'schemacrime';")

library(testthat)


# For logging the error messages and warnings
sink("All_Output.log", type=c("output", "message"), append=TRUE, split=TRUE)


# Reading in the data from the shell
# It is important that it uses the first column as the rownames and does not 
# create an extra column. This is taken care of in Filter_DATA.R by not writing the rownames.
blotter.input <- read.csv("stdin", header = TRUE)



# Function to adjust the neighborhood names-----

# First we need a function that can match misspelled neighborhoods to the real neighborhood
# name used and stored in the data base:
accepted.hoods <- dbGetQuery(con, "select * from schemaCrime.hoods;")$hood

# I found a lot of Golden Triangle/Civic Arena, but it does not occur in the list:
accepted.civic <- dbGetQuery(con, "SELECT * FROM hoods WHERE hood
LIKE '%Civic%'") # There is really nothing with Civic Arena.
accepted.golden <- dbGetQuery(con, "SELECT * FROM hoods WHERE hood
LIKE '%Golden%'") # And nothing with golden
# It will not add Golden Triangle/Civic Arena to the list, it will be filtered out as invalid.

# We need to make the data frame neighborhoods not factors but just strings
blotter.input$NEIGHBORHOOD <- as.character(blotter.input$NEIGHBORHOOD)



changed.count <- 0 #Initializing global counter for number of rows changed
# This function will look for misspellings or fragments of neighborhood names and replace them
# with the correct one. It will also count how many times it changed a name.
# Input: neighborhood name
# Output: corrected neighborhood name or intial input if there is no similar name available
#         and the name should be invalid
replace.neighborhood.name <- function(input.name, input.rowid){
    if(input.name %in% accepted.hoods){warning("The neighborhood name should have been accepted.")}
    if(!(input.name %in% accepted.hoods) &&  
       input.name!="Golden Triangle/Civic Arena"){ 
      # we don't need to see Golden Triangle here
      
      print(input.name)
      
      if(tolower(input.name) %in% tolower(accepted.hoods)){
        replacement.hoods <- accepted.hoods[which(tolower(accepted.hoods)==tolower(input.name))]
      }else{
        # We replace it with the first one of the similar neighborhoods, 
        # but print a warning if there are several
        replacement.hoods <- accepted.hoods[grepl(substr(tolower(input.name), 
                                                         start = 4, stop = 7), tolower(accepted.hoods))]
        }
      
     
      
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



# Filtering the rows that have invalid data------

# Vector of row numbers to be filtered out
row.exeptions <- vector()

# Function to catch ill-formatted data with warnings
  # Input: crime-data frame
  # Output: cleaned crime-data frame
  # Calls function: replace.neighborhood.name
well.formatting <- function(data.input){
  # We loop over all rows in the data
  for(i in 1:nrow(data.input)){
    # Before everything, we run the names through the name replacement
    if(!(data.input$NEIGHBORHOOD[i] %in% accepted.hoods)){
      print(i)
      data.input$NEIGHBORHOOD[i] <- replace.neighborhood.name(data.input$NEIGHBORHOOD[i], data.input$X_id[i])
      # This replace with the inital value if the name should be counted as invalid
      }
    result <- tryCatch({
      expect_false(is.na(data.input$X_id[i]), info = i)
      expect_false(is.na(data.input$ZONE[i]), info = i)
      expect_true(data.input$NEIGHBORHOOD[i] %in% accepted.hoods, info = c(i,data.input$NEIGHBORHOOD[i]))
      }, 
      expectation_failure=function(e) {
      cat(conditionMessage(e))
      #invokeRestart("continue_test")
    })
    # We then separately record the rows that need to be deleted from the data frame
    # there is a more elgant way to do this I'm sure
    # I just wish I could handle that in try catch
    if(!(is.na(data.input$X_id[i]) ||
         is.na(data.input$ZONE[i]) || 
         data.input$NEIGHBORHOOD[i] %in% accepted.hoods)){
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
clean.blotter.input <- well.formatting(blotter.input)

# Record how many we skipped
number.skipped.invalid <- nrow(blotter.input) - nrow(clean.blotter.input)



# Inserting the data in to the data base, step 1: Checking if row is there-------

# R is case-sensitive, so to insert it into the crime database that I created with SQL, I need
# to make the column names lower case.
names(clean.blotter.input) <- tolower(x = names(clean.blotter.input))


# Now we check if we already have the rows in the data base
# We load all of the ID's from the data base
previous.IDs <- dbGetQuery(con, "select x_id from schemaCrime.blotter;")


# Vector of row numbers that were already in the data base
already.inData <-  vector()

#initializing the frame for the case where there is no data in the data base
noDuplicate.clean.blotter.input <- clean.blotter.input

# Function of checking for duplicates
# only run the function if there is data in the data base
# Input: data frame
# Output: data frame without duplicates
if(nrow(previous.IDs)!=0){
  # We create the function of previous IDs
  avoid.duplicates <- function(data.input){
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
      if(data.input$x_id[i] %in% previous.IDs$x_id){
        print(paste0("ID ",data.input$x_id[i], " is already in data frame"))
        # We define exceptions as we did before in the well.formatting function
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

  # this deletes the duplicates directly from the schemacrime.blotter
  rm(noDuplicate.clean.blotter.input)
  noDuplicate.clean.blotter.input <- avoid.duplicates(clean.blotter.input)
}



# Loading this data frame into our crime database in schemaCrime.sql----


# Clean the blotter (only needed if we start over again)
#dbSendStatement(con, "DELETE FROM schemaCrime.blotterinput;")

# Only insert if there is anything to insert
if(class(noDuplicate.clean.blotter.input)!="numeric"){
  # directly inserting the data into the table called blotter, that contains all of the crime history
  query <- sqlAppendTable(con = con, table = "blotter", 
                          values = noDuplicate.clean.blotter.input, row.names = FALSE)
  insert.data <- dbGetQuery(con, query)
}



# Report the rows that where skipped or corrected--------

  # first we need to read the old one to be able to append the data frame
  log.frame <- read.csv("crime_log.csv")

  # skipped data
  skipping.string <- paste0("Number of skipped rows because they are invalid is ", number.skipped.invalid)
  # print it on the console
  print(skipping.string)
  # also write that in our log file
  # it just adds the new ones to it, so the file contains the final sum
  log.frame[1, "invalid"] <- log.frame[1, "invalid"] + number.skipped.invalid
  
  # Number of inserted rows
  number.inserted <- ifelse(class(noDuplicate.clean.blotter.input)=="numeric", 0, 
         nrow(noDuplicate.clean.blotter.input))
  log.frame[1, "inserted"] <- log.frame[1, "inserted"] + number.inserted
  print(paste0("The script inserted ", number.inserted, " rows into the data."))
  
  # Number of corrected neighborhood names
  log.frame[1, "corrected"] <- log.frame[1, "corrected"] + changed.count
  print(paste0("Neighborhood names have been adjusted ", changed.count, " times."))
  
  # Writing it into the log file
  write.csv(x = log.frame, "crime_log.csv", row.names = F)
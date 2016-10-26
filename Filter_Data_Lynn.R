# This script will read in the data and filter it


# General setup----

# Setting up the Postgresql connection
library(RPostgreSQL)
con <- dbConnect(PostgreSQL(), user="lhk", password = "0ntBNyCcuipdh8g", 
                 dbname="lhk", host="pg.stat.cmu.edu")

# Change the schema that I will access with the connection
set.schema <- dbSendStatement(con, "set search_path to 'schemacrime';")

# how to get the argument from the command line
file.name.blotter = commandArgs(trailingOnly=TRUE)

# if this is the base data we create the log file. This should only happen once
if(file.name.blotter=="crime-base.csv"){
  write.csv(x = data.frame("inserted"=0, "invalid"=0, "corrected"=0, "patched"=0, "not.patched"=0), 
            "crime_log_Lynn.csv", row.names = F)
}

# I first need to download the data to my folder to run these scripts.


# Loading the data and relevant crime types-----

blotter <- read.csv(as.character(file.name.blotter))

# Now using the table, which I set up in sql, to filter the data
# it only contains the relevant crime types
interesting.crime.types <- dbGetQuery(con, "select * from schemaCrime.crime_types")


# Filtering function------

# Filtering: This is a pre-cleaning of the data. The rest will be done in the ingest file
# Input: the data set
# Output: the data set that contains only relevant crimes and that has zone information
filter.data <- function(input.blotter){
  # Only the offense-type
  # first convert NA into offense
  input.blotter[is.na(input.blotter$REPORT_NAME)==T,"REPORT_NAME"] <- "OFFENSE 2.0"
  # Only including the rows with offense
  input.blotter <- input.blotter[input.blotter$REPORT_NAME=="OFFENSE 2.0",]
  # Excluding the data with wrong hood, this needs to be done here because we filter for the 
  # patch files also
  
  # Excluding the data with no zone
  input.blotter <- input.blotter[is.na(input.blotter$ZONE)==F,]
  
  # Only including the rows with crime types from the table
  input.blotter <- input.blotter[input.blotter$SECTION %in% interesting.crime.types$section,]
  return(input.blotter)
}

# Run the filtering
filtered.blotter <- filter.data(blotter)


# Writing the data into the shell and on the log files-------

# Writing in the log file what we filtered out, because those rows count as invalid data
log.frame <- read.csv("crime_log_Lynn.csv") # reading in the log file
number.skipped.invalid <- nrow(blotter)-nrow(filtered.blotter)
log.frame[1, "invalid"] <- log.frame[1, "invalid"] + number.skipped.invalid # adding it onto the number
# Writing it into the file
write.csv(x = log.frame, "crime_log_Lynn.csv", row.names = F)


# Print out to STDOUT so that the other scripts can read the filtered data
# I prevent the rownames from being written
write.csv(filtered.blotter, row.names = FALSE)



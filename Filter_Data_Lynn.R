# Reading in the data and filtering it

# Setting up the Postgresql connection
library(RPostgreSQL)
con <- dbConnect(PostgreSQL(), user="lhk", password = "0ntBNyCcuipdh8g", 
                 dbname="lhk", host="pg.stat.cmu.edu")

# Change the schema that I will access with the connection
set.schema <- dbSendStatement(con, "set search_path to 'schemacrime';")

# how to get the argument from the command line
file.name.blotter = commandArgs(trailingOnly=TRUE)

# For testing we need the data
#file.name.blotter <- "crime-base.csv"


# If I leave SQL out completely I first need to download the data to my folder


blotter <- read.csv(as.character(file.name.blotter))

# now use the table set up in sql to filter the data
# it only contains the relevant crime types
interesting.crime.types <- dbGetQuery(con, "select * from schemaCrime.crime_types")

# check the acceptable hoods
#accepted.hoods <- dbGetQuery(con, "select * from schemaCrime.hoods;")$hood
# have it in the ingest and patch file


# Filtering
filter.data <- function(input.blotter){
  # Only the offense-type
  # first convert NA into offense
  input.blotter[is.na(input.blotter$REPORT_NAME)==T,"REPORT_NAME"] <- "OFFENSE 2.0"
  # Only including the rows with offense
  input.blotter <- input.blotter[input.blotter$REPORT_NAME=="OFFENSE 2.0",]
  # Excluding the data with wrong hood, this needs to be done here because we filter for the 
  # patch files also
  #input.blotter <- input.blotter[input.blotter$NEIGHBORHOOD %in% accepted.hoods,]
  # have it in the ingest and patch file
  
  # Excluding the data with no zone
  input.blotter <- input.blotter[is.na(input.blotter$ZONE)==F,]
  # Only including the rows with crime types from the table
  input.blotter <- input.blotter[input.blotter$SECTION %in% interesting.crime.types$section,]
  return(input.blotter)
}

# Run the filtering
filtered.blotter <- filter.data(blotter)

# Print out to STDOUT
# I prevent the rownames from being written
write.csv(filtered.blotter, row.names = FALSE)
#write.csv(filtered.blotter)
#write.csv(c(1,2), row.names = FALSE)
#write.csv(blotter$X_id, row.names = FALSE)

# The problem in not in this script
#write.csv(filtered.blotter[1:3,], row.names = FALSE)

#write.csv(filtered.blotter[1:3,], row.names = TRUE)

# Patching the files

library(RPostgreSQL)
con <- dbConnect(PostgreSQL(), user="lhk", password = "0ntBNyCcuipdh8g", 
                 dbname="lhk", host="pg.stat.cmu.edu")

# Change the schema that I will access with the connection
dbSendStatement(con, "set search_path to 'schemacrime';")

# this requires me to have all the weeks on file I think. Right now I can only do one at a time

# do we even need week 1? I thought we start with week 1, or is that patching the base?

# Reading in the data from the shell
patch.input <- read.csv("stdin")
previous.weeks <- dbGetQuery(con, "select * from schemaCrime.blotter;")

# for testing
#patch.input <- read.csv("crime-week-1-patch.csv", stringsAsFactors=FALSE)
#previous.weeks <- filtered.blotter #read.csv("crime-base.csv")


# It takes the times as a factor, and we don't want that
previous.weeks$arrest_time <- as.character(previous.weeks$arrest_time)
# as before we need to convert to lowercase
names(patch.input) <- tolower(x = names(patch.input))

old.crime <- patch.input[patch.input$x_id < max(previous.weeks$x_id),]
new.crime <- patch.input[patch.input$x_id > max(previous.weeks$x_id),]
# this is empty. It should have an ID that is larger as before

# To patch the data we try to avoid searching the entire existing data base 
# The first function inserts the data that has been updated
  # Input: Part of the patch data that are updates
  # Output directly to the schemacrime.sql, or added to new.crime
patching.data <- function(data.input){
  for(i in 1:nrow(data.input)){
    if(nrow(previous.weeks[previous.weeks$x_id==data.input[i, "x_id"],]) == 0){
      # if it is not in the existing data base
      new.crime <- rbind(new.crime, data.input[i,])
    }else{
      # if it is in the existing data base
      previous.weeks[previous.weeks$x_id==data.input[i, "x_id"],] <- data.input[i,]
      # it sees it as a factor, not as a time. perhaps insert into sql directly here
      
      # To insert directly
      # We need to delete first
      query.delete <- sqlInterpolate(con, "DELETE FROM schemaCrime.blotter WHERE x_id = ?inputid;", 
                                          inputid = as.character(data.input[i, "x_id"]))
      delete.id <- dbGetQuery(con, query.delete)
      # And then add it again
      query.insert <- sqlAppendTable(con = con, table = "blotter", 
                              values = data.input[i,], row.names = FALSE)
      insert.data <- dbGetQuery(con, query.insert)
      }
  }
  }

patching.data(old.crime)

# The second function inserts the new crimes
inserting.patch.new <- function(data.input){
  query.insert <- sqlAppendTable(con = con, table = "blotter", 
                                 values = data.input, row.names = FALSE)
  insert.data <- dbGetQuery(con, query.insert)
}

if(nrow(new.crime)!=0){inserting.patch.new(new.crime)}


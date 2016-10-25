library(RPostgreSQL)
con <- dbConnect(PostgreSQL(), user="lhk", password = "0ntBNyCcuipdh8g", 
                 dbname="lhk", host="pg.stat.cmu.edu")

# Change the schema that I will access with the connection
dbSendStatement(con, "set search_path to 'schemacrime';")

library(testthat)
library(assertthat)

#write.csv(c(1,2)) # it gets here

# Reading in the data from the shell
# It is important that it uses the first column as the rownames and does not create an extra column
# this is taken care of in Filter_DATA_Lynn.R

# make error log!
# save the synonyms for other neighborhoods

blotter.input <- read.csv("stdin", header = TRUE)

#blotter.input <- filtered.blotter


# Testing for problems
# row with no ID, an invalid zone, or other problems


# check the hoods, better with hash, but in this case it is ok, since small
accepted.hoods <- dbGetQuery(con, "select * from schemaCrime.hoods;")$hood


# #old but working!
# for(i in 1:nrow(blotter.input)){
#  # print(i)
#   
# result <- withCallingHandlers({
#   expect_false(is.na(blotter.input$X_id[i]), info = i)
#   expect_false(is.na(blotter.input$ZONE[i]), info = i)
#   #expect_true(is.na(blotter.input$ZONE[i]), info = i)
#   expect_true(blotter.input$NEIGHBORHOOD[i] %in% accepted.hoods, info = c(i,blotter.input$NEIGHBORHOOD[i]))
#   # other problems?
#   #expect_that(string, matches("t.+ting"))
# }, expectation_failure=function(e) {
#   row.exeptions <- append(row.exeptions, i) # it doesn't do this
#   #print(i) #it does this
#   cat(conditionMessage(e))
#   invokeRestart("continue_test")
# })
# }


# Vector row IDs to be filtered out
row.exeptions <- vector()

# Function to catch ill-formatted data
  # Input: crime-data frame
  # Output: cleaned crime-data frame
well.formatting <- function(data.input){
  for(i in 1:nrow(data.input)){
    # print(i)
    result <- tryCatch({
      expect_false(is.na(data.input$X_id[i]), info = i)
      expect_false(is.na(data.input$ZONE[i]), info = i)
      #expect_true(is.na(data.input$ZONE[i]), info = i)
      expect_true(data.input$NEIGHBORHOOD[i] %in% accepted.hoods, info = c(i,data.input$NEIGHBORHOOD[i]))
      # other problems?
      #expect_that(string, matches("t.+ting"))
    }, #error = function(i){row.exeptions <- append(row.exeptions, i) }, # doesn't work
    expectation_failure=function(e) {
      cat(conditionMessage(e))
      #invokeRestart("continue_test")
    })
    # there is a more elgant way to do this I'm sure
    # I also need all the other conditions here. I just wish I could handle that in try catch
    if(!(is.na(data.input$X_id[i]) ||
         is.na(data.input$ZONE[i]) || 
         data.input$NEIGHBORHOOD[i] %in% accepted.hoods)){
      row.exeptions <- append(row.exeptions, i)
      i=i-1 # to move back and not skip one
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
#nrow(blotter.input)
#nrow(clean.blotter.input)
# R is case-sensitive, so to insert it into the crime database that I created with SQL, I need
# to make the column names lower case.
names(clean.blotter.input) <- tolower(x = names(clean.blotter.input))
# need that later for strings that are similar but not the same
#grepl("a", accepted.hoods)

#grepl(substr(accepted.hoods, start = 2, stop = 4), accepted.hoods)

# Now we check if we already have the rows in the data base
# This function replaces those rows with the new rows
# We load all of the ID's from the data base
previous.IDs <- dbGetQuery(con, "select x_id from schemaCrime.blotter;")

previous.IDs$x_id

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
      # there is a more elgant way to do this I'm sure
      # I also need all the other conditions here. I just wish I could handle that in try catch
      if(data.input$x_id[i] %in% previous.IDs$x_id){
        # To insert the more recent row directly
        # We need to delete first
        print(paste0("ID ",data.input$x_id[i], " is already in data frame"))
        # we need to do that in patch, but not in ingest
        query.delete <- sqlInterpolate(con, "DELETE FROM schemaCrime.blotter WHERE x_id = ?inputid;", 
                                       inputid = as.character(data.input[i, "x_id"]))
        delete.id <- dbGetQuery(con, query.delete)
        # And then add it again later all together
        # test if 24784 is there in the end!
        #query.insert <- sqlAppendTable(con = con, table = "blotter", 
        #                               values = data.input[i,], row.names = FALSE)
        #insert.data <- dbGetQuery(con, query.insert)
      }
    }
  }
  
  # this deletes the duplicates directly from the schemacrime.blotter
  #clean.blotter.input <- avoid.duplicates(clean.blotter.input)
  avoid.duplicates(clean.blotter.input)
  
}

# Loading this data frame into our crime database in schemaCrime.sql


# Clean the blotter (only needed if we start over again)
#dbSendStatement(con, "DELETE FROM schemaCrime.blotterinput;")

# Only insert if there is anything to insert
  # directly inserting the data into the table called blotter, that contains all of the crime history
  query <- sqlAppendTable(con = con, table = "blotter", 
                          values = clean.blotter.input, row.names = FALSE)
  insert.data <- dbGetQuery(con, query)




# optional prints:
#head(dbGetQuery(con, "select * from schemaCrime.blotter;"))
#head(blotter.input)
# 


# Notes:-------

#parametrized queries

# copying that data into the one we want
#result <- dbSendStatement(con, "INSERT INTO schemaCrime.blotter VALUES ", )

#num_rows <- dbGetRowsAffected(result)
#dbGetQuery(con, "select * from schemaCrime.blotter;")
# Why can't I access this?
#dbClearResult(result)


# other tests
# # check for the table
#dbExistsTable(con, "schemacrime.blotterinput") # not sure why it doesn't find it

# # This is when I used the shell to set up the tables
# blotter <- dbGetQuery(con, "select * from schemaCrime.blotter where REPORT_NAME ~ 'OFFENSE 2.0' AND ZONE IS NOT NULL AND NEIGHBORHOOD in (select hood from schemaCrime.hoods);")



# notes
#hash(neighborhoods) match to id or to NA if not in neighborhoods.hoods
# making a hash table with new neighborhood ones 
#do that here before going to sql
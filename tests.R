# Test suite for various function in the crime data challenge

library(testthat)

# Since the scripts are based on terminal inputs, the test files cannot be run
# from the terminal. If we would include source("scriptname"), and run it from
# the terminal, the execution would be halted. We need to use the function when
# they are available in the workspace.

# Testing functions in filter_data.R-----

# function filter.data

test_that("we filter out data with relevant missing data", {
  irrelevant.crime.type <- data.frame("X_id" = 20995, "REPORT_NAME"="OFFENSE 2.0", "SECTION"=29, 
                                  "DESCRIPTION"= "Missing Juvenile",
                                  "ARREST_TIME"="2015-03-10T00:56:00", "ADDRESS" = "7600 block Kelly St",
                                  "NEIGHBORHOOD" = "Homewood South", "ZONE"=5)
  expect_equal(nrow(filter.data(irrelevant.crime.type)), 0)
  
  no.arrest_time <- data.frame("X_id" = 20995, "REPORT_NAME"="OFFENSE 2.0", "SECTION"=3701, 
                                      "DESCRIPTION"= "Missing Juvenile",
                                      "ARREST_TIME"=NA, 
                                      "ADDRESS" = "7600 block Kelly St",
                                      "NEIGHBORHOOD" = "Homewood South", "ZONE"=5)
  expect_equal(nrow(filter.data(no.arrest_time)), 0)
  
  no.neighborhood <- data.frame("X_id" = 20995, "REPORT_NAME"="OFFENSE 2.0", "SECTION"=3701, 
                                "DESCRIPTION"= "Missing Juvenile",
                                "ARREST_TIME"="2015-03-10T00:56:00", 
                                "ADDRESS" = "7600 block Kelly St",
                                "NEIGHBORHOOD" = NA, "ZONE"=5)
  expect_equal(nrow(filter.data(no.neighborhood)), 0)
  
  no.zone <- data.frame("X_id" = 20995, "REPORT_NAME"="OFFENSE 2.0", "SECTION"=3701, 
                                "DESCRIPTION"= "Missing Juvenile",
                                "ARREST_TIME"="2015-03-10T00:56:00", 
                                "ADDRESS" = "7600 block Kelly St",
                                "NEIGHBORHOOD" = "Homewood South", "ZONE"=NA)
  expect_equal(nrow(filter.data(no.zone)), 0)
})

test_that("we leave data with irrelevant missing entries", {
  no.description <- data.frame("X_id" = 20848, "REPORT_NAME"="OFFENSE 2.0", "SECTION"=3921, 
                            "DESCRIPTION"= NA,
                            "ARREST_TIME"="2015-03-10T01:38:00","ADDRESS" = "7600 block Kelly St",
                            "NEIGHBORHOOD" = "Homewood South", "ZONE"=5)
  expect_equal(filter.data(no.description), no.description)
  
  no.address <- data.frame("X_id" = 20848, "REPORT_NAME"="OFFENSE 2.0", "SECTION"=3921, 
                               "DESCRIPTION"= "some description",
                               "ARREST_TIME"="2015-03-10T01:38:00","ADDRESS" = NA,
                               "NEIGHBORHOOD" = "Homewood South", "ZONE"=5)
  expect_equal(filter.data(no.address), no.address)
  
})


# Testing functions in ingest_data----

# function replace.neighborhood.name

replace.neighborhood.name(input.name = )

test_that("accepted hoods issue a warning",{
  for(hood in accepted.hoods){
    expect_warning(replace.neighborhood.name(input.name = hood, input.rowid = 1))
  }
})

test_that("lowercase or uppercase spelling of accepted hoods results in the excepted hoods",{
  for(hood in accepted.hoods){
    lower.hood <- tolower(hood)
    upper.hood <- toupper(hood)
    expect_equal(replace.neighborhood.name(input.name = lower.hood, input.rowid = 1), hood)
    expect_equal(replace.neighborhood.name(input.name = upper.hood, input.rowid = 1), hood)
  }
})

test_that("we can find replacement for partial versions of accepted hoods", {
  for(hood in accepted.hoods){
    partial.hood <- substr(hood, 1, 3) # this is not the same as I use in the function
    # We test if the partial.hood has been replaced. If there was no match, it is not replaced.
    expect_false(replace.neighborhood.name(input.name = partial.hood, input.rowid = 1) == partial.hood)
  }
})

test_that("we don't replace gibberish", {
    expect_equal(replace.neighborhood.name(input.name = "wnbeksnekej", input.rowid = 1), "wnbeksnekej")
})



-- Preparing:
-- ssh lhk@pg.stat.cmu.edu
-- cd problem-bank
-- cd Data/
-- git pull

-- psql

CREATE SCHEMA schemaCrime;

-- Creating the table for the neighborhoods
CREATE TABLE schemaCrime.hoods (
	intptlat10 numeric,
	intptlon10 numeric,
	hood text UNIQUE PRIMARY KEY,
	hood_no integer,
	acres numeric,
	sqmiles numeric
);


-- Filling hoods with data
\copy schemaCrime.hoods FROM 'police-neighborhoods.csv' DELIMITER ','  CSV HEADER;

-- Creating the table that is our data base
CREATE TABLE schemaCrime.blotter (
	X_id numeric PRIMARY KEY,
	REPORT_NAME text CHECK (REPORT_NAME in ('ARREST', 'OFFENSE 2.0')) DEFAULT 'OFFENSE 2.0',
	SECTION text,
	DESCRIPTION text,
	ARREST_TIME timestamp,
	ADDRESS text,
	NEIGHBORHOOD text REFERENCES schemaCrime.hoods (hood),
	ZONE integer
) ;

-- Selection table for crime types that will be used in the R script
create table schemaCrime.crime_types (
    SECTION text UNIQUE not null PRIMARY KEY,
    DESCRIPTION text UNIQUE 
);

insert into schemaCrime.crime_types (SECTION, DESCRIPTION)
       values ('3304', 'Criminal mischief'),
              ('2709', 'Harassment'),
              ('3502', 'Burglary'),
              ('13(a)(16)', 'Possession of a controlled substance'),
              ('13(a)(30)', 'Possession w/ intent to deliver'),
              ('3701', 'Robbery'),
              ('3921', 'Theft'),
              ('3921(a)', 'Theft of movable property'),
              ('3934', 'Theft from a motor vehicle'),
              ('3929', 'Retail theft'),
              ('2701', 'Simple assault'),
              ('2702', 'Aggravated assault'),
              ('2501', 'Homicide');



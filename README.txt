This is the readme description.

To run the analysis, one will need execute the sql commands once and then type these commands in the shell:

Rscript filter_data.R crime-base.csv | Rscript ingest_data.R

Rscript filter_data.R crime-week-1-patch.csv | Rscript patch_data.R
Rscript filter_data.R crime-week-1.csv | Rscript ingest_data.R

Rscript filter_data.R crime-week-2-patch.csv | Rscript patch_data.R
Rscript filter_data.R crime-week-2.csv | Rscript ingest_data.R

Rscript filter_data.R crime-week-3-patch.csv | Rscript patch_data.R
Rscript filter_data.R crime-week-3.csv | Rscript ingest_data.R

Rscript filter_data.R crime-week-4-patch.csv | Rscript patch_data.R
Rscript filter_data.R crime-week-4.csv | Rscript ingest_data.R

Rscript -e "library(knitr); knit('report.Rmd')"

If we read in everything from the start, we need:
delete from schemacrime.blotter; 
# Not necessary anymore, but it makes it better.
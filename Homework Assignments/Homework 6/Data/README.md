# Mroz textbook data

Source: https://www.stata.com/data/jwooldridge/eacsap/mroz.dta
Textbook data page: https://www.stata.com/texts/eacsap/
Retrieved for this analysis on November 8, 2026 (America/New_York).

`mroz.dta` is the unmodified Stata download (753 observations, 22 variables).
`mroz.csv` was converted from that file using the already installed R `haven`
package; missing values are empty CSV fields. The analysis script uses only
base R and the CSV, so no package installation is needed to reproduce it.

Conversion command, from the course repository root:

```r
d <- haven::read_dta("Homework Assignments/Homework 6/Data/mroz.dta")
write.csv(as.data.frame(d), "Homework Assignments/Homework 6/Data/mroz.csv",
          row.names = FALSE, na = "")
```

The local Lab 7 `mroz.txt` is a Stata variable-description log, not a data table.
The downloaded data reproduce the Lab 7 regression results to reported
precision. The script records the CSV's MD5 checksum in its result log.

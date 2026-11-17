# HW6 Q4

From the Homework 6 folder, run:

```sh
Rscript R/q4_hw6_commands.R
```

The script loads `Data/mroz.csv`, selects the 428 working women, and copies
`lwage` and `expersq` to the names `logwage` and `exper2` used in HW6.
It then runs the supplied first- and second-stage commands unchanged inside
`with(mroz, {...})`. No packages are required. The script contains no extra
calculations, diagnostics, or output-writing commands.

`q3_q4_iv.R` redirects to this script. Q3 uses the results printed in Lab 7.
The identical Q4 code is included directly in the report and its appendix.
Earlier comparison files in `Output/` are retained as reference results;
the simplified script does not regenerate them.

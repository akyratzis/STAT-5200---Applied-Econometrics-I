rm(list = ls()); # refresh memory

# ------------------------------------------------------------------
# US trade in semiconductor equipment and AI hardware, 2020 onwards,
# monthly at HS10 by partner country, from the Census API.
#
# One file is written per flow, heading and month under
# data/raw/census. A month already on disk is not requested again, so
# the script can be stopped and restarted, and a failed run costs only
# the months it had not yet reached.
# ------------------------------------------------------------------

source("00_setup.R");

FLOWS   = c("exports", "imports");
PERIODS = census_periods();

cat("Requesting", length(FLOWS)*length(HS4_CODES)*length(PERIODS),
    "commodity-months at most.\n");
cat("Cached months are skipped.\n\n");

n_new = 0;
n_cached = 0;
n_empty = 0;

for (flow in FLOWS){
  for (hs4 in HS4_CODES){
    for (period in PERIODS){

      f = file.path(DIR_CENSUS, sprintf("%s_%s_%s.csv", flow, hs4, period));

      if (file.exists(f)){
        n_cached = n_cached + 1;
        next;
      }

      d = census_month(hs4 = hs4, period = period, flow = flow);

      if (is.null(d) || nrow(d) == 0){
        # Record the empty answer so the month is not requested again.
        write.csv(data.frame(), f, row.names = FALSE);
        n_empty = n_empty + 1;
      } else {
        write.csv(d, f, row.names = FALSE);
        n_new = n_new + 1;
      }

      Sys.sleep(0.3);   # keep the request rate polite
    }
    cat(sprintf("%-8s %s done\n", flow, hs4));
  }
}

cat(sprintf("\nnew: %d   cached: %d   empty: %d\n", n_new, n_cached, n_empty));

# ------------------------------------------------------------------
# Combine into one analysis file
# ------------------------------------------------------------------
files = list.files(DIR_CENSUS, pattern = "\\.csv$", full.names = TRUE);
files = files[file.size(files) > 10];   # drop the empty-month markers

parts = lapply(files, function(f) read.csv(f, colClasses = "character"));
parts = parts[sapply(parts, nrow) > 0];

census = do.call(rbind, lapply(parts, function(p){
  value_col = intersect(c("ALL_VAL_MO", "GEN_VAL_MO"), names(p));
  comm_col  = intersect(c("E_COMMODITY", "I_COMMODITY"), names(p));
  data.frame(flow      = p$flow,
             period    = p$period,
             cty_code  = p$CTY_CODE,
             cty_name  = p$CTY_NAME,
             hs10      = p[[comm_col]],
             comm_lvl  = p$COMM_LVL,
             value     = suppressWarnings(as.numeric(p[[value_col]])),
             qty       = suppressWarnings(as.numeric(p$QTY_1_MO)),
             qty_unit  = p$UNIT_QY1,
             stringsAsFactors = FALSE);
}));

census$hs4   = substr(census$hs10, 1, 4);
census$year  = as.integer(substr(census$period, 1, 4));
census$month = as.integer(substr(census$period, 6, 7));

# Census reports partner totals alongside countries; keep countries only.
census = census[census$cty_code != "-" & census$cty_name != "TOTAL FOR ALL COUNTRIES", ];

saveRDS(census, file.path(DIR_PROCESSED, "census_ai_hardware.rds"));

print("Rows by flow and year ...");
print(table(census$flow, census$year));

print("US export value by heading, $bn, most recent full year ...");
y = max(census$year[census$month == 12], na.rm = TRUE);
e = census[census$flow == "exports" & census$year == y, ];
print(round(tapply(e$value, e$hs4, sum, na.rm = TRUE)/1e9, 2));

print("Written to ...");
print(normalizePath(file.path(DIR_PROCESSED, "census_ai_hardware.rds")));

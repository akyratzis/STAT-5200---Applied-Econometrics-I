rm(list = ls()); # refresh memory

# ------------------------------------------------------------------
# Shared paths, the Census API key, and one helper used by 01.
# Sourced by the other scripts; not run on its own.
# ------------------------------------------------------------------

DIR_RAW       = file.path("..", "Data", "Raw");
DIR_CENSUS    = file.path(DIR_RAW, "Census");
DIR_PROCESSED = file.path("..", "Data", "Processed");
DIR_FIGURES   = file.path("..", "Figures");
DIR_OUTPUT    = file.path("..", "Output");

for (d in c(DIR_CENSUS, DIR_PROCESSED, DIR_FIGURES, DIR_OUTPUT)){
  if (!dir.exists(d)) dir.create(d, recursive = TRUE);
}

# The key lives in ~/.Renviron, never in this repository. Add the line
#     CENSUS_API_KEY=your_key_here
# to that file and restart R. Sign up at api.census.gov/data/key_signup.html.
CENSUS_API_KEY = Sys.getenv("CENSUS_API_KEY");

if (!nzchar(CENSUS_API_KEY)){
  stop("CENSUS_API_KEY is not set. Put it in ~/.Renviron and restart R.");
}

# Product headings. 8486 is machines for manufacturing semiconductor
# devices, the treated group; the rest are the AI-hardware comparison
# set and the controls.
HS4_CODES = c("8486",   # semiconductor manufacturing equipment
              "8542",   # electronic integrated circuits
              "8541",   # semiconductor devices
              "8471",   # computers and servers
              "8473",   # parts for 8471
              "8517",   # networking apparatus
              "8504");  # transformers and static converters

PERIOD_FROM = "2020-01";
PERIOD_TO   = "2026-08";   # Census runs about five weeks behind.

# ------------------------------------------------------------------
# One Census call: one commodity heading, one month, all partners.
#
# Returns a data frame, or NULL when the API reports no matching rows
# (a 204 or an empty body), which is a normal answer rather than a
# failure. Anything else stops with the URL so it can be inspected.
# ------------------------------------------------------------------
census_month = function(hs4, period, flow = "exports", comm_lvl = "HS10"){

  base = sprintf("https://api.census.gov/data/timeseries/intltrade/%s/hs", flow);

  commodity_var = if (flow == "exports") "E_COMMODITY" else "I_COMMODITY";
  value_var     = if (flow == "exports") "ALL_VAL_MO"  else "GEN_VAL_MO";

  query = list(get      = paste(c("CTY_CODE", "CTY_NAME", commodity_var,
                                  "COMM_LVL", value_var,
                                  "QTY_1_MO", "UNIT_QY1"), collapse = ","),
               time     = period,
               COMM_LVL = comm_lvl,
               key      = CENSUS_API_KEY);
  query[[commodity_var]] = hs4;

  resp = httr::GET(base, query = query, httr::timeout(60));

  if (httr::status_code(resp) == 204) return(NULL);

  if (httr::http_error(resp)){
    stop(sprintf("Census API returned %d for %s %s %s\n%s",
                 httr::status_code(resp), flow, hs4, period,
                 httr::modify_url(base, query = c(query, key = "REDACTED"))));
  }

  txt = httr::content(resp, as = "text", encoding = "UTF-8");
  if (!nzchar(txt) || substr(txt, 1, 1) != "[") return(NULL);

  m = jsonlite::fromJSON(txt);
  out = as.data.frame(m[-1, , drop = FALSE], stringsAsFactors = FALSE);
  names(out) = m[1, ];

  # The value and quantity fields come back as text.
  for (v in c(value_var, "QTY_1_MO")){
    if (v %in% names(out)) out[[v]] = suppressWarnings(as.numeric(out[[v]]));
  }

  out$flow   = flow;
  out$period = period;
  out;
}

# Months to request, as "YYYY-MM".
census_periods = function(from = PERIOD_FROM, to = PERIOD_TO){
  a = as.Date(paste0(from, "-01"));
  b = as.Date(paste0(to,   "-01"));
  format(seq(a, b, by = "month"), "%Y-%m");
}

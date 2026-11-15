"""
Downloads the raw UN Comtrade data that Fajgelbaum et al. (2024) build their
trade panel from: annual goods trade, HS 2012 (H4) classification, all
reporters, 2014-2019. This is the input their README asks for in
data/raw/comtrade/, which they could not redistribute.

This script only downloads. The files are saved exactly as the UN serves
them; all processing is done by Data Processing/comtrade.py.

The files come from the UN Comtrade Bulk API (premium; available through
Penn). It works in two steps:

  1. Catalogue: GET /bulk/v1/get/C/A/H4?period=2014,...,2019
     lists one compressed file per reporter and year.
  2. Files:     GET each catalogue entry's fileUrl, which is
     /bulk/v1/file/{reporterCode}/{rowKey}.

The "Plus" format is used, not "Classic". Most countries reported in HS 2017
from 2017 onwards, so their HS 2012 data exists only as Comtrade's
conversion, and those converted files are published only in Plus: on
2026-11-11 the Classic catalogue had 60, 36 and 23 files for 2017-2019
against 168, 169 and 166 in Plus (identical counts for 2014-2016).

Where the output goes (paths set in config.py):
  COMTRADE_DATA_DIR/<year>/comtrade_H4_<year>_<reporter>_plus.txt.gz
      the data files, about 14 GB (default ~/Downloads/Comtrade_raw;
      kept out of the repository and out of iCloud)
  Data/Raw/Comtrade/catalogue.csv
      every file available at the time of the run, with publication dates
  Data/Raw/Comtrade/download_log.csv
      every file downloaded: when, its publication date, size and SHA-256
Comtrade revises data, so the download date matters for replication; the
log identifies exactly which version of each file was used.

Each file is written to a .part file first, checked to be a complete gzip
file, and only then renamed, so an interrupted or truncated download never
looks complete. Failed requests are retried; a rerun skips files already on
disk, so the download can be resumed at any time.

The subscription key is read from the environment variable
COMTRADE_API_KEY and is never written to disk or printed. It is sent only
to comtradeapi.un.org. Set it once in ~/.zshenv:

    export COMTRADE_API_KEY=your_key

Usage (from the Python folder):

    python comtrade_download.py --catalogue-only     # list files, no download
    python comtrade_download.py --reporters 36 --years 2017   # one test file
    python comtrade_download.py                      # everything (resumable)
"""

import argparse
import gzip
import hashlib
import os
import sys
import time
from datetime import datetime, timezone
from urllib.parse import urlparse

import pandas as pd
import requests

from config import COMTRADE_DATA_DIR, COMTRADE_RAW_DIR

BASE = "https://comtradeapi.un.org/bulk/v1"
API_HOST = "comtradeapi.un.org"
YEARS = [2014, 2015, 2016, 2017, 2018, 2019]
CLASSIFICATION = "H4"          # HS 2012
MAX_RETRIES = 5


def api_key():
    key = os.environ.get("COMTRADE_API_KEY", "").strip()
    if not key:
        sys.exit("COMTRADE_API_KEY is not set. Add\n"
                 "    export COMTRADE_API_KEY=your_key\n"
                 "to ~/.zshenv, open a new terminal, and run again.")
    return key


def check_url(url):
    """Only ever send the key to the UN Comtrade API over HTTPS."""
    u = urlparse(url)
    if u.scheme != "https" or u.hostname != API_HOST:
        sys.exit(f"Refusing to request {url}: not https://{API_HOST}.")


def backoff(attempt, retry_after=None):
    """Seconds to wait before the next attempt."""
    try:
        return int(retry_after)
    except (TypeError, ValueError):   # absent, or an HTTP date
        return 2 ** attempt * 5


def get(session, url, params=None, stream=False):
    """GET with retries on rate limits, server errors and network errors."""
    check_url(url)
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = session.get(url, params=params, stream=stream, timeout=120)
        except (requests.ConnectionError, requests.Timeout) as e:
            wait = backoff(attempt)
            print(f"    network error ({type(e).__name__}), waiting {wait}s "
                  f"(attempt {attempt}/{MAX_RETRIES})")
            time.sleep(wait)
            continue
        if r.status_code == 200:
            return r
        if r.status_code == 401:
            sys.exit("401: the subscription key was rejected.")
        if r.status_code == 403:
            sys.exit("403: access denied. Bulk files need a premium "
                     "subscription; check that this key belongs to the "
                     "Penn premium access.")
        if r.status_code in (429, 500, 502, 503, 504):
            wait = backoff(attempt, r.headers.get("Retry-After"))
            print(f"    {r.status_code}, waiting {wait}s "
                  f"(attempt {attempt}/{MAX_RETRIES})")
            time.sleep(wait)
            continue
        r.raise_for_status()
    sys.exit(f"Giving up on {url} after {MAX_RETRIES} attempts.")


def fetch_catalogue(session, years, reporters):
    params = {"period": ",".join(map(str, years))}
    if reporters:
        params["reporterCode"] = ",".join(map(str, reporters))
    r = get(session, f"{BASE}/get/C/A/{CLASSIFICATION}", params=params)
    body = r.json()
    if body.get("error"):
        sys.exit(f"Catalogue error: {body['error']}")
    cat = pd.DataFrame(body.get("data", []))
    if cat.empty:
        sys.exit("The catalogue is empty for these years and reporters.")
    keep = ["reporterCode", "period", "classificationCode", "fileSize",
            "publicationDate", "isOriginalClassification", "rowKey",
            "fileUrl"]
    cat = cat[[c for c in keep if c in cat.columns]]
    return cat.sort_values(["period", "reporterCode"]).reset_index(drop=True)


def size_in_mb(text):
    """'12.34 MB', '1,018.64 KB' or '850 B' -> megabytes."""
    value, unit = str(text).split()
    factor = {"B": 1 / 1024 ** 2, "KB": 1 / 1024, "MB": 1, "GB": 1024}
    return float(value.replace(",", "")) * factor[unit.upper()]


def target_path(row):
    return (COMTRADE_DATA_DIR / str(row.period)
            / f"comtrade_{CLASSIFICATION}_{row.period}_{row.reporterCode}"
              f"_plus.txt.gz")


def is_complete_gzip(path):
    """Read the whole file through gzip; False if it is cut short or corrupt."""
    try:
        with gzip.open(path, "rb") as f:
            while f.read(1 << 24):
                pass
        return True
    except (OSError, EOFError):
        return False


def download(session, row):
    """Download one file to a .part file, check it, then rename it.

    Retries if the connection breaks during the transfer or the file is not
    a complete gzip file.
    """
    path = target_path(row)
    path.parent.mkdir(parents=True, exist_ok=True)
    part = path.with_suffix(path.suffix + ".part")
    for attempt in range(1, MAX_RETRIES + 1):
        sha = hashlib.sha256()
        n = 0
        try:
            with get(session, row.fileUrl, stream=True) as r, \
                    open(part, "wb") as f:
                for chunk in r.iter_content(chunk_size=1 << 20):
                    f.write(chunk)
                    sha.update(chunk)
                    n += len(chunk)
        except requests.RequestException as e:
            problem = f"transfer interrupted ({type(e).__name__})"
        else:
            if is_complete_gzip(part):
                part.rename(path)
                return path, n, sha.hexdigest()
            problem = "incomplete gzip file"
        part.unlink(missing_ok=True)
        wait = backoff(attempt)
        print(f"    {problem}, waiting {wait}s "
              f"(attempt {attempt}/{MAX_RETRIES})")
        time.sleep(wait)
    sys.exit(f"Giving up on {path.name} after {MAX_RETRIES} attempts.")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--years", type=int, nargs="+", default=YEARS)
    p.add_argument("--reporters", type=int, nargs="+",
                   help="Comtrade reporter codes (default: all)")
    p.add_argument("--catalogue-only", action="store_true",
                   help="list the files and their total size, then stop")
    args = p.parse_args()

    session = requests.Session()
    session.headers["Ocp-Apim-Subscription-Key"] = api_key()

    COMTRADE_RAW_DIR.mkdir(parents=True, exist_ok=True)
    cat = fetch_catalogue(session, args.years, args.reporters)
    accessed = datetime.now(timezone.utc).isoformat(timespec="seconds")
    cat["catalogue_accessed_utc"] = accessed
    # A filtered (test) run must not overwrite the full catalogue.
    filtered = args.reporters or sorted(args.years) != YEARS
    cat_path = COMTRADE_RAW_DIR / ("catalogue_subset.csv" if filtered
                                   else "catalogue.csv")
    cat.drop(columns=["fileUrl"]).to_csv(cat_path, index=False)

    total = sum(size_in_mb(s) for s in cat["fileSize"])
    print(f"Catalogue: {len(cat)} files, {cat['reporterCode'].nunique()} "
          f"reporters, about {total / 1024:.1f} GB compressed.")
    if "isOriginalClassification" in cat.columns:
        by_year = (cat.groupby(["period", "isOriginalClassification"]).size()
                   .unstack(fill_value=0)
                   .rename(columns={True: "reported in HS 2012",
                                    False: "converted to HS 2012"}))
        print(by_year.to_string())
    print(f"Saved to {cat_path}")
    if args.catalogue_only:
        return

    print(f"Downloading to {COMTRADE_DATA_DIR}")
    COMTRADE_DATA_DIR.mkdir(parents=True, exist_ok=True)
    log_path = COMTRADE_RAW_DIR / "download_log.csv"
    done = 0
    for i, row in enumerate(cat.itertuples(index=False), start=1):
        path = target_path(row)
        if path.exists() and path.stat().st_size > 0:
            continue                       # already downloaded: resumable
        path_out, n, digest = download(session, row)
        entry = pd.DataFrame([{
            "reporterCode": row.reporterCode, "period": row.period,
            "publicationDate": row.publicationDate,
            "file": path_out.relative_to(COMTRADE_DATA_DIR).as_posix(),
            "bytes": n, "sha256": digest,
            "downloaded_utc": datetime.now(timezone.utc)
                              .isoformat(timespec="seconds")}])
        entry.to_csv(log_path, mode="a", index=False,
                     header=not log_path.exists())
        done += 1
        print(f"[{i}/{len(cat)}] {row.period} reporter {row.reporterCode}: "
              f"{n / 1e6:.1f} MB")
        time.sleep(0.5)                    # stay well inside rate limits

    print(f"\nDownloaded {done} new files; "
          f"{len(cat) - done} were already on disk.")


if __name__ == "__main__":
    main()

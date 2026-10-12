# Clear-Files

Common module for clearing files from the current folder.

```powershell
$cfg = [pscustomobject]@{ keepdays = 2; purgefiles = '*.log,*.csv' }
Clear-Files $cfg
```

Without an option, cleanup uses `LastWriteTime < (Get-Date).AddDays(-keepdays)`.
Existing patterns and output are unchanged. A fresh checkout can reset that filesystem age.

## filename days (opt-in)

```powershell
Clear-Files $cfg -FilenameDateFormat yyyyMMdd
# or, for separated prefixes:
Clear-Files $cfg -FilenameDateFormat yyyy-MM-dd
```

The format enables the mode. Only these two fixed-width day formats are supported.
The first eight or ten filename characters supply the date. For example,
`20261012.log`, `20261012153000-report.csv` and `2026-10-12-report.csv`.
Suffixes, including time digits, do not affect the day. The `purgefiles` patterns still select files.

Files expire strictly before local today's date minus `keepdays`. The cutoff day stays.
On October 12 with `keepdays = 2`, October 9 expires; October 10, 11 and 12 stay.
This is calendar-day retention, not a rolling 48-hour cutoff. Date prefixes have no timezone;
the caller must use a consistent calendar convention. Default mode is not changed.

Missing, short, malformed, invalid and future dates stay untouched. There is no fallback to
filesystem age. Directories are excluded in filename mode. Unsupported formats and missing,
blank, negative or nonnumeric `keepdays` fail before deletion. Choose prefixes that represent the
artifact age you intend to retain, not an unrelated source-event date.

Run the disposable-directory regression checks with `pwsh -NoProfile -File tests/retention.ps1`.
No existing caller needs this option. Add it only where the filename contract fits.

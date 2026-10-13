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

The format enables the mode. The fixed-width day formats are `yyyyMMdd`, `yyyy-MM-dd` and `yyMMdd`.
Short years always mean `2000 + yy`: `000229` is February 29, 2000, and `990101` is January 1, 2099.
There is no culture-dependent century pivot. Use four-digit years for dates outside 2000-2099.
Without a pattern, the date stays at the start of the filename.
The first six, eight or ten filename characters supply the date. For example,
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

## dates elsewhere (opt-in)

```powershell
# invoice-20261013153000.csv
Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '^invoice-(?<date>[0-9]{8})[0-9]{6}\.csv$'
# Report2026-10-13.xlsx (purgefiles must include *.xlsx)
Clear-Files $cfg -FilenameDateFormat yyyy-MM-dd -FilenameDatePattern '^Report(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})\.xlsx$'
```

The pattern is a regex over the filename only, not its path. Name the day capture `date`.
It must match exactly once and capture `date` exactly once. No match, multiple matches,
repeated captures, missing dates and invalid dates keep the file. The capture must have the
format's exact width. A pattern does not change `purgefiles`, the cutoff, or the no-fallback rule.

A pattern requires a format. Invalid regex, an absent named `date` group, or an empty pattern
fails before deletion. Regex matching has a one-second timeout per file. All filenames are
selected before any removal, so a matching timeout also refuses without deleting files.
Choose a pattern that identifies the artifact's own date, not another date in its name.

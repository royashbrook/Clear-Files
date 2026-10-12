function Clear-Files {
    param($cfg, [ValidateSet('yyyyMMdd', 'yyyy-MM-dd')][string]$FilenameDateFormat)

    $pf = $cfg.purgefiles -split ","
    $pd = (Get-Date).AddDays(-[int]($cfg.keepdays))
    if($FilenameDateFormat){
        if([string]::IsNullOrWhiteSpace([string]$cfg.keepdays) -or [int]$cfg.keepdays -lt 0){
            throw 'Filename-date retention requires nonnegative keepdays.'
        }
        $pd = $pd.Date
        $ff = @(Get-ChildItem .\* -Include $pf | Where-Object {
            $date = [datetime]::MinValue
            !$_.PSIsContainer -and $_.Name.Length -ge $FilenameDateFormat.Length -and
                [datetime]::TryParseExact($_.Name.Substring(0, $FilenameDateFormat.Length),
                    $FilenameDateFormat, [cultureinfo]::InvariantCulture,
                    [Globalization.DateTimeStyles]::None, [ref]$date) -and $date -lt $pd
        })
    }else{
        $ff = Get-ChildItem .\* -Include $pf | Where-Object LastWriteTime -lt $pd
    }
    if(!$pf -or $ff.Length -eq 0){
        "Nothing to cleanup"
        return
    }
    foreach ($f in $ff) {
        "Remove-Item {0}" -f $f
        Remove-Item $f
    }
}
Export-ModuleMember -Function Clear-Files

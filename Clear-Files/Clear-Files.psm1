function Clear-Files {
    param(
        $cfg,
        [ValidateSet('yyyyMMdd', 'yyyy-MM-dd', 'yyMMdd')][string]$FilenameDateFormat,
        [ValidateNotNullOrEmpty()][string]$FilenameDatePattern
    )

    $pattern = $null
    if($PSBoundParameters.ContainsKey('FilenameDatePattern')){
        if(!$FilenameDateFormat){ throw 'FilenameDatePattern requires FilenameDateFormat.' }
        $pattern = [regex]::new($FilenameDatePattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant,
            [timespan]::FromSeconds(1))
        if('date' -cnotin $pattern.GetGroupNames()){ throw 'FilenameDatePattern requires a named date capture.' }
    }
    $pf = $cfg.purgefiles -split ","
    $pd = (Get-Date).AddDays(-[int]($cfg.keepdays))
    if($FilenameDateFormat){
        if([string]::IsNullOrWhiteSpace([string]$cfg.keepdays) -or [int]$cfg.keepdays -lt 0){
            throw 'Filename-date retention requires nonnegative keepdays.'
        }
        $pd = $pd.Date
        $format = if($FilenameDateFormat -eq 'yyMMdd'){ 'yyyyMMdd' }else{ $FilenameDateFormat }
        $ff = @(Get-ChildItem .\* -Include $pf | Where-Object {
            if($_.PSIsContainer){ return $false }
            if($pattern){
                $hits = $pattern.Matches($_.Name)
                # PowerShell hides property-getter exceptions on this lazy collection.
                if($hits.get_Count() -ne 1 -or !$hits[0].Groups['date'].Success -or
                    $hits[0].Groups['date'].Captures.Count -ne 1){ return $false }
                $text = $hits[0].Groups['date'].Value
            }else{
                if($_.Name.Length -lt $FilenameDateFormat.Length){ return $false }
                $text = $_.Name.Substring(0, $FilenameDateFormat.Length)
            }
            if($text.Length -ne $FilenameDateFormat.Length){ return $false }
            if($FilenameDateFormat -eq 'yyMMdd'){ $text = '20' + $text }
            $date = [datetime]::MinValue
            [datetime]::TryParseExact($text, $format, [cultureinfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::None, [ref]$date) -and $date -lt $pd
        } -ErrorAction Stop)
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

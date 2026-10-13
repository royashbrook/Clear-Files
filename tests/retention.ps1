$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../Clear-Files/Clear-Files.psm1" -Force
$root = Join-Path ([IO.Path]::GetTempPath()) ('clear-files-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory $root
$checks = 0
function Assert($ok, $name){
    if(!$ok){ throw $name }
    $script:checks++
}
function File($name, $age = 0){
    Set-Content $name 'synthetic'
    (Get-Item $name).LastWriteTime = (Get-Date).AddDays(-$age)
}
Push-Location $root
try {
    $cfg = [pscustomobject]@{ keepdays = 2; purgefiles = '*.log' }
    File old.log 3
    File fresh.log
    $expected = 'Remove-Item {0}' -f (Get-Item old.log)
    $output = @(Clear-Files $cfg)
    Assert (!(Test-Path old.log) -and (Test-Path fresh.log)) 'legacy file age'
    Assert ($output.Count -eq 1 -and $output[0] -eq $expected) 'legacy output'
    Assert ((Clear-Files $cfg) -eq 'Nothing to cleanup') 'idle output'
    Remove-Item fresh.log

    $today = (Get-Date).Date
    foreach($format in 'yyyyMMdd','yyyy-MM-dd'){
        $old = $today.AddDays(-3).ToString($format) + '-old.log'
        $edge = $today.AddDays(-2).ToString($format) + '-edge.log'
        $future = $today.AddDays(1).ToString($format) + '-future.log'
        File $old
        File $edge 90
        File $future 90
        File no-date.log 90
        File '20010229-invalid.log' 90
        File '2001-02-29-invalid.log' 90
        File ($today.AddDays(-3).ToString($format) + '.csv') 90
        $null = Clear-Files $cfg -FilenameDateFormat $format
        Assert (!(Test-Path $old)) "$format old prefix, fresh mtime"
        Assert (Test-Path $edge) "$format cutoff day retained"
        Assert (Test-Path $future) "$format future retained"
        Assert (Test-Path no-date.log) "$format no mtime fallback"
        Assert ((Test-Path '20010229-invalid.log') -and (Test-Path '2001-02-29-invalid.log')) "$format invalid leap retained"
        Assert (Test-Path ($today.AddDays(-3).ToString($format) + '.csv')) "$format glob exclusion"
        Remove-Item ./*
    }

    File 20000229-leap.log
    File 20000101153000-time.log
    File x20000101.log 90
    File 2000.log 90
    $null = Clear-Files $cfg -FilenameDateFormat yyyyMMdd
    Assert (!(Test-Path 20000229-leap.log)) 'valid leap expires'
    Assert (!(Test-Path 20000101153000-time.log)) 'time suffix ignored'
    Assert ((Test-Path x20000101.log) -and (Test-Path 2000.log)) 'prefix only and short retained'

    $null = New-Item -ItemType File 20000101-empty.log
    $null = Clear-Files ([pscustomobject]@{keepdays=2; purgefiles='20000101-empty.log'}) -FilenameDateFormat yyyyMMdd
    Assert (!(Test-Path 20000101-empty.log)) 'single zero-byte expired file removed'

    $zero = [pscustomobject]@{ keepdays=0; purgefiles='*.log' }
    $current = $today.ToString('yyyyMMdd') + '-today.log'
    File $current 90
    $null = New-Item -ItemType Directory 20000101-dir.log
    $null = Clear-Files $zero -FilenameDateFormat yyyyMMdd
    Assert (Test-Path $current) 'zero days retains today'
    Assert (Test-Path 20000101-dir.log) 'filename mode excludes directories'

    foreach($case in @(
        @{format='yyyyMM'; days=2},
        @{format='yyyyMMdd'; days=-1},
        @{format='yyyyMMdd'; days=$null},
        @{format='yyyyMMdd'; days=''},
        @{format='yyyyMMdd'; days=' '},
        @{format='yyyyMMdd'; days='invalid'}
    )){
        File 20000101.log
        $bad = [pscustomobject]@{ keepdays=$case.days; purgefiles='*.log' }
        $refused = $false
        try { $null = Clear-Files $bad -FilenameDateFormat $case.format }
        catch { $refused = $true }
        Assert ($refused -and (Test-Path 20000101.log)) 'invalid config refuses before deletion'
    }

    Remove-Item ./* -Recurse
    foreach($format in 'yyyyMMdd','yyyy-MM-dd'){
        $day = $today.AddDays(-3).ToString($format)
        $old = 'Report' + $day + '153000.log'
        $dashed = 'invoice-' + $day + '.log'
        $edge = 'Report' + $today.AddDays(-2).ToString($format) + '.log'
        $future = 'Report' + $today.AddDays(1).ToString($format) + '.log'
        $digits = if($format -eq 'yyyyMMdd'){ '[0-9]{8}' }else{ '[0-9]{4}-[0-9]{2}-[0-9]{2}' }
        $pattern = '(?<date>' + $digits + ')'
        File $old
        File $dashed
        File $edge 90
        File $future 90
        File no-date.log 90
        File ($dashed -replace '\.log$', '.csv') 90
        $null = Clear-Files $cfg -FilenameDateFormat $format -FilenameDatePattern $pattern
        Assert (!(Test-Path $old)) "$format glued prefix and timestamp suffix"
        Assert (!(Test-Path $dashed)) "$format dashed prefix"
        Assert (Test-Path $edge) "$format pattern cutoff day retained"
        Assert (Test-Path $future) "$format pattern future retained"
        Assert (Test-Path no-date.log) "$format pattern no mtime fallback"
        Assert (Test-Path ($dashed -replace '\.log$', '.csv')) "$format pattern glob exclusion"
        Remove-Item ./*
    }

    File invoice-20000101.log
    File invoice-20010229.log 90
    File Report20000101.log 90
    File invoice-20000101-copy-20000102.log 90
    $null = New-Item -ItemType Directory invoice-20000102-dir.log
    $null = Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '^invoice-(?<date>[0-9]{8})\.log$'
    Assert (!(Test-Path invoice-20000101.log)) 'anchored caller pattern deletes only matching file'
    Assert (Test-Path invoice-20010229.log) 'pattern invalid leap retained'
    Assert (Test-Path Report20000101.log) 'caller prefix mismatch retained'
    $null = Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '(?<date>[0-9]{8})'
    Assert (Test-Path invoice-20000101-copy-20000102.log) 'multiple matches retained'
    Assert (Test-Path invoice-20000102-dir.log) 'pattern directories excluded'

    File 20000101-20000102.log 90
    $null = Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '^(?:(?<date>[0-9]{8})-?)+\.log$'
    Assert (Test-Path 20000101-20000102.log) 'repeated named captures retained'
    File absent.log 90
    $null = Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '^(?<date>[0-9]{8})?absent\.log$'
    Assert (Test-Path absent.log) 'optional unmatched date capture retained'
    File short-200001.log 90
    $null = Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '^short-(?<date>[0-9]{6})\.log$'
    Assert (Test-Path short-200001.log) 'capture width must match format'
    $null = New-Item -ItemType File empty-20000101.log
    $null = Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '^empty-(?<date>[0-9]{8})\.log$'
    Assert (!(Test-Path empty-20000101.log)) 'pattern singleton zero-byte file removed'
    Remove-Item ./* -Recurse

    $culture = [cultureinfo]::CurrentCulture
    try {
        foreach($name in 'en-US','th-TH'){
            [cultureinfo]::CurrentCulture = [cultureinfo]::GetCultureInfo($name)
            File 000229-leap.log
            File 990101-future.log 90
            File 010229-invalid.log 90
            $null = Clear-Files $cfg -FilenameDateFormat yyMMdd
            Assert (!(Test-Path 000229-leap.log)) "$name short year means 2000"
            Assert (Test-Path 990101-future.log) "$name short year means 2099, not 1999"
            Assert (Test-Path 010229-invalid.log) "$name short year invalid leap retained"
            Remove-Item ./*
        }
    }finally { [cultureinfo]::CurrentCulture = $culture }
    File invoice-000229153000.log
    File invoice-990101.log 90
    $null = Clear-Files $cfg -FilenameDateFormat yyMMdd -FilenameDatePattern '^invoice-(?<date>[0-9]{6})'
    Assert (!(Test-Path invoice-000229153000.log)) 'short year pattern with timestamp suffix'
    Assert (Test-Path invoice-990101.log) 'short year pattern future retained'
    Remove-Item ./*

    foreach($options in @(
        @{FilenameDatePattern='(?<date>[0-9]{8})'},
        @{FilenameDateFormat='yyyyMMdd'; FilenameDatePattern='('},
        @{FilenameDateFormat='yyyyMMdd'; FilenameDatePattern='[0-9]{8}'},
        @{FilenameDateFormat='yyyyMMdd'; FilenameDatePattern='(?<day>[0-9]{8})'},
        @{FilenameDateFormat='yyyyMMdd'; FilenameDatePattern='(?<Date>[0-9]{8})'},
        @{FilenameDateFormat='yyyyMMdd'; FilenameDatePattern='(?<DATE>[0-9]{8})'},
        @{FilenameDateFormat='yyyyMMdd'; FilenameDatePattern=''},
        @{FilenameDateFormat='yyyyMMdd'; FilenameDatePattern=$null},
        @{FilenameDateFormat='yyyyMM'; FilenameDatePattern='(?<date>[0-9]{8})'}
    )){
        File 20000101.log 90
        $refused = $false
        try { $null = Clear-Files $cfg @options }
        catch { $refused = $true }
        Assert ($refused -and (Test-Path 20000101.log)) 'invalid pattern config refuses before deletion'
    }

    Remove-Item ./*
    File A-20000101.log
    $slow = 'Z-20000101' + ('a' * 220) + '!.log'
    File $slow
    $refused = $false
    try {
        $null = & {
            $ErrorActionPreference = 'Continue'
            Clear-Files $cfg -FilenameDateFormat yyyyMMdd -FilenameDatePattern '(?<date>[0-9]{8})(a+)+$|(?<date>[0-9]{8})\.log$'
        }
    }catch { $refused = $_.Exception.ToString() -match 'RegexMatchTimeoutException' }
    Assert ($refused -and (Test-Path A-20000101.log) -and (Test-Path $slow)) 'regex timeout refuses before any deletion even with caller Continue'
    "$checks retention checks passed"
}finally{
    Pop-Location
    Remove-Item $root -Recurse -Force
}

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
        @{format='yyyyMMdd'; days='invalid'}
    )){
        File 20000101.log
        $bad = [pscustomobject]@{ keepdays=$case.days; purgefiles='*.log' }
        $refused = $false
        try { $null = Clear-Files $bad -FilenameDateFormat $case.format }
        catch { $refused = $true }
        Assert ($refused -and (Test-Path 20000101.log)) 'invalid config refuses before deletion'
    }
    "$checks retention checks passed"
}finally{
    Pop-Location
    Remove-Item $root -Recurse -Force
}

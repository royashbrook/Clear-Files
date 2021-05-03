function Clear-Files($cfg){
    $pf = $cfg.purgefiles -split ","
    $pd = (Get-Date).AddDays(-[int]($cfg.keepdays))
    $ff = Get-ChildItem .\* -Include $pf | Where-Object LastWriteTime -lt $pd
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
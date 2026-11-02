# BBR1 save editor
param([int]$Coins = -1, [int]$Gems = -1)

if ($Coins -lt 0 -and $Gems -lt 0) { Write-Host "Usage: .\bbr_edit.ps1 -Coins 999999 -Gems 99999"; exit }

$pkg = Get-AppxPackage -Name "VectorUnit.BeachBuggyRacing" -ErrorAction SilentlyContinue
if (-not $pkg) { Write-Host "BBR1 not installed."; exit }
$base = Join-Path $env:LOCALAPPDATA "Packages\$($pkg.PackageFamilyName)\LocalState\"

$proc = Get-Process -Name "PurpleWindowsStore" -ErrorAction SilentlyContinue
if ($proc) { Write-Host "Close BBR1 first."; exit }


function Patch-File([string]$path) {
    if (-not (Test-Path $path)) { Write-Host "  skip (not found): $path"; return }
    $data = [System.IO.File]::ReadAllBytes($path)

    # find all int32 Earned and Spent instances
    function Get-IntFields2([string]$name) {
        $nb = [System.Text.Encoding]::ASCII.GetBytes($name)
        $list = [System.Collections.Generic.List[object]]::new()
        for ($i = 0; $i -le ($data.Length - $nb.Length - 8); $i++) {
            $m = $true
            for ($j = 0; $j -lt $nb.Length; $j++) { if ($data[$i+$j] -ne $nb[$j]) { $m = $false; break } }
            if ($m) {
                $to = $i + $nb.Length; $vo = $to + 4
                $t = ([int]$data[$to] -shl 24) -bor ([int]$data[$to+1] -shl 16) -bor ([int]$data[$to+2] -shl 8) -bor [int]$data[$to+3]
                $v = ([int]$data[$vo] -shl 24) -bor ([int]$data[$vo+1] -shl 16) -bor ([int]$data[$vo+2] -shl 8) -bor [int]$data[$vo+3]
                if ($t -eq 1) { $list.Add([PSCustomObject]@{Offset=[int]$vo; Val=[int]$v}) }
            }
        }
        return $list
    }

    $earned = Get-IntFields2 "Earned"
    $spent  = Get-IntFields2 "Spent"

    if ($earned.Count -lt 2 -or $spent.Count -lt 2) {
        Write-Host "  skip: couldn't find fields in $path"
        return
    }

    Write-Host ("  {0}: gems balance={1}  coins balance={2}" -f (Split-Path $path -Leaf), ($earned[0].Val - $spent[0].Val), ($earned[1].Val - $spent[1].Val))

    function Set-Int32BE([int]$off, [int]$v) {
        $data[$off]   = [byte](($v -shr 24) -band 0xFF)
        $data[$off+1] = [byte](($v -shr 16) -band 0xFF)
        $data[$off+2] = [byte](($v -shr 8)  -band 0xFF)
        $data[$off+3] = [byte]($v            -band 0xFF)
    }

    if ($Gems -ge 0) {
        $ne = $Gems + $spent[0].Val
        Set-Int32BE $earned[0].Offset $ne
    }
    if ($Coins -ge 0) {
        $ne = $Coins + $spent[1].Val
        Set-Int32BE $earned[1].Offset $ne
    }

    # FNV-1a 32-bit over bytes[16..end], store LE at bytes 12-15
    $h = 0x811C9DC5L
    for ($i = 16; $i -lt $data.Length; $i++) {
        $h = ($h -bxor [long]$data[$i]) * 0x01000193L -band 0xFFFFFFFFL
    }
    $data[12] = [byte]($h          -band 0xFFL)
    $data[13] = [byte](($h -shr 8)  -band 0xFFL)
    $data[14] = [byte](($h -shr 16) -band 0xFFL)
    $data[15] = [byte](($h -shr 24) -band 0xFFL)

    [System.IO.File]::WriteAllBytes($path, $data)

    # verify
    $d2 = [System.IO.File]::ReadAllBytes($path)
    $v0 = ([int]$d2[$earned[0].Offset] -shl 24) -bor ([int]$d2[$earned[0].Offset+1] -shl 16) -bor ([int]$d2[$earned[0].Offset+2] -shl 8) -bor [int]$d2[$earned[0].Offset+3]
    $v1 = ([int]$d2[$earned[1].Offset] -shl 24) -bor ([int]$d2[$earned[1].Offset+1] -shl 16) -bor ([int]$d2[$earned[1].Offset+2] -shl 8) -bor [int]$d2[$earned[1].Offset+3]
    $s0 = ([int]$d2[$spent[0].Offset]  -shl 24) -bor ([int]$d2[$spent[0].Offset+1]  -shl 16) -bor ([int]$d2[$spent[0].Offset+2]  -shl 8) -bor [int]$d2[$spent[0].Offset+3]
    $s1 = ([int]$d2[$spent[1].Offset]  -shl 24) -bor ([int]$d2[$spent[1].Offset+1]  -shl 16) -bor ([int]$d2[$spent[1].Offset+2]  -shl 8) -bor [int]$d2[$spent[1].Offset+3]
    Write-Host ("  verified: gems={0}  coins={1}" -f ($v0 - $s0), ($v1 - $s1))
}

Copy-Item ($base + "profile")     ($base + "profile.orig_bak")     -Force
Copy-Item ($base + "profile.bak") ($base + "profile.bak.orig_bak") -Force

Write-Host "Patching all save files..."
Patch-File ($base + "profile")
Patch-File ($base + "profile.bak")
Patch-File ($base + "profileback")

Write-Host "`nDone. Launch BBR1."

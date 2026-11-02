Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── locate install ────────────────────────────────────────────────────────────
$pkg = Get-AppxPackage -Name "VectorUnit.BeachBuggyRacing" -ErrorAction SilentlyContinue
if (-not $pkg) {
    [System.Windows.Forms.MessageBox]::Show(
        "Beach Buggy Racing 1 is not installed on this machine.",
        "BBR1 Trainer", "OK", "Error") | Out-Null
    exit
}
$pkgFamily = $pkg.PackageFamilyName
$savePath  = Join-Path $env:LOCALAPPDATA "Packages\$pkgFamily\LocalState\profile"
if (-not (Test-Path $savePath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Save file not found at:`n$savePath`n`nLaunch BBR1 at least once first.",
        "BBR1 Trainer", "OK", "Error") | Out-Null
    exit
}

# ── save parsing ──────────────────────────────────────────────────────────────
function Get-Fields([byte[]]$data, [string]$name) {
    $nb = [System.Text.Encoding]::ASCII.GetBytes($name); $list = @()
    for ($i = 0; $i -le $data.Length - $nb.Length - 8; $i++) {
        $m = $true
        for ($j = 0; $j -lt $nb.Length; $j++) { if ($data[$i+$j] -ne $nb[$j]) { $m = $false; break } }
        if ($m) {
            $to = $i + $nb.Length; $vo = $to + 4
            $t = ([int]$data[$to] -shl 24) -bor ([int]$data[$to+1] -shl 16) -bor ([int]$data[$to+2] -shl 8) -bor [int]$data[$to+3]
            $v = ([int]$data[$vo] -shl 24) -bor ([int]$data[$vo+1] -shl 16) -bor ([int]$data[$vo+2] -shl 8) -bor [int]$data[$vo+3]
            if ($t -eq 1) { $list += [PSCustomObject]@{Off=[int]$vo; Val=[int]$v} }
        }
    }
    return $list
}

function Read-Balance {
    $data = [System.IO.File]::ReadAllBytes($savePath)
    $e = Get-Fields $data "Earned"; $s = Get-Fields $data "Spent"
    if ($e.Count -lt 2 -or $s.Count -lt 2) { throw "Save format not recognized." }
    return @{
        Gems        = ($e[0].Val - $s[0].Val)
        Coins       = ($e[1].Val - $s[1].Val)
        EarnedGems  = $e[0].Val;  SpentGems  = $s[0].Val
        EarnedCoins = $e[1].Val;  SpentCoins = $s[1].Val
    }
}

function Write-Patch([int]$gems, [int]$coins) {
    $data   = [System.IO.File]::ReadAllBytes($savePath)
    $earned = Get-Fields $data "Earned"
    $spent  = Get-Fields $data "Spent"
    $sG = $spent[0].Val; $sC = $spent[1].Val

    function Set-BE([int]$o, [int]$v) {
        $data[$o]   = [byte](($v -shr 24) -band 0xFF)
        $data[$o+1] = [byte](($v -shr 16) -band 0xFF)
        $data[$o+2] = [byte](($v -shr 8)  -band 0xFF)
        $data[$o+3] = [byte]($v            -band 0xFF)
    }
    if ($gems  -ge 0) { Set-BE $earned[0].Off ($gems  + $sG) }
    if ($coins -ge 0) { Set-BE $earned[1].Off ($coins + $sC) }

    # FNV-1a 32-bit checksum over bytes[16..end], stored LE at bytes 12-15
    $h = 0x811C9DC5L
    for ($i = 16; $i -lt $data.Length; $i++) {
        $h = ($h -bxor [long]$data[$i]) * 0x01000193L -band 0xFFFFFFFFL
    }
    $data[12] = [byte]($h           -band 0xFFL)
    $data[13] = [byte](($h -shr  8) -band 0xFFL)
    $data[14] = [byte](($h -shr 16) -band 0xFFL)
    $data[15] = [byte](($h -shr 24) -band 0xFFL)

    Copy-Item $savePath "$savePath.bak_trainer" -Force
    [System.IO.File]::WriteAllBytes($savePath, $data)
    $bak = "$savePath.bak"
    if (Test-Path $bak) { [System.IO.File]::WriteAllBytes($bak, $data) }
}

function Restart-Game {
    $proc = Get-Process -Name "PurpleWindowsStore" -ErrorAction SilentlyContinue
    if ($proc) { $proc | Stop-Process -Force; Start-Sleep -Milliseconds 800 }
    Start-Process "explorer.exe" "shell:AppsFolder\$pkgFamily!App"
}

# ── GUI ───────────────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text            = "BBR1 Trainer"
$form.Size            = New-Object System.Drawing.Size(320, 310)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::FromArgb(28, 28, 28)
$form.ForeColor       = [System.Drawing.Color]::White
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 10)

function New-Label($t, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $t; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.AutoSize = $true; $l.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
    $form.Controls.Add($l); $l
}
function New-Box($x, $y) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size(140, 26)
    $t.BackColor = [System.Drawing.Color]::FromArgb(48, 48, 48)
    $t.ForeColor = [System.Drawing.Color]::White
    $t.BorderStyle = "FixedSingle"
    $form.Controls.Add($t); $t
}
function New-Btn($t, $x, $y, $w, $c) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $t; $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, 32)
    $b.FlatStyle = "Flat"; $b.BackColor = $c; $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatAppearance.BorderSize = 0; $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $form.Controls.Add($b); $b
}

New-Label "Beach Buggy Racing 1" 20 15 | Out-Null

New-Label "Coins" 20  65 | Out-Null; $boxCoins = New-Box 90  61
New-Label "Gems"  20 103 | Out-Null; $boxGems  = New-Box 90  99

$status = New-Object System.Windows.Forms.Label
$status.Location  = New-Object System.Drawing.Point(20, 148)
$status.Size      = New-Object System.Drawing.Size(270, 38)
$status.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 100)
$form.Controls.Add($status)

$btnRead         = New-Btn "Read"                 20 200 120 ([System.Drawing.Color]::FromArgb(55, 75, 95))
$btnPatch        = New-Btn "Patch File"          155 200 120 ([System.Drawing.Color]::FromArgb(35, 110, 55))
$btnPatchRestart = New-Btn "Patch + Restart Game" 20 244 255 ([System.Drawing.Color]::FromArgb(130, 60, 20))

$btnRead.Add_Click({
    try {
        $b = Read-Balance
        $boxCoins.Text = $b.Coins; $boxGems.Text = $b.Gems
        $status.Text = "Loaded."; $status.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 100)
    } catch {
        $status.Text = "Error: $_"; $status.ForeColor = [System.Drawing.Color]::FromArgb(220, 80, 80)
    }
})

$btnPatch.Add_Click({
    $c = -1; $g = -1
    if ($boxCoins.Text -match '^\d+$') { $c = [int]$boxCoins.Text }
    if ($boxGems.Text  -match '^\d+$') { $g = [int]$boxGems.Text  }
    if ($c -lt 0 -and $g -lt 0) { $status.Text = "Enter a value first."; return }
    try {
        Write-Patch $g $c
        $status.Text = "File patched. Restart BBR1 to apply."
        $status.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 100)
        $btnRead.PerformClick()
    } catch {
        $status.Text = "Error: $_"; $status.ForeColor = [System.Drawing.Color]::FromArgb(220, 80, 80)
    }
})

$btnPatchRestart.Add_Click({
    $c = -1; $g = -1
    if ($boxCoins.Text -match '^\d+$') { $c = [int]$boxCoins.Text }
    if ($boxGems.Text  -match '^\d+$') { $g = [int]$boxGems.Text  }
    if ($c -lt 0 -and $g -lt 0) { $status.Text = "Enter a value first."; return }
    try {
        Write-Patch $g $c
        $status.Text = "Patched. Restarting game..."
        $status.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 100)
        $form.Refresh()
        Restart-Game
        $btnRead.PerformClick()
    } catch {
        $status.Text = "Error: $_"; $status.ForeColor = [System.Drawing.Color]::FromArgb(220, 80, 80)
    }
})

try {
    $b = Read-Balance
    $boxCoins.Text = $b.Coins; $boxGems.Text = $b.Gems
    $status.Text = "Save loaded."
} catch {
    $status.Text = "Could not read save."
}

[void]$form.ShowDialog()

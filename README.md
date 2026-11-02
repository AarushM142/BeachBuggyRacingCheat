# Beach Buggy Racing Cheat

Coins and gems editor for **Beach Buggy Racing 1** (Microsoft Store / UWP version on Windows).

## Download

Grab `BBR1Trainer.exe` from the [Releases](../../releases/latest) page. No install needed.

## How to use

1. Launch **Beach Buggy Racing 1** at least once so the save file exists
2. Run `BBR1Trainer.exe` — Windows will ask for admin permission, click Yes
3. Your current coins and gems load automatically
4. Type in the values you want
5. Click **Patch + Restart Game** — it edits the save and relaunches BBR1 instantly

## Requirements

- Windows 10 / 11
- Beach Buggy Racing 1 installed from the Microsoft Store
- Admin rights (needed to restart the game)

## Notes

- Works on any PC, no hardcoded paths
- Creates a backup of your save at `profile.bak_trainer` before patching
- Cloud sync works in your favor — the game pushes the patched values online after loading

## Build from source

Requires [ps2exe](https://github.com/MScholtes/PS2EXE):

```powershell
Install-Module ps2exe -Scope CurrentUser -Force
ps2exe .\bbr_gui.ps1 .\BBR1Trainer.exe -noConsole -requireAdmin -title "BBR1 Trainer"
```

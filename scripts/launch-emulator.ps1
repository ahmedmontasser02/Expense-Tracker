# Launches the Android emulator and guarantees its window is visible.
# Fixes the recurring "emulator only in taskbar" issue caused by a saved
# off-screen window position (and minimized/hidden launches).
param(
    [string]$Avd = 'Pixel_6_Pro_API_36',
    [int]$X = 100,
    [int]$Y = 60
)

$ErrorActionPreference = 'SilentlyContinue'
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
$avdDir = "$env:USERPROFILE\.android\avd\$Avd.avd"

# 1. Clean stale locks from crashed sessions.
Get-ChildItem $avdDir -Filter *.lock | Remove-Item -Recurse -Force

# 2. Force a known-good on-screen window position in the saved config.
$ini = Join-Path $avdDir 'emulator-user.ini'
if (Test-Path $ini) {
    (Get-Content $ini) |
        ForEach-Object { $_ -replace '^window\.x=.*', "window.x=$X" -replace '^window\.y=.*', "window.y=$Y" } |
        Set-Content $ini
}

# 3. Launch (RAM capped so Gradle builds don't starve it of memory).
Start-Process -FilePath "$sdk\emulator\emulator.exe" `
    -ArgumentList "@$Avd", '-no-snapshot-load', '-gpu', 'swiftshader_indirect', '-memory', '2048'

# 4. Wait for the window, then restore/center it if off-screen or minimized.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class EmuWin {
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    public struct RECT { public int L, T, R, B; }
}
"@

$deadline = (Get-Date).AddSeconds(90)
$handle = [IntPtr]::Zero
while ((Get-Date) -lt $deadline -and $handle -eq [IntPtr]::Zero) {
    Start-Sleep -Seconds 2
    $proc = Get-Process | Where-Object {
        $_.MainWindowTitle -like '*Android Emulator*' -and $_.MainWindowHandle -ne 0
    } | Select-Object -First 1
    if ($proc) { $handle = $proc.MainWindowHandle }
}

if ($handle -ne [IntPtr]::Zero) {
    # The emulator may re-apply its own geometry late in startup, so verify
    # the restore sticks across a couple of checks.
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $r = New-Object EmuWin+RECT
        [EmuWin]::GetWindowRect($handle, [ref]$r) | Out-Null
        $offScreen = $r.T -lt -50 -or $r.L -lt -50 -or
            ($r.R -le 0 -and $r.B -le 0) -or
            $r.L -ge 3000 -or $r.T -ge 2000 -or
            $r.Rt -eq -25600
        if ([EmuWin]::IsIconic($handle) -or $offScreen) {
            [EmuWin]::ShowWindowAsync($handle, 9) | Out-Null          # restore
            [EmuWin]::SetWindowPos($handle, [IntPtr]::Zero, $X, $Y, 0, 0, 0x0001 -bor 0x0040) | Out-Null
            Write-Host "Window restored to ($X, $Y) (attempt $($attempt + 1))"
            Start-Sleep -Seconds 3
        } else {
            Start-Sleep -Seconds 3
            $r2 = New-Object EmuWin+RECT
            [EmuWin]::GetWindowRect($handle, [ref]$r2) | Out-Null
            if (-not [EmuWin]::IsIconic($handle) -and $r2.L -eq $r.L -and $r2.T -eq $r.T) {
                Write-Host "Window stable on-screen ($($r2.L), $($r2.T))"
                break
            }
        }
    }
} else {
    Write-Host 'Window handle not found yet - it may still be booting.'
}

# 5. Wait for adb.
$bootDeadline = (Get-Date).AddSeconds(120)
do {
    Start-Sleep -Seconds 5
    $line = & $adb devices | Select-String "$Avd|emulator-\d+\s+device"
} until ($line -or (Get-Date) -gt $bootDeadline)
& $adb devices

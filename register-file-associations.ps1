<#
.SYNOPSIS
  Registers (or removes) Windows "open with" file-type associations for the
  roc_desk standalone tool exes in this same directory, so double-clicking a
  .txt/.sql/etc file launches the matching tool with that file preloaded.

.DESCRIPTION
  Writes per-user associations under HKEY_CURRENT_USER\Software\Classes --
  no administrator privileges required, and nothing outside the current
  user's profile is touched. Each tool exe must already support being
  launched with a file path as its first argument (roc_desk-editor.exe and
  roc_desk-sql.exe do, as of roc_desk-editor v0.2.13 / roc_desk-sql v0.3.9 --
  see docs/MULTI_REPO_SPLIT_PROGRESS.md in the host roc_desk repo for the
  argv/single-instance-forwarding mechanism both tools share with the full
  roc_desk.exe host).

  Default extension -> tool mapping (edit $associations below to add more):
    .txt/.log/.md/.json/.yaml/.yml/.ini/.conf/.cfg/.xml/.csv -> roc_desk-editor.exe
    .sql                                                     -> roc_desk-sql.exe

  Run this script from the directory the exes actually live in (the
  extracted release zip, or roc_desk-releases\bundle\ for local testing) --
  it resolves tool paths relative to its own location, not relative to the
  current working directory.

  IMPORTANT WINDOWS LIMITATION (tested on Windows 11): since Windows 8,
  Explorer protects a user's existing "default app" choice for an extension
  (stored as a hash-signed `UserChoice` key) from being silently overwritten
  by any script -- this is an anti-hijacking measure, not a bug here. The
  practical effect:
    - Extensions with NO prior default on this machine (most of the list
      above, on a typical install -- .sql, .log, .yaml, .ini, .conf, .cfg...)
      switch over immediately and silently, confirmed by testing.
    - Extensions that already have a well-known default (most commonly
      .txt -> Notepad) will keep opening in that app after this script runs,
      even though the registry now points `.txt` itself at roc_desk-editor.exe
      and the exe is correctly listed in the right-click "Open with" menu.
      To finish switching one of those over, the user does ONE manual step:
      right-click a .txt file -> "Open with" -> choose "roc_desk
      (roc_desk-editor.exe)" -> check "Always use this app" -> OK. This
      script cannot do that step for them; no registry-only approach can,
      by design.

.PARAMETER Unregister
  Remove the associations this script would otherwise create, restoring
  whatever the extension was associated with before (if anything else now
  claims it, this only removes roc_desk's own ProgID entries and the
  association falls back to Windows' default "no default app" prompt).

.EXAMPLE
  .\register-file-associations.ps1
  Registers the default mapping using the exes next to this script.

.EXAMPLE
  .\register-file-associations.ps1 -Unregister
  Removes those associations again.
#>
param(
  [switch]$Unregister
)
$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ProgID prefix -- kept short and namespaced so it's obvious in regedit which
# entries belong to roc_desk if someone goes looking, and so it can't collide
# with another app's ProgID.
$progIdPrefix = "RocDesk"

# Extension -> tool exe (relative to this script's directory). Add more
# entries here as needed; each key is lowercase, dot-prefixed.
$associations = @{
  ".txt"  = "roc_desk-editor.exe"
  ".log"  = "roc_desk-editor.exe"
  ".md"   = "roc_desk-editor.exe"
  ".json" = "roc_desk-editor.exe"
  ".yaml" = "roc_desk-editor.exe"
  ".yml"  = "roc_desk-editor.exe"
  ".ini"  = "roc_desk-editor.exe"
  ".conf" = "roc_desk-editor.exe"
  ".cfg"  = "roc_desk-editor.exe"
  ".xml"  = "roc_desk-editor.exe"
  ".csv"  = "roc_desk-editor.exe"
  ".sql"  = "roc_desk-sql.exe"
}

# Notify Explorer that file associations changed, so the "always use this
# app" default takes effect without a sign-out/sign-in (SHCNE_ASSOCCHANGED).
Add-Type -Namespace RocDesk -Name Shell -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
"@
function Update-ShellAssociation {
  [RocDesk.Shell]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
}

if ($Unregister) {
  Write-Output "Removing roc_desk file associations..."
  foreach ($ext in $associations.Keys) {
    $progId = "$progIdPrefix.$($ext.TrimStart('.'))"
    Remove-Item -Path "HKCU:\Software\Classes\$progId" -Recurse -Force -ErrorAction SilentlyContinue

    # A registry key's unnamed "(Default)" value is actually named "" --
    # `Get-ItemProperty`/`Remove-ItemProperty -Name "(Default)"` only read
    # it (PowerShell's display convention), they silently fail to DELETE it
    # (`Remove-ItemProperty -Name "(Default)"` errors with "Property
    # (Default) does not exist", and `-Name ""` is rejected as an empty
    # argument) -- confirmed by testing, this left every extension's
    # default value dangling at the just-deleted ProgID instead of clearing
    # it. The underlying .NET registry API has no such restriction.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Software\Classes\$ext", $true)
    if ($key) {
      if ($key.GetValue("") -eq $progId) { $key.DeleteValue("", $false) }
      $key.Close()
    }
    Write-Output "  removed $progId ($ext)"
  }
  Update-ShellAssociation
  Write-Output "Done. Some extensions may still show roc_desk as an option under 'Open with' until Explorer restarts -- that's cosmetic, the default has already changed."
  return
}

Write-Output "Registering roc_desk file associations from $toolsDir ..."
$missingTools = @()
foreach ($ext in $associations.Keys) {
  $exeName = $associations[$ext]
  $exePath = Join-Path $toolsDir $exeName
  if (-not (Test-Path $exePath)) {
    if ($missingTools -notcontains $exeName) { $missingTools += $exeName }
    continue
  }

  $progId = "$progIdPrefix.$($ext.TrimStart('.'))"

  # ProgID -> command (what actually runs on double-click).
  New-Item -Path "HKCU:\Software\Classes\$progId\shell\open\command" -Force | Out-Null
  Set-ItemProperty -Path "HKCU:\Software\Classes\$progId\shell\open\command" -Name "(Default)" -Value "`"$exePath`" `"%1`""
  Set-ItemProperty -Path "HKCU:\Software\Classes\$progId" -Name "(Default)" -Value "roc_desk ($exeName)"

  # Extension -> ProgID (this is the actual "default app" association).
  New-Item -Path "HKCU:\Software\Classes\$ext" -Force | Out-Null
  Set-ItemProperty -Path "HKCU:\Software\Classes\$ext" -Name "(Default)" -Value $progId

  Write-Output "  $ext -> $exeName"
}

if ($missingTools.Count -gt 0) {
  Write-Warning "Skipped extensions whose tool exe wasn't found next to this script: $($missingTools -join ', ')"
  Write-Warning "(expected them in: $toolsDir)"
}

Update-ShellAssociation
Write-Output ""
Write-Output "Done. Double-clicking a registered file type now launches the matching roc_desk tool."
Write-Output "Run with -Unregister to remove these associations again."
Write-Output ""
Write-Output "Note: extensions that already had a default app on this machine before running this"
Write-Output "script (most commonly .txt -> Notepad) are NOT silently overridden -- that's a Windows"
Write-Output "anti-hijacking protection (the 'UserChoice' registry key), not a bug here. For those,"
Write-Output "right-click a file -> Open with -> pick the roc_desk tool -> check 'Always use this"
Write-Output "app' once. Extensions with no prior default switch over immediately with no extra step."

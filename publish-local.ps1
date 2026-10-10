param(
  [ValidateSet('debug','release')]
  [string]$Configuration = 'release',
  # Skip rebuilding each tool -- just re-collect whatever is already in each
  # repo's bin\ directory. Handy after fixing one tool's build without
  # wanting to wait through all six again.
  [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'

# This script lives in roc_desk-releases itself; the six tool repos are its
# siblings under the same roc_tools\ parent directory.
$releasesRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsRoot = Split-Path -Parent $releasesRoot
$bundleDir = Join-Path $releasesRoot 'bundle'
New-Item -ItemType Directory -Force $bundleDir | Out-Null

# Order doesn't matter -- each repo builds in its own target\ directory,
# independent of the others.
$repos = @(
  "roc_desk-http",
  "roc_desk-explorer",
  "roc_desk-editor",
  "roc_desk-sql",
  "roc_desk-ssh",
  "roc_desk-workspace"
)

foreach ($repo in $repos) {
  $repoPath = Join-Path $toolsRoot $repo
  if (-not (Test-Path $repoPath)) { throw "sibling repo not found: $repoPath (expected roc_desk-releases and the six tool repos to share one roc_tools\ parent directory)" }

  if (-not $SkipBuild) {
    Write-Output "==> Building $repo ($Configuration)..."
    Push-Location $repoPath
    try {
      & .\build-standalone.ps1 -Configuration $Configuration
      if ($LASTEXITCODE -ne 0) { throw "$repo build failed with exit code $LASTEXITCODE" }
    } finally {
      Pop-Location
    }
  }

  $binDir = Join-Path $repoPath 'bin'
  if (-not (Test-Path $binDir)) { throw "$repo has no bin\ directory -- its build-standalone.ps1 did not run or failed silently" }
  Get-ChildItem $binDir -File | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $bundleDir $_.Name) -Force
    Write-Output "  collected $($_.Name)"
  }
}

Copy-Item (Join-Path $releasesRoot 'register-file-associations.ps1') -Destination $bundleDir -Force

Write-Output ""
Write-Output "All tool exes collected into: $bundleDir"
Write-Output "(same directory layout the GitHub release zip uses -- each exe resolves its .rock_desk data dir relative to its own path, so they share one data dir when run from here together)"
Get-ChildItem $bundleDir | Sort-Object Name | Format-Table Name, Length, LastWriteTime -AutoSize

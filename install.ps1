<#
.SYNOPSIS
  Install SwarmKit into a target repository.

.DESCRIPTION
  Copies the agent definitions and the .swarm scaffold into a target repo,
  without clobbering anything the repo already has. Existing files are only
  replaced with -Force, and the script reports exactly what it would replace
  first so you can decide.

.EXAMPLE
  .\install.ps1 -Target C:\repos\my-project
  .\install.ps1 -Target C:\repos\my-project -Force -RegisterTask my-task
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Target,

  [switch]$Force,

  [string]$RegisterTask,

  [switch]$NoSchema
)

$ErrorActionPreference = 'Stop'
$Kit = $PSScriptRoot

if (-not (Test-Path -LiteralPath $Target)) {
  Write-Output "ERROR: target does not exist: $Target"
  exit 1
}
$Target = (Resolve-Path -LiteralPath $Target).Path
if (-not (Test-Path -LiteralPath (Join-Path $Target '.git'))) {
  Write-Output "WARN: $Target is not a git repository. The swarm commits checkpoints; continuing anyway."
}

function Copy-Tree($src, $dst, $label) {
  if (-not (Test-Path -LiteralPath $src)) { Write-Output "  skip  $label (missing: $src)"; return }
  $conflicts = @()
  if (Test-Path -LiteralPath $dst) {
    Get-ChildItem -LiteralPath $src -File -Recurse | ForEach-Object {
      $rel = $_.FullName.Substring($src.Length).TrimStart('\')
      if (Test-Path -LiteralPath (Join-Path $dst $rel)) { $conflicts += $rel }
    }
  }
  if ($conflicts.Count -and -not $Force) {
    Write-Output "  CONFLICT $label - already present, will NOT overwrite:"
    $conflicts | ForEach-Object { Write-Output "           $_" }
    Write-Output "           re-run with -Force to replace."
    return
  }
  Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
  $n = (Get-ChildItem -LiteralPath $src -File -Recurse).Count
  Write-Output "  ok    $label ($n files)"
}

Write-Output "Installing SwarmKit into: $Target"
Write-Output ""
Write-Output "opencode/ -> $Target\swarmkit\.opencode"
Copy-Tree (Join-Path $Kit 'opencode') (Join-Path $Target 'swarmkit\.opencode') 'agents + commands'

Write-Output ""
Write-Output ".swarm/ -> $Target\.swarm"
foreach ($sub in @('tasks', 'plans', 'adr', 'reviews', 'state', 'logs', 'locks', 'scripts', 'templates')) {
  Copy-Tree (Join-Path $Kit ".swarm\$sub") (Join-Path $Target ".swarm\$sub") ".swarm/$sub"
}

if (-not $NoSchema -and (Test-Path -LiteralPath (Join-Path $Kit 'schema'))) {
  Copy-Tree (Join-Path $Kit 'schema') (Join-Path $Target 'swarmkit\.swarm\schema') 'swarmkit/.swarm/schema'
  Write-Output "  ok    swarmkit/.swarm/schema (state + evidence contracts)"
}

# Keep runtime artefacts out of version control without touching a repo's
# existing .gitignore semantics.
$gi = Join-Path $Target 'swarmkit\.swarm\.gitignore'
if (-not (Test-Path -LiteralPath $gi)) {
  @'
# Runtime swarm state. The plan, ADRs, reviews and log files ARE tracked;
# the lease and machine-local noise are not.
locks/*.lock
state/*.tmp
'@ | Set-Content -LiteralPath $gi
  Write-Output "  ok    swarmkit\.swarm\.gitignore (locks and temp state untracked)"
}

Write-Output ""
if ($RegisterTask) {
  $sw = Join-Path $Target 'swarmkit\.swarm\scripts\swarm.ps1'
  if (Test-Path -LiteralPath $sw) {
    & powershell -NoProfile -File $sw init -Task $RegisterTask
  } else {
    Write-Output "WARN: swarm.ps1 not found at $sw; create the task state manually."
  }
}

Write-Output "Next:"
Write-Output "  1. Write the task:        $Target\swarmkit \.swarm\tasks\<task>.md"
Write-Output "  2. Run the swarm:         /swarm-run <task>   (or $Target\swarmkit\.swarm\scripts\swarm.sh status -Task <task>)"
Write-Output "  3. Check the budget:      $Target\swarmkit\.swarm\scripts\swarm.ps1 validate -Task <task>"
Write-Output ""
Write-Output "See $Kit\README.md for the design, and docs\MIGRATING.md to convert a v1 state file."

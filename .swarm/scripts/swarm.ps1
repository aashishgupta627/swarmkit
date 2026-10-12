<#
.SYNOPSIS
  SwarmKit control script. Single entry point for state, locking and validation.

.DESCRIPTION
  Invoked by the orchestrator agent. Every verb is idempotent and every verb
  prints a short, machine-readable result. The `status` verb is deliberately
  cheap (a few hundred tokens) so a fresh session can orient itself without
  reading the plan or the log history.

.EXAMPLE
  powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 init    -Task my-task
  powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 lock    -Task my-task
  powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 status  -Task my-task
  powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 validate -Task my-task
  powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 validate-findings -Task my-task
  powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 unlock  -Task my-task
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet('init', 'lock', 'unlock', 'status', 'validate', 'validate-findings', 'compact', 'new-phase', 'log')]
  [string]$Verb,

  [Parameter(Mandatory = $true)]
  [string]$Task,

  [string]$PhaseId,
  [string]$Title,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- paths ------
function Get-SwarmRoot {
  $p = $PSScriptRoot
  if (-not $p) { $p = Split-Path -Parent $MyInvocation.MyCommand.Path }
  return (Split-Path -Parent $p)   # .swarm
}
$Swarm    = Get-SwarmRoot
# The kit may be nested (swarmkit/.swarm) — resolve the real git toplevel so
# phase_file paths recorded as "swarmkit/.swarm/..." check against the repo
# root, not the kit's parent. Falls back to the parent when git is absent.
$top = git -C $Swarm rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -eq 0 -and $top) { $RepoRoot = ("$top").Trim() }
else { $RepoRoot = Split-Path -Parent $Swarm }
$StateDir = Join-Path $Swarm 'state'
$LockDir  = Join-Path $Swarm 'locks'
$LogDir   = Join-Path $Swarm 'logs'
$PlanDir  = Join-Path $Swarm "plans/$Task"
$ReviewDir = Join-Path $Swarm 'reviews'

$StateFile = Join-Path $StateDir "$Task.json"
$LockFile  = Join-Path $LockDir  "$Task.lock"
$TaskLog   = Join-Path $LogDir   $Task

foreach ($d in @($StateDir, $LockDir, $LogDir)) {
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ----------------------------------------------------------------- util ------
function New-SessionId {
  $epoch = [int][double]::Parse((Get-Date -UFormat %s))
  "orch-$PID-$epoch"
}
function Read-Json($path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
  catch { Write-Output "ERROR: $path is not valid JSON: $($_.Exception.Message)"; exit 2 }
}
function Write-Json($path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 12
  [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))
}
function Get-ProcAlive([int]$ProcId) {
  if ($ProcId -le 0) { return $false }
  try { return [bool](Get-Process -Id $ProcId -ErrorAction Stop) } catch { return $false }
}
function Get-Head {
  # Always resolve HEAD against the target repo, never the caller's cwd.
  $h = git -C $RepoRoot rev-parse --short HEAD 2>$null
  if ($LASTEXITCODE -eq 0 -and $h) { return $h.Trim() }
  return '0000000'
}
function Get-Slug([string]$s) {
  return (($s -replace '[^A-Za-z0-9]+', '-').Trim('-')).ToLower()
}
function Out($s) { Write-Output $s }

# Helpers for validate-findings. Hand-coded so they run under Windows
# PowerShell 5.1 and pwsh alike; -c operators keep enum and pattern checks
# case-sensitive.
function Test-IsInt($v) { return ($v -is [int] -or $v -is [long]) }
function Test-Str($v, [int]$min, [int]$max) {
  return (($v -is [string]) -and $v.Length -ge $min -and $v.Length -le $max)
}
function Test-Keys($o, [string]$path, [string[]]$req, [string[]]$opt, $errs) {
  if (($null -eq $o) -or ($o -isnot [pscustomobject])) { $errs.Add("$path must be an object"); return $false }
  $names = @($o.PSObject.Properties | ForEach-Object { $_.Name })
  $ok = $true
  foreach ($k in $req) { if ($names -cnotcontains $k) { $errs.Add("$path missing required key: $k"); $ok = $false } }
  foreach ($n in $names) { if (($req -cnotcontains $n) -and ($opt -cnotcontains $n)) { $errs.Add("$path has unknown key: $n") } }
  return $ok
}
function Test-Loc($loc, [string]$path, $errs) {
  if (-not (Test-Keys $loc $path @('file') @('line') $errs)) { return }
  if (-not (Test-Str $loc.file 1 1000)) { $errs.Add("$path.file must be a non-empty string") }
  if ($loc.PSObject.Properties['line']) {
    if (-not ((Test-IsInt $loc.line) -and $loc.line -ge 1)) { $errs.Add("$path.line must be an integer >= 1") }
  }
}
function New-TemplateState($taskName, $planDir) {
  [ordered]@{
    schema_version = 2
    task          = $taskName
    status        = 'PENDING'
    stage         = 'created'
    head          = (Get-Head)
    plan_dir      = $planDir
    artifacts     = [ordered]@{
      task   = "swarmkit/.swarm/tasks/$taskName.md"
      plan   = "$planDir/00-plan.md"
      review = "swarmkit/.swarm/reviews/$taskName.md"
    }
    done      = @()
    remaining = @()
    blockers  = @()
    events    = @([ordered]@{
      at     = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
      stage  = 'INIT'
      detail = "State v2 created by swarm.ps1 init."
    })
    decisions = @()
    baseline = [ordered]@{}
    env      = [ordered]@{}
    lock     = [ordered]@{ holder = ''; since = ''; pid = $null }
  }
}

# ----------------------------------------------------------------- init ------
if ($Verb -eq 'init') {
  if ((Test-Path -LiteralPath $StateFile) -and -not $Force) {
    Out "EXISTS: $StateFile (use -Force to overwrite)"
    exit 1
  }
  if (-not (Test-Path -LiteralPath $PlanDir)) { New-Item -ItemType Directory -Path $PlanDir -Force | Out-Null }
  Write-Json $StateFile (New-TemplateState $Task "swarmkit/.swarm/plans/$Task")
  Out "OK init task=$Task state=$StateFile"
  Out "NEXT: write swarmkit/.swarm/tasks/$Task.md, then dispatch architect to write $PlanDir/00-plan.md"
  exit 0
}

if ($Verb -eq 'new-phase') {
  if (-not $PhaseId -or -not $Title) { Out 'ERROR: new-phase requires -PhaseId and -Title'; exit 2 }
  if (-not (Test-Path -LiteralPath $PlanDir)) { New-Item -ItemType Directory -Path $PlanDir -Force | Out-Null }
  $slug = Get-Slug $Title
  $file = Join-Path $PlanDir "$PhaseId-$slug.md"
  if ((Test-Path -LiteralPath $file) -and -not $Force) { Out "EXISTS: $file"; exit 1 }
  $tpl = @"
# $PhaseId - $Title

**Depends on:** <phase ids>
**Unblocks:** <phase ids>
**Status:** planned

## Scope

Files to create or change. Be specific: path -> what changes and why.

## Design

The part of the design this phase needs. Reference `00-plan.md` for the
overall architecture; do not restate it here.

## Tests

Every test this phase must land, each mapped to an acceptance criterion.
A phase is not complete until its tests exist. Code without tests is not a
committable unit.

## Exit gate

The single check that decides whether this phase is DONE. Must be runnable
and must have been run.

## Escalation triggers

Stop and ask rather than absorb, if any of these occur.
"@
  [System.IO.File]::WriteAllText($file, $tpl, (New-Object System.Text.UTF8Encoding $false))
  Out "OK new-phase $PhaseId -> $file"
  exit 0
}

if ($Verb -eq 'log') {
  if (-not $PhaseId) { Out 'ERROR: log requires -PhaseId (used as the filename prefix)'; exit 2 }
  if (-not (Test-Path -LiteralPath $TaskLog)) { New-Item -ItemType Directory -Path $TaskLog -Force | Out-Null }
  $n = (Get-ChildItem -LiteralPath $TaskLog -Filter '*.md' -ErrorAction SilentlyContinue).Count
  $file = Join-Path $TaskLog ('{0:d3}-{1}.md' -f ($n + 1), $PhaseId)
  $head = "# Log $PhaseId - $Task - $(Get-Date -Format 'yyyy-MM-dd HH:mm')`r`n`r`N"
  [System.IO.File]::WriteAllText($file, $head, (New-Object System.Text.UTF8Encoding $false))
  Out "OK log $file"
  exit 0
}

# ------------------------------------------------------ validate-findings ---
# Read-only. Checks swarmkit/.swarm/reviews/<task>.findings.json against the shape in
# swarmkit/.swarm/schemas/findings.schema.json, then cross-checks it for consistency and
# against the review report. Exit 0 valid, 1 invalid, 2 missing or unparseable.
if ($Verb -eq 'validate-findings') {
  $ff = Join-Path $ReviewDir "$Task.findings.json"
  $rf = Join-Path $ReviewDir "$Task.md"
  if (-not (Test-Path -LiteralPath $ff)) { Out "ERROR: no findings file at $ff"; exit 2 }
  $fd = Read-Json $ff

  $SEV  = @('BLOCKER', 'HIGH', 'MEDIUM', 'LOW')
  $CLS  = @('code_defect', 'test_defect', 'env_or_dependency', 'flaky', 'spec_ambiguity', 'architectural')
  $VERD = @('APPROVED', 'APPROVED WITH NOTES', 'CHANGES_REQUIRED', 'BLOCKED')
  $errs  = New-Object System.Collections.Generic.List[string]
  $warns = New-Object System.Collections.Generic.List[string]
  $tally = @{ BLOCKER = 0; HIGH = 0; MEDIUM = 0; LOW = 0 }
  $nFind = 0; $round = 0; $verdict = ''

  $topReq = @('schema', 'task', 'review_round', 'head', 'verdict', 'counts', 'findings', 'suggestions', 'prior_findings')
  if (Test-Keys $fd 'file' $topReq @() $errs) {
    if (-not ((Test-IsInt $fd.schema) -and $fd.schema -eq 1)) { $errs.Add('schema must be 1') }
    if ($fd.task -cne $Task) { $errs.Add("task is '$($fd.task)' but this review is for '$Task'") }
    if (-not ((Test-IsInt $fd.review_round) -and $fd.review_round -ge 1)) { $errs.Add('review_round must be an integer >= 1') } else { $round = $fd.review_round }
    if (-not (($fd.head -is [string]) -and $fd.head -cmatch '^[0-9a-f]{7,40}$')) { $errs.Add('head must be a 7-40 character lowercase hex sha') }
    if ($VERD -cnotcontains [string]$fd.verdict) { $errs.Add("verdict must be one of: $($VERD -join ', ')") } else { $verdict = $fd.verdict }

    # counts
    $cnt = $fd.counts
    $cntOk = Test-Keys $cnt 'counts' $SEV @() $errs
    if ($cntOk) {
      foreach ($s in $SEV) { if (-not ((Test-IsInt $cnt.$s) -and $cnt.$s -ge 0)) { $errs.Add("counts.$s must be an integer >= 0") ; $cntOk = $false } }
    }

    # findings
    $fa = $fd.PSObject.Properties['findings'].Value
    $ids = @{}; $sigs = @{}
    if ($fa -isnot [array]) { $errs.Add('findings must be an array') }
    else {
      $i = 0
      foreach ($f in $fa) {
        $i++; $p = "findings[$i]"
        $req = @('id', 'severity', 'class', 'signature', 'title', 'location', 'evidence', 'phase', 'suggested_fix')
        if (-not (Test-Keys $f $p $req @('acs', 'repro', 'flaky_check') $errs)) { continue }
        $nFind++
        if (-not (($f.id -is [string]) -and $f.id -cmatch '^F-[0-9]{3}$')) { $errs.Add("$p.id must look like F-001") }
        elseif ($ids.ContainsKey($f.id)) { $errs.Add("$p.id duplicates $($f.id)") } else { $ids[$f.id] = $true }
        if ($SEV -cnotcontains [string]$f.severity) { $errs.Add("$p.severity must be one of: $($SEV -join ', ')"); $cntOk = $false } else { $tally[$f.severity]++ }
        if ($CLS -cnotcontains [string]$f.class) { $errs.Add("$p.class must be one of: $($CLS -join ', ')") }
        if (-not ((Test-Str $f.signature 8 120) -and $f.signature -cmatch '^(build|lint|type|test|e2e|contract|security|review):.+:.+$')) {
          $errs.Add("$p.signature must be <check>:<locator>:<error>, 8-120 chars, check one of build|lint|type|test|e2e|contract|security|review")
        } else {
          if ($sigs.ContainsKey($f.signature)) { $errs.Add("$p.signature duplicates an earlier finding: $($f.signature)") } else { $sigs[$f.signature] = $true }
          $numeric = @(($f.signature -split ':') | Select-Object -Skip 1 | Where-Object { $_ -cmatch '^[0-9]+$' })
          if ($numeric.Count) { $warns.Add("$p.signature has a purely numeric part; line numbers and counts make signatures drift between rounds: $($f.signature)") }
        }
        if (-not (Test-Str $f.title 1 120)) { $errs.Add("$p.title must be 1-120 chars") }
        Test-Loc $f.location "$p.location" $errs
        if (Test-Keys $f.evidence "$p.evidence" @('cmd', 'exit_code', 'excerpt') @() $errs) {
          if (($null -ne $f.evidence.cmd) -and ($f.evidence.cmd -isnot [string])) { $errs.Add("$p.evidence.cmd must be a string or null") }
          if (($null -ne $f.evidence.exit_code) -and -not (Test-IsInt $f.evidence.exit_code)) { $errs.Add("$p.evidence.exit_code must be an integer or null") }
          if (-not (Test-Str $f.evidence.excerpt 0 600)) { $errs.Add("$p.evidence.excerpt must be a string of at most 600 chars") }
        }
        if (-not (Test-Str $f.phase 1 16)) { $errs.Add("$p.phase must be 1-16 chars") }
        if (-not (Test-Str $f.suggested_fix 1 400)) { $errs.Add("$p.suggested_fix must be 1-400 chars") }
        if ($f.PSObject.Properties['repro'] -and -not (Test-Str $f.repro 0 300)) { $errs.Add("$p.repro must be a string of at most 300 chars") }
        if ($f.PSObject.Properties['acs']) {
          $acs = $f.PSObject.Properties['acs'].Value
          if ($acs -isnot [array]) { $errs.Add("$p.acs must be an array of strings") }
          else { foreach ($a in $acs) { if ($a -isnot [string]) { $errs.Add("$p.acs must contain only strings") ; break } } }
        }
        if ($f.PSObject.Properties['flaky_check']) {
          $fc = $f.flaky_check
          if (Test-Keys $fc "$p.flaky_check" @('reruns', 'results') @() $errs) {
            if (-not ((Test-IsInt $fc.reruns) -and $fc.reruns -ge 1)) { $errs.Add("$p.flaky_check.reruns must be an integer >= 1") }
            $fr = $fc.PSObject.Properties['results'].Value
            if (($fr -isnot [array]) -or $fr.Count -lt 2) { $errs.Add("$p.flaky_check.results must list at least 2 outcomes") }
            else { foreach ($x in $fr) { if (@('pass', 'fail') -cnotcontains [string]$x) { $errs.Add("$p.flaky_check.results must contain only pass or fail"); break } } }
          }
        } elseif ($f.class -ceq 'flaky') { $errs.Add("$p is class flaky but has no flaky_check") }
      }
    }

    # suggestions
    $sa = $fd.PSObject.Properties['suggestions'].Value
    if ($sa -isnot [array]) { $errs.Add('suggestions must be an array') }
    else {
      $i = 0
      foreach ($g in $sa) {
        $i++; $p = "suggestions[$i]"
        if (-not (Test-Keys $g $p @('title', 'location') @('note') $errs)) { continue }
        if (-not (Test-Str $g.title 1 120)) { $errs.Add("$p.title must be 1-120 chars") }
        Test-Loc $g.location "$p.location" $errs
        if ($g.PSObject.Properties['note'] -and -not (Test-Str $g.note 0 300)) { $errs.Add("$p.note must be a string of at most 300 chars") }
      }
    }

    # prior findings
    $pa = $fd.PSObject.Properties['prior_findings'].Value
    $nPrior = 0
    if ($pa -isnot [array]) { $errs.Add('prior_findings must be an array') }
    else {
      $i = 0
      foreach ($q in $pa) {
        $i++; $p = "prior_findings[$i]"
        if (-not (Test-Keys $q $p @('signature', 'status') @() $errs)) { continue }
        $nPrior++
        if (-not (Test-Str $q.signature 8 120)) { $errs.Add("$p.signature must be 8-120 chars") }
        if (@('resolved', 'still_open') -cnotcontains [string]$q.status) { $errs.Add("$p.status must be resolved or still_open") }
        elseif ($q.status -ceq 'still_open' -and -not $sigs.ContainsKey($q.signature)) { $errs.Add("$p is still_open but no finding carries signature $($q.signature)") }
        elseif ($q.status -ceq 'resolved' -and $sigs.ContainsKey($q.signature)) { $errs.Add("$p is resolved but a finding still carries signature $($q.signature)") }
      }
      if ($round -eq 1 -and $nPrior -gt 0) { $errs.Add('review_round is 1 but prior_findings is not empty') }
    }

    # consistency: counts, verdict
    if ($cntOk) {
      foreach ($s in $SEV) { if ($cnt.$s -ne $tally[$s]) { $errs.Add("counts.$s is $($cnt.$s) but findings contain $($tally[$s])") } }
    }
    # Unqualified APPROVED allows no MEDIUM, matching the rule that an unrunnable
    # gate is MEDIUM and blocks it. Relax here if you want MEDIUM under APPROVED.
    $crit = $tally['BLOCKER'] + $tally['HIGH']
    if ($verdict -ceq 'APPROVED' -and ($crit + $tally['MEDIUM']) -gt 0) { $errs.Add('verdict APPROVED but findings include BLOCKER, HIGH or MEDIUM') }
    if ($verdict -ceq 'APPROVED WITH NOTES' -and $crit -gt 0) { $errs.Add('verdict APPROVED WITH NOTES but findings include BLOCKER or HIGH') }
    if ($verdict -ceq 'CHANGES_REQUIRED' -and $nFind -eq 0) { $errs.Add('verdict CHANGES_REQUIRED but there are no findings') }

    # the report must carry every finding id, so prose and file cannot diverge
    if (-not (Test-Path -LiteralPath $rf)) { $errs.Add("review report not found: $rf") }
    else {
      $rt = Get-Content -LiteralPath $rf -Raw
      foreach ($k in $ids.Keys) { if (-not $rt.Contains($k)) { $errs.Add("finding $k is not mentioned in the review report") } }
    }
  }

  if ($errs.Count -eq 0) {
    $warns | Select-Object -Unique | ForEach-Object { Out "WARN $_" }
    Out "OK validate-findings task=$Task findings=$nFind round=$round verdict=$verdict"
    exit 0
  }
  $errs | Select-Object -Unique | ForEach-Object { Out "ERROR $_" }
  exit 1
}

# ---------------------------------------------------------------- state ------
$st = Read-Json $StateFile
if (-not $st) { Out "ERROR: no state for task '$Task'. Run: swarm.ps1 init -Task $Task"; exit 2 }

if (-not $st.PSObject.Properties['schema_version'] -or $st.schema_version -ne 2) {
  Out "ERROR: state is not schema v2."
  Out "      v1 state files are not resumable under this kit. Follow docs/MIGRATING.md:"
  Out "        1. archive this file to swarmkit/.swarm/logs/$Task/000-legacy-state-v1.json"
  Out "        2. split the plan into swarmkit/.swarm/plans/$Task/00-plan.md plus phase files"
  Out "        3. re-run 'init -Force' and rebuild done[]/remaining[] from git"
  exit 2
}

# ---------------------------------------------------------------- lock -------
# Single-writer lease. This is the mechanism that replaces the prose
# 'ownership' block, which enforced nothing and allowed two orchestrators to
# run on one tree and silently drop history.
switch ($Verb) {
  'lock' {
    $holder = $st.lock.holder
    if ($holder -and $holder -ne (New-SessionId)) {
      $otherPid = $st.lock.pid
      if (Get-ProcAlive ([int]$otherPid)) {
        Out "LOCKED task=$Task holder=$holder pid=$otherPid alive=true"
        Out "HALT: another swarm session holds the write lease for this task."
        Out "      Do not proceed. Ask the user whether to take over."
        exit 3
      }
      if (-not $Force) {
        Out "STALE_LOCK task=$Task holder=$holder pid=$otherPid alive=false"
        Out "HALT: the lease holder is gone but the lock was not released."
        Out "      Re-run with -Force to break it, after confirming no other session is active."
        exit 3
      }
    }
    $sid = New-SessionId
    $st.lock.holder = $sid
    $st.lock.since  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    $st.lock.pid    = $PID
    Write-Json $StateFile $st
    $lf = @{
      task = $Task; holder = $sid; pid = $PID
      since = $st.lock.since; repo = $RepoRoot
    } | ConvertTo-Json
    [System.IO.File]::WriteAllText($LockFile, $lf, (New-Object System.Text.UTF8Encoding $false))
    Out "OK lock task=$Task holder=$sid"
    exit 0
  }
  'unlock' {
    $st.lock.holder = ''
    $st.lock.pid    = $null
    Write-Json $StateFile $st
    if (Test-Path -LiteralPath $LockFile) { Remove-Item -LiteralPath $LockFile -Force }
    Out "OK unlock task=$Task"
    exit 0
  }
}

# -------------------------------------------------------------- status -------
if ($Verb -eq 'status') {
  $d = @($st.done)
  $r = @($st.remaining)
  $b = @($st.blockers | Where-Object { $_.state -eq 'OPEN' -or $_.state -eq 'BLOCKED' })
  $live = $st.head
  $actual = Get-Head
  $drift = if ($live -eq $actual) { 'no' } else { "YES ($live -> $actual)" }
  Out "task=$($st.task) status=$($st.status) stage=$($st.stage)"
  Out "head=$($st.head) drift=$drift"
  Out "done=$($d.Count) remaining=$($r.Count) open_blockers=$($b.Count)"
  if ($d.Count) { $d | ForEach-Object { Out "  done $($_.id) $($_.commit) tests=$($_.tests)" } }
  if ($r.Count) { $r | ForEach-Object { Out "  todo $($_.id) -> $($_.phase_file)" } }
  if ($b.Count) { $b | ForEach-Object { Out "  BLOCK $($_.id) [$($_.state)] owner=$($_.owner) $($_.note)" } }
  Out "plan=$(if (Test-Path (Join-Path $PlanDir '00-plan.md')) { Join-Path $PlanDir '00-plan.md' } else { 'MISSING 00-plan.md' })"
  Out "lock=$($st.lock.holder)"
  exit 0
}

# ------------------------------------------------------------- validate ------
if ($Verb -eq 'validate') {
  $errs = New-Object System.Collections.Generic.List[string]
  $sz = (Get-Item -LiteralPath $StateFile).Length
  if ($sz -gt 4096) { $errs.Add("state file is $sz bytes; budget is 4096. Move detail to swarmkit/.swarm/logs/$Task/ and reference it.") }

  foreach ($k in @('task', 'status', 'stage', 'head', 'plan_dir', 'done', 'remaining', 'blockers', 'events', 'baseline', 'env', 'lock')) {
    if (-not $st.PSObject.Properties[$k]) { $errs.Add("missing required key: $k") }
  }
  # Reserved, optional fields. Absent means autonomy=supervised and cycle 0.
  if ($st.PSObject.Properties['autonomy']) {
    if (@('supervised', 'auto') -cnotcontains [string]$st.autonomy) { $errs.Add("autonomy must be 'supervised' or 'auto', got '$($st.autonomy)'") }
  }
  if ($st.PSObject.Properties['heal']) {
    $hc = if ($st.heal -is [pscustomobject]) { $st.heal.PSObject.Properties['cycle'] } else { $null }
    if (-not $hc -or -not (Test-IsInt $hc.Value) -or $hc.Value -lt 0) { $errs.Add('heal must be an object with an integer cycle >= 0') }
  }
  $longEvents = @($st.events | Where-Object { $_.detail -and $_.detail.Length -gt 180 })
  if ($longEvents.Count -eq 1) {
    $errs.Add("event detail $($longEvents[0].detail.Length) chars > 180: move to a log file")
  } elseif ($longEvents.Count -gt 1) {
    $errs.Add("$($longEvents.Count) event details exceed the 180-char cap: move detail to swarmkit/.swarm/logs/$Task/ and reference by path")
  }
  if (@($st.events).Count -gt 30) { $errs.Add("$(@($st.events).Count) events > 30. Fold the oldest into a log file and keep the last 10.") }
  foreach ($o in @($st.remaining)) {
    if ($o.phase_file -and -not (Test-Path -LiteralPath (Join-Path $RepoRoot $o.phase_file))) {
      $errs.Add("remaining.$($o.id) points at missing file: $($o.phase_file)")
    }
  }
  $p0 = Join-Path $PlanDir '00-plan.md'
  if (Test-Path -LiteralPath $p0) {
    $pl = (Get-Content -LiteralPath $p0 | Measure-Object -Line).Lines
    if ($pl -gt 300) { $errs.Add("00-plan.md is $pl lines > 300. Move detail into per-phase files.") }
  }
  foreach ($d in @($st.done)) {
    if ($d.commit) {
      git -C $RepoRoot cat-file -e "$($d.commit)^{commit}" 2>$null
      if ($LASTEXITCODE -ne 0) { $errs.Add("done.$($d.id) commit not found: $($d.commit)") }
    }
  }
  if ($errs.Count -eq 0) { Out "OK validate task=$Task bytes=$sz"; exit 0 }
  $errs | Select-Object -Unique | ForEach-Object { Out "ERROR $_" }
  exit 1
}

# ------------------------------------------------------------- compact ------
# Fold old events into a log file so the state file stays inside budget without
# losing the record. This is what makes the 4 KB cap sustainable.
if ($Verb -eq 'compact') {
  $evs = @($st.events)
  $BUDGET = 3600   # target working size, leaving headroom under the 4096 hard cap
  if ((Get-Item -LiteralPath $StateFile).Length -le $BUDGET) {
    Out "OK compact task=$Task events=$($evs.Count) bytes=$((Get-Item -LiteralPath $StateFile).Length) (already within budget)"
    exit 0
  }
  if (-not (Test-Path -LiteralPath $TaskLog)) { New-Item -ItemType Directory -Path $TaskLog -Force | Out-Null }

  # Keep as many trailing events as fit, never fewer than 3, so the timeline
  # stays usable. Fold everything older into a log file.
  $keepN = $evs.Count
  while ($keepN -gt 3) {
    $trial = @()
    $trialEvs = $evs[($evs.Count - $keepN)..($evs.Count - 1)]
    $copy = $st | Select-Object *
    $copy.events = $trialEvs
    $sz = ($copy | ConvertTo-Json -Depth 12).Length
    if ($sz -le $BUDGET) { break }
    $keepN--
  }
  $foldFrom = $evs.Count - $keepN
  if ($foldFrom -le 0) { Out "WARN compact: cannot fit under $BUDGET even keeping 3 events; state needs manual review"; exit 1 }

  $old = $evs[0..($foldFrom - 1)]
  $new = $evs[$foldFrom..($evs.Count - 1)]
  $file = Join-Path $TaskLog ('{0:d3}-events-fold.md' -f ((Get-ChildItem -LiteralPath $TaskLog -Filter '*.md').Count + 1))
  $md = "# Folded events - $Task`r`n`r`n$($old.Count) events moved here to keep the state file inside its 4 KB budget.`r`n"
  foreach ($e in $old) { $md += "- ``$($e.at)`` **$($e.stage)** - $($e.detail)`r`n" }
  [System.IO.File]::WriteAllText($file, $md, (New-Object System.Text.UTF8Encoding $false))
  $st.events = $new
  Write-Json $StateFile $st
  $after = (Get-Item -LiteralPath $StateFile).Length
  Out "OK compact task=$Task folded=$($old.Count) kept=$($new.Count) bytes=$after log=$file"
  exit 0
}

Out "ERROR: unhandled verb $Verb"
exit 2

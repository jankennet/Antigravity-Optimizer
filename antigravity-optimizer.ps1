#!/usr/bin/env pwsh
# ============================================================
# Antigravity Low-End Optimizer (Windows / PowerShell)
# ============================================================

$ErrorActionPreference = "Stop"

$BaseDir    = Join-Path $env:LOCALAPPDATA "antigravity-lowend"
$BackupDir  = Join-Path $BaseDir "backups"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

function Info ($label, $value) { Write-Host ("  {0,-14}" -f $label) -ForegroundColor Cyan -NoNewline; Write-Host " $value" }
function Ok   ($label, $value) { Write-Host ("  {0,-14}" -f $label) -ForegroundColor Green -NoNewline; Write-Host " $value" }
function Warn ($label, $value) { Write-Host ("  {0,-14}" -f $label) -ForegroundColor Yellow -NoNewline; Write-Host " $value" }
function Fail ($label, $value) { Write-Host ("  {0,-14}" -f $label) -ForegroundColor Red -NoNewline; Write-Host " $value" }

function Section ($title) {
    Write-Host ""
    Write-Host $title -ForegroundColor White
    Write-Host "------------------------------------------------------------"
}

function Show-Help {
@"
Usage:
  antigravity-lowend                     Optimize and launch
  antigravity-lowend -Optimize           Optimize only, no launch
  antigravity-lowend -Profile <name>     auto | normal | low | extreme
  antigravity-lowend -Safe               Compatibility mode (no GPU)
  antigravity-lowend -Status             Show detected hardware/state
  antigravity-lowend -Reset              Restore latest settings backup
  antigravity-lowend -Help               Show this help

See README.md for details on each profile.
"@ | Write-Host
}

# ------------------------------------------------------------
# Arguments
# ------------------------------------------------------------

$ProfileName        = "auto"
$OptimizeOnly   = $false
$ResetRequested = $false
$StatusRequested= $false
$Passthrough    = @()

$i = 0
while ($i -lt $args.Count) {
    switch -Regex ($args[$i]) {
        '^(--profile|-profile)$' {
            if ($i + 1 -ge $args.Count) { Fail "ERROR" "-Profile requires a value"; exit 1 }
            $ProfileName = $args[$i + 1].ToLower()
            $i += 2
            continue
        }
        '^(--safe|-safe)$'       { $ProfileName = "safe"; $i++; continue }
        '^(--optimize|-optimize)$' { $OptimizeOnly = $true; $i++; continue }
        '^(--reset|-reset)$'     { $ResetRequested = $true; $i++; continue }
        '^(--status|-status)$'   { $StatusRequested = $true; $i++; continue }
        '^(--help|-help|-h)$'    { Show-Help; exit 0 }
        default                  { $Passthrough += $args[$i]; $i++; continue }
    }
}

# ------------------------------------------------------------
# Hardware detection
# ------------------------------------------------------------

$CpuThreads = [Environment]::ProcessorCount

$CpuInfo  = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$CpuModel = if ($CpuInfo -and $CpuInfo.Name) { $CpuInfo.Name.Trim() } else { "Unknown CPU" }

$OsInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$MemGB  = [math]::Round($OsInfo.TotalVisibleMemorySize / 1MB)

# CPU classification
$CpuClass = "normal"
if ($CpuThreads -le 2) { $CpuClass = "extreme" }
elseif ($CpuThreads -le 4) { $CpuClass = "low" }

if ($CpuModel -match '(Celeron N\d+|Pentium Silver|Pentium N\d+|Atom|Athlon Silver|Athlon 300U)') {
    $CpuClass = "extreme"
}

# RAM classification
$RamClass = "normal"
if ($MemGB -le 4) { $RamClass = "extreme" }
elseif ($MemGB -le 8) { $RamClass = "low" }

# Automatic profile
if ($ProfileName -eq "auto") {
    if ($CpuClass -eq "extreme" -or $RamClass -eq "extreme") { $ProfileName = "extreme" }
    elseif ($CpuClass -eq "low" -or $RamClass -eq "low") { $ProfileName = "low" }
    else { $ProfileName = "normal" }
}

if ($ProfileName -notin @("normal", "low", "extreme", "safe")) {
    Fail "ERROR" "Invalid profile: $ProfileName"
    exit 1
}

# ------------------------------------------------------------
# Find settings file
# ------------------------------------------------------------

$SettingsFile = $null
$Candidates = @(
    (Join-Path $env:APPDATA "Antigravity\User\settings.json"),
    (Join-Path $env:APPDATA "antigravity\User\settings.json")
)

foreach ($candidate in $Candidates) {
    if (Test-Path $candidate -PathType Leaf) { $SettingsFile = $candidate; break }
}

if (-not $SettingsFile -and (Test-Path $env:APPDATA)) {
    $found = Get-ChildItem -Path $env:APPDATA -Recurse -Depth 3 -Filter "settings.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\(Antigravity|antigravity)\\User\\settings\.json$' } |
        Select-Object -First 1
    if ($found) { $SettingsFile = $found.FullName }
}

# ------------------------------------------------------------
# Locate Antigravity binary
# ------------------------------------------------------------

$AntigravityBin = $null
$BinCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Antigravity\Antigravity.exe"),
    (Join-Path $env:ProgramFiles "Antigravity\Antigravity.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity\Antigravity.exe")
)
foreach ($bin in $BinCandidates) {
    if ($bin -and (Test-Path $bin -PathType Leaf)) { $AntigravityBin = $bin; break }
}
if (-not $AntigravityBin) {
    $cmd = Get-Command antigravity -ErrorAction SilentlyContinue
    if ($cmd) { $AntigravityBin = $cmd.Source }
}

# ------------------------------------------------------------
# Status
# ------------------------------------------------------------

if ($StatusRequested) {
    Section "ANTIGRAVITY LOW-END STATUS"
    Info "CPU" $CpuModel
    Info "THREADS" $CpuThreads
    Info "RAM" "$MemGB GiB"
    Info "CPU CLASS" $CpuClass
    Info "RAM CLASS" $RamClass
    Info "PROFILE" $ProfileName

    if ($SettingsFile) { Info "SETTINGS" $SettingsFile } else { Warn "SETTINGS" "Not found" }
    if ($AntigravityBin) { Ok "BINARY" $AntigravityBin } else { Warn "BINARY" "Not found" }
    exit 0
}

# ------------------------------------------------------------
# Reset
# ------------------------------------------------------------

if ($ResetRequested) {
    Section "ANTIGRAVITY LOW-END RESET"

    $latest = Get-ChildItem -Path $BackupDir -Filter "settings.json.*.backup" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $latest) {
        Fail "RESET" "No settings backup found."
        exit 1
    }

    if (-not $SettingsFile) {
        $SettingsFile = Join-Path $env:APPDATA "Antigravity\User\settings.json"
        New-Item -ItemType Directory -Force -Path (Split-Path $SettingsFile) | Out-Null
    }

    Copy-Item -Path $latest.FullName -Destination $SettingsFile -Force

    Ok "RESTORE" "Previous settings restored"
    Info "SOURCE" $latest.FullName
    Info "TARGET" $SettingsFile
    Write-Host ""
    Ok "DONE" "Reset complete."
    exit 0
}

# ------------------------------------------------------------
# Validate binary
# ------------------------------------------------------------

if (-not $AntigravityBin) {
    Fail "ERROR" "Antigravity binary not found."
    Write-Host "          Checked Program Files, LocalAppData\Programs, and PATH."
    exit 1
}

# ------------------------------------------------------------
# Create settings file if missing
# ------------------------------------------------------------

if (-not $SettingsFile) {
    $SettingsDir = Join-Path $env:APPDATA "Antigravity\User"
    New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null
    $SettingsFile = Join-Path $SettingsDir "settings.json"
}

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

$Timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupFile = Join-Path $BackupDir "settings.json.$Timestamp.backup"

if (Test-Path $SettingsFile -PathType Leaf) {
    Copy-Item -Path $SettingsFile -Destination $BackupFile -Force
    Ok "BACKUP" $BackupFile
} else {
    New-Item -ItemType File -Force -Path $SettingsFile | Out-Null
    Ok "SETTINGS" "Created settings.json"
}

# ------------------------------------------------------------
# Display
# ------------------------------------------------------------

Clear-Host

Write-Host "Antigravity Low-End Optimizer" -ForegroundColor White
Write-Host "Adaptive + Agent Responsiveness mode"

Section "HARDWARE"
Info "CPU" $CpuModel
Info "THREADS" $CpuThreads
Info "RAM" "$MemGB GiB"
Info "CPU CLASS" $CpuClass
Info "RAM CLASS" $RamClass

Section "PROFILE"
switch ($ProfileName) {
    "normal"  { Info "PROFILE" "NORMAL";          Info "TARGET" "Conservative optimization" }
    "low"     { Info "PROFILE" "LOW";             Info "TARGET" "Low-end optimization" }
    "extreme" { Info "PROFILE" "EXTREME LOW-END"; Info "TARGET" "Agent responsiveness" }
    "safe"    { Info "PROFILE" "SAFE";            Info "TARGET" "Maximum compatibility" }
}

Section "OPTIMIZATION PROCEDURE"
Write-Host "  STEP 1/10  Detect hardware"
Write-Host "  STEP 2/10  Select adaptive profile"
Write-Host "  STEP 3/10  Backup existing configuration"
Write-Host "  STEP 4/10  Reduce editor rendering workload"
Write-Host "  STEP 5/10  Reduce file watcher workload"
Write-Host "  STEP 6/10  Reduce Git background activity"
Write-Host "  STEP 7/10  Reduce search/index workload"
Write-Host "  STEP 8/10  Reduce agent-output rendering pressure"
Write-Host "  STEP 9/10  Configure Electron compatibility"
Write-Host "  STEP 10/10 Launch optimized Antigravity"
Write-Host ""

# ------------------------------------------------------------
# JSONC helpers (comment/trailing-comma stripping, no external deps)
# ------------------------------------------------------------

function Strip-JsonComments {
    param([string]$Text)

    $sb = New-Object System.Text.StringBuilder
    $inString = $false; $escape = $false
    $lineComment = $false; $blockComment = $false
    $n = $Text.Length

    for ($i = 0; $i -lt $n; $i++) {
        $c = $Text[$i]
        $nxt = if ($i + 1 -lt $n) { $Text[$i + 1] } else { [char]0 }

        if ($lineComment) {
            if ($c -eq "`n") { $lineComment = $false; [void]$sb.Append($c) }
            continue
        }
        if ($blockComment) {
            if ($c -eq '*' -and $nxt -eq '/') { $blockComment = $false; $i++ }
            continue
        }
        if ($inString) {
            [void]$sb.Append($c)
            if ($escape) { $escape = $false }
            elseif ($c -eq '\') { $escape = $true }
            elseif ($c -eq '"') { $inString = $false }
            continue
        }
        if ($c -eq '"') { $inString = $true; [void]$sb.Append($c); continue }
        if ($c -eq '/' -and $nxt -eq '/') { $lineComment = $true; $i++; continue }
        if ($c -eq '/' -and $nxt -eq '*') { $blockComment = $true; $i++; continue }
        [void]$sb.Append($c)
    }

    $result = $sb.ToString()
    return [regex]::Replace($result, ',(\s*[}\]])', '$1')
}

function ConvertFrom-JsonToHashtable {
    param([string]$Json)
    $ht = @{}
    if ([string]::IsNullOrWhiteSpace($Json)) { return $ht }
    $obj = $Json | ConvertFrom-Json
    if ($obj) {
        foreach ($prop in $obj.PSObject.Properties) { $ht[$prop.Name] = $prop.Value }
    }
    return $ht
}

# ------------------------------------------------------------
# Generate settings
# ------------------------------------------------------------

try {
    $raw = if (Test-Path $SettingsFile) { Get-Content -Path $SettingsFile -Raw -ErrorAction SilentlyContinue } else { "" }
    $settings = ConvertFrom-JsonToHashtable (Strip-JsonComments $raw)
} catch {
    Fail "CONFIG" "Unable to parse settings.json: $($_.Exception.Message)"
    if (Test-Path $BackupFile) { Copy-Item $BackupFile $SettingsFile -Force; Warn "RESTORE" "Original configuration restored." }
    exit 1
}

# Editor rendering
$settings["editor.minimap.enabled"]              = $false
$settings["editor.smoothScrolling"]               = $false
$settings["workbench.list.smoothScrolling"]       = $false
$settings["editor.cursorSmoothCaretAnimation"]    = "off"
$settings["editor.hover.delay"]                   = 500
$settings["editor.lightbulb.enabled"]             = "off"
$settings["editor.codeLens"]                      = $false
$settings["editor.stickyScroll.enabled"]          = $false
$settings["editor.occurrencesHighlight"]          = $false
$settings["editor.selectionHighlight"]            = $false
$settings["editor.renderWhitespace"]              = "none"
$settings["editor.renderControlCharacters"]       = $false
$settings["editor.overviewRulerBorder"]           = $false
$settings["editor.guides.bracketPairs"]           = $false
# Workbench
$settings["workbench.editor.enablePreview"]       = $true
$settings["workbench.editor.limit.enabled"]       = $true
# Git
$settings["git.autofetch"]                        = $false
$settings["git.autorefresh"]                      = $false
# Search
$settings["search.followSymlinks"]                = $false
# Source control decorations
$settings["scm.diffDecorations"]                  = "none"
# File saving
$settings["files.autoSave"]                       = "off"

# File watcher exclusions
$settings["files.watcherExclude"] = @{
    "**/.git/objects/**"    = $true
    "**/.git/subtree-cache/**" = $true
    "**/node_modules/**"    = $true
    "**/.next/**"           = $true
    "**/dist/**"             = $true
    "**/build/**"            = $true
    "**/coverage/**"         = $true
    "**/.cache/**"           = $true
    "**/.turbo/**"           = $true
    "**/.parcel-cache/**"    = $true
    "**/.vite/**"             = $true
    "**/target/**"            = $true
    "**/__pycache__/**"       = $true
    "**/.venv/**"              = $true
}

$settings["search.exclude"] = @{
    "**/node_modules" = $true
    "**/.git"          = $true
    "**/dist"          = $true
    "**/build"         = $true
    "**/.next"         = $true
    "**/coverage"      = $true
    "**/.cache"        = $true
    "**/.turbo"        = $true
    "**/target"        = $true
    "**/__pycache__"   = $true
    "**/.venv"          = $true
}

switch ($ProfileName) {
    "normal"  { $settings["workbench.editor.limit.value"] = 8; $settings["terminal.integrated.scrollback"] = 2000 }
    "low"     { $settings["workbench.editor.limit.value"] = 5; $settings["terminal.integrated.scrollback"] = 1000 }
    { $_ -in @("extreme", "safe") } {
        $settings["workbench.editor.limit.value"] = 3
        $settings["terminal.integrated.scrollback"] = 500
    }
}

if ($ProfileName -in @("extreme", "safe")) {
    $settings["editor.inlayHints.enabled"]                 = "off"
    $settings["editor.bracketPairColorization.enabled"]    = $false
    $settings["editor.guides.bracketPairs"]                = $false
    $settings["editor.semanticHighlighting.enabled"]       = $false
    $settings["terminal.integrated.gpuAcceleration"]       = "off"
    $settings["terminal.integrated.scrollback"]            = 500
}

try {
    $json = $settings | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($SettingsFile, $json + "`n", $utf8NoBom)
} catch {
    Fail "CONFIG" "Configuration generation failed: $($_.Exception.Message)"
    if (Test-Path $BackupFile) { Copy-Item $BackupFile $SettingsFile -Force; Warn "RESTORE" "Original configuration restored." }
    exit 1
}

Ok "CONFIG" "Agent responsiveness configuration applied"

# ------------------------------------------------------------
# Electron / Node / environment
# ------------------------------------------------------------

$ElectronArgs = @()
if ($ProfileName -eq "safe") { $ElectronArgs += "--disable-gpu" }
Ok "ELECTRON" "Using stable Electron arguments only"

$NodeHeap = switch ($ProfileName) {
    "normal"  { 1536 }
    "low"     { 1024 }
    "extreme" { 768 }
    "safe"    { 768 }
}

$env:NODE_OPTIONS = "--max-old-space-size=$NodeHeap"
Ok "MEMORY" "Node heap: $NodeHeap MB"

$env:ANTIGRAVITY_LOWEND = "1"
$env:ANTIGRAVITY_LOWEND_PROFILE = $ProfileName

# ------------------------------------------------------------
# Final configuration
# ------------------------------------------------------------

Section "FINAL CONFIGURATION"
Info "Profile" $ProfileName
Info "CPU" $CpuModel
Info "RAM" "$MemGB GiB"
Info "Threads" $CpuThreads
Info "Node heap" "$NodeHeap MB"
Info "GPU" $(if ($ProfileName -eq "safe") { "software" } else { "hardware" })
Info "Agent mode" $(if ($ProfileName -in @("extreme", "safe")) { "RESPONSIVE" } else { "BALANCED" })
Info "Diagnostics" "OFF"
Write-Host ""

if ($OptimizeOnly) {
    Ok "DONE" "Antigravity optimization complete."
    Write-Host ""
    Write-Host "  Launch with:"
    Write-Host "    antigravity-lowend"
    Write-Host ""
    exit 0
}

Section "LAUNCH"
Write-Host "  Antigravity is starting with the optimized configuration."
Write-Host ""

$allArgs = $ElectronArgs + $Passthrough
Start-Process -FilePath $AntigravityBin -ArgumentList $allArgs
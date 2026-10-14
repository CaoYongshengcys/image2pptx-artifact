# check_env.ps1 — Verify Codex CLI + artifact-tool environment
# Usage: powershell -ExecutionPolicy Bypass -File check_env.ps1

$errors = @()
$warnings = @()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " image2pptx-artifact Environment Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check codex CLI
Write-Host "[1/5] Checking Codex CLI..." -NoNewline
try {
    $ver = & codex --version 2>&1
    if ($LASTEXITCODE -eq 0 -and $ver -match '\d+\.\d+') {
        Write-Host " OK ($ver)" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        $errors += "codex CLI not found or not working. Install: npm install -g @openai/codex --registry https://registry.npmmirror.com"
    }
} catch {
    Write-Host " NOT FOUND" -ForegroundColor Red
    $errors += "codex CLI not in PATH. Install: npm install -g @openai/codex --registry https://registry.npmmirror.com"
}

# 2. Check artifact-tool runtime
Write-Host "[2/5] Checking artifact-tool runtime..." -NoNewline
$artifactPath = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\@oai\artifact-tool\package.json"
if (Test-Path $artifactPath) {
    $pkg = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Write-Host " OK (v$($pkg.version))" -ForegroundColor Green
} else {
    Write-Host " MISSING" -ForegroundColor Yellow
    $warnings += "artifact-tool runtime not downloaded yet. Run 'codex exec --skip-git-repo-check hello' to trigger download."
}

# 3. Check artifact feature flag
Write-Host "[3/5] Checking artifact feature flag..." -NoNewline
$configPath = Join-Path $env:USERPROFILE ".codex\config.toml"
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw
    if ($config -match 'artifact\s*=\s*true') {
        Write-Host " OK (enabled)" -ForegroundColor Green
    } else {
        Write-Host " DISABLED" -ForegroundColor Yellow
        $warnings += "artifact feature not enabled. Run: codex features enable artifact"
    }
} else {
    Write-Host " NO CONFIG" -ForegroundColor Yellow
    $warnings += "No config.toml found. Run: codex features enable artifact"
}

# 4. Check API provider config
Write-Host "[4/5] Checking API provider..." -NoNewline
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw
    if ($config -match 'model_provider\s*=\s*"(\w+)"') {
        $provider = $Matches[1]
        Write-Host " OK (provider: $provider)" -ForegroundColor Green
    } else {
        Write-Host " NOT CONFIGURED" -ForegroundColor Red
        $errors += "No model_provider in config.toml. Add a [model_providers.xxx] section with base_url and auth."
    }
} else {
    Write-Host " NO CONFIG" -ForegroundColor Red
    $errors += "No ~/.codex/config.toml. Create one with model and model_provider settings."
}

# 5. Check approval policy
Write-Host "[5/5] Checking approval policy..." -NoNewline
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw
    if ($config -match 'approvals_reviewer\s*=\s*"auto_review"' -and $config -notmatch '#\s*approvals_reviewer') {
        Write-Host " WARNING (auto_review active)" -ForegroundColor Yellow
        $warnings += "approvals_reviewer = auto_review is active but may fail with 'Model not found'. Comment it out in config.toml."
    } elseif ($config -match 'approval_policy\s*=\s*"never"') {
        Write-Host " OK (never - auto execute)" -ForegroundColor Green
    } else {
        Write-Host " OK (default)" -ForegroundColor Green
    }
} else {
    Write-Host " SKIP" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host " ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host " Ready to use image2pptx-artifact!" -ForegroundColor Green
} elseif ($errors.Count -eq 0) {
    Write-Host " PASSED with warnings" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "  ! $w" -ForegroundColor Yellow }
} else {
    Write-Host " FAILED - $($errors.Count) error(s)" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  X $e" -ForegroundColor Red }
    if ($warnings.Count -gt 0) {
        Write-Host ""
        foreach ($w in $warnings) { Write-Host "  ! $w" -ForegroundColor Yellow }
    }
}
Write-Host "========================================" -ForegroundColor Cyan

exit $errors.Count

$ErrorActionPreference = 'Stop'

$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskWorkflow = Get-Content -Raw -LiteralPath (Join-Path $taskRoot '.github/workflows/php-compatibility.yml')
$taskManifest = [xml](Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'extension.xml'))
$taskModule = Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'module.combodo-powerbi-integration.php')
$taskBuild = Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'scripts/build-release.ps1')

$taskRequiredPhp = @('7.0.8', '7.1', '7.2', '7.3', '7.4', '8.0', '8.1', '8.2', '8.3', '8.4', '8.5')
$taskMatrixMatch = [regex]::Match($taskWorkflow, '(?ms)^  php-matrix:.*?(?=^  [A-Za-z0-9_-]+:|\z)')
if (-not $taskMatrixMatch.Success) {
    throw 'Blocking PHP matrix job is missing.'
}
$taskMatrix = $taskMatrixMatch.Value
if ($taskMatrix -notmatch '(?m)^    name: PHP \$\{\{ matrix\.php \}\} \(Docker\)\s*$') {
    throw 'Blocking PHP matrix must be the Docker job.'
}
if ($taskMatrix -notmatch '(?m)^\s+docker run --rm\s*$') {
    throw 'Blocking PHP matrix must execute its contract in Docker.'
}
if ($taskMatrix -match '(?m)^\s+continue-on-error:') {
    throw 'Blocking PHP matrix must not allow failures.'
}
foreach ($taskVersion in $taskRequiredPhp) {
    if ($taskMatrix -notmatch ('(?m)^\s+- "' + [regex]::Escape($taskVersion) + '"\s*$')) {
        throw "Blocking Docker matrix is missing PHP $taskVersion."
    }
}
$taskNightlyMatch = [regex]::Match($taskWorkflow, '(?ms)^  php-nightly:.*?(?=^  [A-Za-z0-9_-]+:|\z)')
if (-not $taskNightlyMatch.Success) {
    throw 'PHP 8.6 must remain a separate informational job.'
}
$taskNightly = $taskNightlyMatch.Value
if ($taskNightly -notmatch '(?m)^    name: PHP 8\.6 nightly \(informational\)\s*$' -or
    $taskNightly -notmatch '(?m)^    continue-on-error: true\s*$') {
    throw 'PHP 8.6 must remain a separate informational continue-on-error job.'
}
if ($taskMatrix -match '(?m)^\s+- "8\.6"\s*$') {
    throw 'PHP 8.6 must not be part of the blocking Docker matrix.'
}
if ($taskNightly -notmatch '(?m)^          php-version: "8\.6"\s*$' -or
    $taskNightly -notmatch '(?m)^          php -l module\.combodo-powerbi-integration\.php') {
    throw 'The informational PHP 8.6 job must install and execute PHP 8.6.'
}
if ([string]$taskManifest.extension.version -ne '1.1.2') {
    throw 'extension.xml must declare version 1.1.2.'
}
if ($taskModule -notmatch "combodo-powerbi-integration/1\.1\.2") {
    throw 'module registration must declare version 1.1.2.'
}
$taskExpectedBuildLines = @(
    '$taskVersionRoot = [System.IO.Path]::GetFullPath((Join-Path $taskDistRoot ''combodo-powerbi-integration-1.1.2''))',
    '$taskArchivePath = [System.IO.Path]::GetFullPath((Join-Path $taskDistRoot ''combodo-powerbi-integration-1.1.2.zip''))'
)
foreach ($taskExpectedLine in $taskExpectedBuildLines) {
    if ($taskBuild -notmatch ('(?m)^' + [regex]::Escape($taskExpectedLine) + '\s*$')) {
        throw "Release packaging assignment is not exact: $taskExpectedLine"
    }
}
if ($taskBuild -notmatch "write-deterministic-zip\.ps1") {
    throw 'Release archives must use the cross-platform deterministic ZIP writer.'
}
Write-Output 'PASS: release metadata is synchronized for PHP 8.5 and extension 1.1.2.'

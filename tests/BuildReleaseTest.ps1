$ErrorActionPreference = 'Stop'

$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskBuildScript = Join-Path $taskRoot 'scripts/build-release.ps1'
$taskArchive = Join-Path $taskRoot 'dist/combodo-powerbi-integration-1.1.0.zip'

if (-not (Test-Path -LiteralPath $taskBuildScript -PathType Leaf)) {
	throw 'Release build script is missing.'
}

& $taskBuildScript
if (-not (Test-Path -LiteralPath $taskArchive -PathType Leaf)) {
	throw 'Release archive was not created.'
}
$taskFirstHash = (Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash

& $taskBuildScript
$taskSecondHash = (Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash
if ($taskFirstHash -ne $taskSecondHash) {
	throw 'Repeated builds must produce the same SHA-256 hash.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskArchive)
try {
	$taskEntries = @($taskZip.Entries | ForEach-Object { $_.FullName })
	$taskRequired = @(
		'combodo-powerbi-integration/extension.xml',
		'combodo-powerbi-integration/module.combodo-powerbi-integration.php',
		'combodo-powerbi-integration/data/en_us.data.combodo-powerbi-integration.xml'
	)
	foreach ($taskEntry in $taskRequired) {
		if ($taskEntries -notcontains $taskEntry) {
			throw "Release archive is missing $taskEntry."
		}
	}
	$taskForbidden = @('.github/', 'docs/', 'scripts/', 'tests/', '.git/')
	foreach ($taskEntry in $taskEntries) {
		foreach ($taskPrefix in $taskForbidden) {
			if ($taskEntry -like "combodo-powerbi-integration/$taskPrefix*") {
				throw "Release archive contains source-only entry $taskEntry."
			}
		}
	}
} finally {
	$taskZip.Dispose()
}

Write-Output "PASS: deterministic release archive $taskFirstHash"

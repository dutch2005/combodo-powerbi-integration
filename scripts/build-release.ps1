[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskManifestPath = Join-Path $taskRoot 'extension.xml'
$taskModulePath = Join-Path $taskRoot 'module.combodo-powerbi-integration.php'
$taskManifest = [xml](Get-Content -Raw -LiteralPath $taskManifestPath)
$taskManifestVersion = [string]$taskManifest.extension.version
$taskModuleText = Get-Content -Raw -LiteralPath $taskModulePath
$taskModuleMatch = [regex]::Match($taskModuleText, "'combodo-powerbi-integration/([^']+)'" )

if (-not $taskModuleMatch.Success) {
	throw 'Unable to read the registered module version.'
}
$taskModuleVersion = $taskModuleMatch.Groups[1].Value
if ($taskManifestVersion -ne '1.1.0' -or $taskModuleVersion -ne '1.1.0') {
	throw "Release versions must both be 1.1.0 (manifest=$taskManifestVersion, module=$taskModuleVersion)."
}

$taskDistRoot = [System.IO.Path]::GetFullPath((Join-Path $taskRoot 'dist'))
$taskVersionRoot = [System.IO.Path]::GetFullPath((Join-Path $taskDistRoot 'combodo-powerbi-integration-1.1.0'))
$taskPackageRoot = Join-Path $taskVersionRoot 'combodo-powerbi-integration'
$taskArchivePath = [System.IO.Path]::GetFullPath((Join-Path $taskDistRoot 'combodo-powerbi-integration-1.1.0.zip'))
$taskDistPrefix = $taskDistRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$taskRootPrefix = $taskRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

function Assert-NoTaskReparsePoint
{
	param([Parameter(Mandatory)][string]$Path)

	$taskCurrentPath = $Path
	while ($taskCurrentPath.StartsWith($taskRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		if (Test-Path -LiteralPath $taskCurrentPath) {
			$taskItem = Get-Item -LiteralPath $taskCurrentPath -Force
			if (0 -ne ($taskItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
				throw "Refusing to use reparse or symbolic link path: $taskCurrentPath"
			}
		}
		$taskParentPath = Split-Path -Parent $taskCurrentPath
		if ($taskParentPath -eq $taskCurrentPath) {
			break
		}
		$taskCurrentPath = $taskParentPath
	}
}

if (-not $taskVersionRoot.StartsWith($taskDistPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
	throw 'Refusing to stage outside the repository dist directory.'
}
if ((Split-Path -Parent $taskArchivePath) -ne $taskDistRoot) {
	throw 'Refusing to write the archive outside the repository dist directory.'
}
Assert-NoTaskReparsePoint -Path $taskVersionRoot
Assert-NoTaskReparsePoint -Path $taskArchivePath

if (Test-Path -LiteralPath $taskVersionRoot) {
	Remove-Item -LiteralPath $taskVersionRoot -Recurse -Force
}
if (Test-Path -LiteralPath $taskArchivePath) {
	Remove-Item -LiteralPath $taskArchivePath -Force
}
New-Item -ItemType Directory -Path $taskPackageRoot -Force | Out-Null

$taskRuntimeFiles = @(
	'extension.xml',
	'module.combodo-powerbi-integration.php',
	'model.combodo-powerbi-integration.php',
	'datamodel.combodo-powerbi-integration.xml',
	'en.dict.combodo-powerbi-integration.php',
	'license.txt',
	'data/en_us.data.combodo-powerbi-integration.xml'
)

foreach ($taskRelativePath in $taskRuntimeFiles) {
	$taskSourcePath = Join-Path $taskRoot $taskRelativePath
	if (-not (Test-Path -LiteralPath $taskSourcePath -PathType Leaf)) {
		throw "Required runtime file is missing: $taskRelativePath"
	}
	$taskDestinationPath = Join-Path $taskPackageRoot $taskRelativePath
	New-Item -ItemType Directory -Path (Split-Path -Parent $taskDestinationPath) -Force | Out-Null
	$taskText = [System.IO.File]::ReadAllText($taskSourcePath)
	$taskText = $taskText.Replace("`r`n", "`n").Replace("`r", "`n")
	$taskUtf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
	[System.IO.File]::WriteAllText($taskDestinationPath, $taskText, $taskUtf8WithoutBom)
}

Add-Type -AssemblyName System.IO.Compression
$taskArchiveStream = [System.IO.File]::Open(
	$taskArchivePath,
	[System.IO.FileMode]::CreateNew,
	[System.IO.FileAccess]::ReadWrite,
	[System.IO.FileShare]::None
)
$taskArchive = [System.IO.Compression.ZipArchive]::new(
	$taskArchiveStream,
	[System.IO.Compression.ZipArchiveMode]::Create,
	$false
)
$taskTimestamp = [System.DateTimeOffset]::Parse('2000-01-01T00:00:00Z')

try {
	$taskFiles = Get-ChildItem -LiteralPath $taskPackageRoot -File -Recurse | Sort-Object FullName
	foreach ($taskFile in $taskFiles) {
		$taskRelativePath = $taskFile.FullName.Substring($taskPackageRoot.Length + 1).Replace('\', '/')
		$taskEntryName = 'combodo-powerbi-integration/' + $taskRelativePath
		$taskEntry = $taskArchive.CreateEntry($taskEntryName, [System.IO.Compression.CompressionLevel]::Optimal)
		$taskEntry.LastWriteTime = $taskTimestamp
		$taskInput = [System.IO.File]::OpenRead($taskFile.FullName)
		$taskOutput = $taskEntry.Open()
		try {
			$taskInput.CopyTo($taskOutput)
		} finally {
			$taskOutput.Dispose()
			$taskInput.Dispose()
		}
	}
} finally {
	$taskArchive.Dispose()
	$taskArchiveStream.Dispose()
}

$taskHash = Get-FileHash -LiteralPath $taskArchivePath -Algorithm SHA256
Write-Output "Built $taskArchivePath"
Write-Output "SHA256 $($taskHash.Hash)"

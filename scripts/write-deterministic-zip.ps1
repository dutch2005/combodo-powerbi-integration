[CmdletBinding()]
param(
	[Parameter(Mandatory)][string]$SourceRoot,
	[Parameter(Mandatory)][string]$Destination,
	[Parameter(Mandatory)][string]$EntryPrefix
)

$ErrorActionPreference = 'Stop'

function Get-Crc32([byte[]]$Bytes)
{
	[uint32]$taskCrc = [uint32]::MaxValue
	[uint32]$taskPolynomial = [Convert]::ToUInt32('EDB88320', 16)
	foreach ($taskByte in $Bytes) {
		$taskCrc = [uint32]($taskCrc -bxor [uint32]$taskByte)
		for ($taskBit = 0; $taskBit -lt 8; $taskBit++) {
			if (0 -ne ($taskCrc -band 1)) {
				$taskCrc = [uint32](($taskCrc -shr 1) -bxor $taskPolynomial)
			} else {
				$taskCrc = [uint32]($taskCrc -shr 1)
			}
		}
	}
	return [uint32]($taskCrc -bxor [uint32]::MaxValue)
}

$taskSource = (Resolve-Path -LiteralPath $SourceRoot).Path
$taskSourcePrefix = $taskSource.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$taskFiles = @(Get-ChildItem -LiteralPath $taskSource -File -Recurse)
$taskRelativePaths = [string[]]@($taskFiles | ForEach-Object { $_.FullName.Substring($taskSourcePrefix.Length).Replace('\', '/') })
[array]::Sort($taskRelativePaths, [System.StringComparer]::Ordinal)

if ($taskRelativePaths.Count -gt [uint16]::MaxValue) { throw 'ZIP64 entry counts are not supported.' }
$taskEncoding = [System.Text.UTF8Encoding]::new($false)
$taskRecords = [System.Collections.Generic.List[object]]::new()
$taskStream = [System.IO.File]::Open($Destination, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
$taskWriter = [System.IO.BinaryWriter]::new($taskStream, $taskEncoding, $false)

try {
	foreach ($taskRelativePath in $taskRelativePaths) {
		$taskEntryName = $EntryPrefix.TrimEnd('/') + '/' + $taskRelativePath
		$taskNameBytes = $taskEncoding.GetBytes($taskEntryName)
		$taskData = [System.IO.File]::ReadAllBytes((Join-Path $taskSource $taskRelativePath))
		if ($taskNameBytes.Length -gt [uint16]::MaxValue -or $taskData.LongLength -gt [uint32]::MaxValue) { throw "ZIP64 is not supported: $taskEntryName" }
		$taskOffset = $taskStream.Position
		$taskCrc = Get-Crc32 $taskData

		$taskWriter.Write([uint32]0x04034B50)
		$taskWriter.Write([uint16]20)
		$taskWriter.Write([uint16]0x0800)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint16]0x2821)
		$taskWriter.Write([uint32]$taskCrc)
		$taskWriter.Write([uint32]$taskData.Length)
		$taskWriter.Write([uint32]$taskData.Length)
		$taskWriter.Write([uint16]$taskNameBytes.Length)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write($taskNameBytes)
		$taskWriter.Write($taskData)
		$taskRecords.Add([pscustomobject]@{ Name = $taskNameBytes; Data = $taskData; Crc = $taskCrc; Offset = $taskOffset })
	}

	$taskCentralOffset = $taskStream.Position
	foreach ($taskRecord in $taskRecords) {
		$taskWriter.Write([uint32]0x02014B50)
		$taskWriter.Write([uint16]20)
		$taskWriter.Write([uint16]20)
		$taskWriter.Write([uint16]0x0800)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint16]0x2821)
		$taskWriter.Write([uint32]$taskRecord.Crc)
		$taskWriter.Write([uint32]$taskRecord.Data.Length)
		$taskWriter.Write([uint32]$taskRecord.Data.Length)
		$taskWriter.Write([uint16]$taskRecord.Name.Length)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint16]0)
		$taskWriter.Write([uint32]0)
		$taskWriter.Write([uint32]$taskRecord.Offset)
		$taskWriter.Write($taskRecord.Name)
	}
	$taskCentralSize = $taskStream.Position - $taskCentralOffset

	$taskWriter.Write([uint32]0x06054B50)
	$taskWriter.Write([uint16]0)
	$taskWriter.Write([uint16]0)
	$taskWriter.Write([uint16]$taskRecords.Count)
	$taskWriter.Write([uint16]$taskRecords.Count)
	$taskWriter.Write([uint32]$taskCentralSize)
	$taskWriter.Write([uint32]$taskCentralOffset)
	$taskWriter.Write([uint16]0)
} finally {
	$taskWriter.Dispose()
}

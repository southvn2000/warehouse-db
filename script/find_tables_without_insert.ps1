$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path

$tableDefs = @()
Get-ChildItem -Path (Join-Path $root 'Tables') -Recurse -File -Filter *.sql | ForEach-Object {
  $name = $_.Name
  if ($name -match '^(?<schema>[^\.]+)\.(?<table>.+)\.Table\.sql$') {
    $schema = $matches['schema']
    $table = $matches['table']
    $tableDefs += [PSCustomObject]@{
      Schema = $schema
      Table = $table
      FullName = ($schema + '.' + $table).ToLowerInvariant()
      Path = $_.FullName
    }
  }
}

$insertTargets = New-Object 'System.Collections.Generic.HashSet[string]'
$insertTableOnly = New-Object 'System.Collections.Generic.HashSet[string]'
$insertRegex = [regex]'(?is)\binsert\s+(?:into\s+)?(?<target>[\[\]A-Za-z0-9_#@\.]+)'

Get-ChildItem -Path $root -Recurse -File -Filter *.StoredProcedure.sql | ForEach-Object {
  $content = Get-Content -Path $_.FullName -Raw
  foreach ($m in $insertRegex.Matches($content)) {
    $raw = $m.Groups['target'].Value
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }

    $norm = $raw -replace '\[', '' -replace '\]', ''
    if ($norm.StartsWith('#') -or $norm.StartsWith('@')) { continue }

    $parts = $norm.Split('.')
    if ($parts.Count -ge 2) {
      $schema = $parts[$parts.Count - 2]
      $table = $parts[$parts.Count - 1]
      if ($schema -and $table) {
        [void]$insertTargets.Add(($schema + '.' + $table).ToLowerInvariant())
        [void]$insertTableOnly.Add($table.ToLowerInvariant())
      }
    }
    else {
      [void]$insertTableOnly.Add($norm.ToLowerInvariant())
    }
  }
}

$missing = $tableDefs | Where-Object {
  -not $insertTargets.Contains($_.FullName) -and -not $insertTableOnly.Contains($_.Table.ToLowerInvariant())
} | Sort-Object FullName

Write-Output "TABLE_DEF_COUNT=$($tableDefs.Count)"
Write-Output "INSERT_TARGET_2PART_COUNT=$($insertTargets.Count)"
Write-Output "INSERT_TARGET_TABLE_ONLY_COUNT=$($insertTableOnly.Count)"
Write-Output "MISSING_COUNT=$($missing.Count)"
$missing | ForEach-Object { $_.FullName }

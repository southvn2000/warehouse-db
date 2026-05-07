$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path

$tables = @(
  'dbo.apiendpoint','dbo.connote','dbo.country','dbo.cpitemsdomestic','dbo.cpmanifest',
  'dbo.cpshipmentdomestic','dbo.createkitorder','dbo.createkitorderline','dbo.logfile',
  'dbo.mobileversioninfo','dbo.numberingsequances','dbo.pickingresult','dbo.reportdefinition',
  'dbo.reportscheduleparameter','dbo.reportstockonhand','dbo.reportwidget','dbo.securitylog',
  'dbo.setting','dbo.tarektest','dbo.tenantlog','dbo.tenantpermission','dbo.tenantsectionpermission',
  'dbo.uldlabelfilemapping','dbo.uldprefix','dbo.useripaddress','dbo.weather','dbo.widget'
)

$spFiles = Get-ChildItem -Path $root -Recurse -File -Filter *.StoredProcedure.sql

foreach ($t in $tables) {
  $parts = $t.Split('.')
  $schema = $parts[0]
  $table = $parts[1]

  Write-Output ("### " + $t)

  $hits = @()
  $tableEsc = [regex]::Escape($table)
  $schemaEsc = [regex]::Escape($schema)

  # Patterns for common operations against a table
  $patterns = @(
    @{ Op = 'SELECT'; Rx = [regex]("(?is)(?:from|join)\s+" + $schemaEsc + "\." + $tableEsc + "\b|(?:from|join)\s+" + $tableEsc + "\b") },
    @{ Op = 'UPDATE'; Rx = [regex]("(?is)\bupdate\s+" + $schemaEsc + "\." + $tableEsc + "\b|\bupdate\s+" + $tableEsc + "\b") },
    @{ Op = 'DELETE'; Rx = [regex]("(?is)\bdelete\s+from\s+" + $schemaEsc + "\." + $tableEsc + "\b|\bdelete\s+from\s+" + $tableEsc + "\b") },
    @{ Op = 'MERGE'; Rx = [regex]("(?is)\bmerge\s+into\s+" + $schemaEsc + "\." + $tableEsc + "\b|\bmerge\s+into\s+" + $tableEsc + "\b") },
    @{ Op = 'INSERT'; Rx = [regex]("(?is)\binsert\s+(?:into\s+)?" + $schemaEsc + "\." + $tableEsc + "\b|\binsert\s+(?:into\s+)?" + $tableEsc + "\b") }
  )

  foreach ($f in $spFiles) {
    $content = (Get-Content -Path $f.FullName -Raw) -replace '\[', '' -replace '\]', ''
    $proc = [IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetFileNameWithoutExtension($f.Name))

    $ops = New-Object System.Collections.Generic.List[string]
    foreach ($p in $patterns) {
      if ($p.Rx.IsMatch($content)) {
        [void]$ops.Add($p.Op)
      }
    }

    if ($ops.Count -gt 0) {
      $uniqueOps = $ops | Sort-Object -Unique
      $hits += [PSCustomObject]@{
        Procedure = $proc
        Operations = ($uniqueOps -join ', ')
      }
    }
  }

  if ($hits.Count -eq 0) {
    Write-Output 'NO_USAGE'
  }
  else {
    $hits | Sort-Object Procedure | ForEach-Object {
      Write-Output ("- " + $_.Procedure + " :: " + $_.Operations)
    }
  }

  Write-Output ''
}

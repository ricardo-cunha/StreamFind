$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root '.venv\Scripts\python.exe'
$catalogue = Join-Path $PSScriptRoot 'ontology'
$catalogueFiles = @(Get-ChildItem -LiteralPath $catalogue -Recurse -Filter '*.ttl' | ForEach-Object FullName)
$vocabulary = Join-Path $PSScriptRoot 'ontology/vocabulary.ttl'
$shapes = Join-Path $PSScriptRoot 'ontology/shapes.ttl'
$manifest = Join-Path $root 'tests\fixtures\semantic\manifest.json'
$projection = Join-Path $PSScriptRoot 'generated\catalogue.json'

foreach ($path in @($catalogue, $vocabulary, $shapes, $manifest, $projection)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing semantic catalogue file: $path"
    }
}

if (-not (Test-Path -LiteralPath $python)) {
    throw "Missing repository Python environment: $python"
}

foreach ($token in @('sfcore:create', 'sfcore:getWorkflow', 'sfcore:getWorkflowExecution', 'sfcore:runMethod')) {
    if (-not (Select-String -LiteralPath $catalogueFiles -Pattern ([regex]::Escape($token)) -Quiet)) {
        throw "Missing catalogue declaration: $token"
    }
}

foreach ($token in @('skos:prefLabel', 'skos:definition', 'sh:NodeShape', 'sh:minCount')) {
    if (-not (Select-String -LiteralPath ($catalogueFiles + @($vocabulary, $shapes)) -Pattern ([regex]::Escape($token)) -Quiet)) {
        throw "Missing semantic validation construct: $token"
    }
}

$fixture = Join-Path $root 'tests\data\project\project_conformance.json'
if (-not (Test-Path -LiteralPath $fixture)) {
    throw "Missing referenced fixture: $fixture"
}

& $python (Join-Path $PSScriptRoot 'validate_semantic.py')
if ($LASTEXITCODE -ne 0) {
    throw 'RDF/TriG and SHACL validation failed'
}
& $python (Join-Path $PSScriptRoot 'generate_projection.py') --check
if ($LASTEXITCODE -ne 0) {
    throw 'Generated semantic projection is stale'
}

Write-Output 'semantic catalogue validation passed'

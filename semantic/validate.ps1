$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root '.venv\Scripts\python.exe'
$catalogue = Join-Path $PSScriptRoot 'streamfind.trig'
$vocabulary = Join-Path $PSScriptRoot 'vocabulary.ttl'
$shapes = Join-Path $PSScriptRoot 'shapes.trig'
$manifest = Join-Path $PSScriptRoot 'fixtures\manifest.json'

foreach ($path in @($catalogue, $vocabulary, $shapes, $manifest)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing semantic catalogue file: $path"
    }
}

if (-not (Test-Path -LiteralPath $python)) {
    throw "Missing repository Python environment: $python"
}

foreach ($token in @('sfcore:create', 'sfcore:getWorkflow', 'sfcore:runMethod', 'sfcore:projectConformance')) {
    if (-not (Select-String -LiteralPath $catalogue -Pattern ([regex]::Escape($token)) -Quiet)) {
        throw "Missing catalogue declaration: $token"
    }
}

foreach ($token in @('skos:prefLabel', 'skos:definition', 'sh:NodeShape', 'sh:minCount')) {
    if (-not (Select-String -LiteralPath $catalogue, $vocabulary, $shapes -Pattern ([regex]::Escape($token)) -Quiet)) {
        throw "Missing semantic validation construct: $token"
    }
}

$fixture = Join-Path $root 'core\tests\fixtures\project_conformance.json'
if (-not (Test-Path -LiteralPath $fixture)) {
    throw "Missing referenced fixture: $fixture"
}

& $python (Join-Path $PSScriptRoot 'validate_semantic.py')
if ($LASTEXITCODE -ne 0) {
    throw 'RDF/TriG and SHACL validation failed'
}

Write-Output 'semantic catalogue validation passed'

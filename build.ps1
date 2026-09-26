$ErrorActionPreference = "Stop"

$buildDirectory = Join-Path $PSScriptRoot "build"
if (Test-Path $buildDirectory) {
    Remove-Item $buildDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $buildDirectory | Out-Null
python -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot "requirements.txt") -t $buildDirectory
Copy-Item (Join-Path $PSScriptRoot "handler.py") $buildDirectory
$ErrorActionPreference = "Stop"
$php = (Get-Command php).Source
$phpDir = Split-Path $php -Parent
$extDir = Join-Path $phpDir "ext"
& $php -d "extension_dir=$extDir" -d extension=pdo_mysql (Join-Path $PSScriptRoot "scripts\setup_test_db.php")
exit $LASTEXITCODE

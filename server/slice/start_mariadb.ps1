$ErrorActionPreference = "Stop"
$base = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "tools\mariadb\mariadb-11.4.9-winx64"
$data = Join-Path $PSScriptRoot "testdb\data"
$log = Join-Path $PSScriptRoot "testdb\mariadb.log"

if (-not (Test-Path (Join-Path $base "bin\mariadbd.exe"))) {
    throw "未找到便携 MariaDB：$base"
}
if (-not (Test-Path $data)) {
    throw "未找到测试数据目录：$data，请先运行 mysql_install_db"
}

& (Join-Path $base "bin\mariadbd.exe") "--defaults-file=$data\my.ini" "--basedir=$base" "--datadir=$data" "--console" "--skip-name-resolve"

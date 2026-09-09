param([string]$DevEcoHome = $env:DEVECO_STUDIO_HOME)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($DevEcoHome)) {
  throw 'Pass -DevEcoHome with the installed DevEco Studio directory.'
}
$taskProject = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskNode = Join-Path $DevEcoHome 'tools/node/node.exe'
$taskHvigor = Join-Path $DevEcoHome 'tools/hvigor/bin/hvigorw.js'
if (!(Test-Path -LiteralPath $taskNode) -or !(Test-Path -LiteralPath $taskHvigor)) {
  throw 'The selected DevEco Studio installation is missing Node or Hvigor.'
}
$env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
$env:NODE_HOME = Join-Path $DevEcoHome 'tools/node'
$env:PATH = "$env:JAVA_HOME/bin;$env:NODE_HOME;$env:PATH"
Push-Location -LiteralPath $taskProject
try {
  & $taskNode $taskHvigor assembleHap --mode module -p product=default --no-daemon
  $taskExit = $LASTEXITCODE
} finally { Pop-Location }
exit $taskExit

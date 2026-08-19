$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'RenderPromo.cs'
$buildDirectory = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\.dart_tool')).Path 'promo-renderer'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
$executable = Join-Path $buildDirectory 'RenderPromo.exe'
$windowsMetadata = 'C:\Program Files (x86)\Windows Kits\10\UnionMetadata\10.0.26100.0\Windows.winmd'
$runtime = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.WindowsRuntime.dll'
$systemRuntime = 'C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\Facades\System.Runtime.dll'
$compiler = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'

& $compiler /nologo /optimize+ /target:exe /out:$executable /reference:$windowsMetadata /reference:$runtime /reference:$systemRuntime $source
if ($LASTEXITCODE -ne 0) { throw 'Could not compile the local promo renderer.' }

& $executable $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not render the promo video.' }

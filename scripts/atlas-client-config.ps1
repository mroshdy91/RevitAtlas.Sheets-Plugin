# Export a secret-free connection fragment; never replace an existing client config.
[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('generic','vscode','opencode','continue','antigravity')][string]$Client,
 [Parameter(Mandatory)][ValidateSet('core','family','sheets','annotations')][string]$Surface,
 [Parameter(Mandatory)][string]$OutputPath
)
$ErrorActionPreference='Stop'
$adapter=Join-Path $PSScriptRoot 'atlas-mcp.ps1'
if(!(Test-Path -LiteralPath $adapter -PathType Leaf)){throw 'ADAPTER_MISSING'}
$name='atlas_'+$Surface
if($Client -eq 'antigravity'){
 $root=Split-Path $PSScriptRoot -Parent
 $manifest=Get-Content -LiteralPath (Join-Path $root 'plugin.json') -Raw | ConvertFrom-Json
 if($manifest.name -cne ('atlas-'+$Surface)){throw 'SURFACE_MISMATCH: export from the matching plugin package.'}
 $full=[IO.Path]::GetFullPath($OutputPath)
 if(Test-Path -LiteralPath $full){throw 'OUTPUT_EXISTS: choose a fresh plugin directory.'}
 [void](New-Item -ItemType Directory -Path $full -ErrorAction Stop)
 foreach($entry in @('skills','scripts','CLIENTS.md','FREE-USE-TERMS.txt','runtime-release.json','RUNTIME.md')){
  $source=Join-Path $root $entry
  if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination $full -Recurse -ErrorAction Stop}
 }
 $utf8=[Text.UTF8Encoding]::new($false)
 [IO.File]::WriteAllText((Join-Path $full 'plugin.json'),(@{name=$manifest.name;description=$manifest.description}|ConvertTo-Json),$utf8)
 $arguments=@('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $full 'scripts/atlas-mcp.ps1'),'-Surface',$Surface)
 [IO.File]::WriteAllText((Join-Path $full 'mcp_config.json'),(@{mcpServers=@{$name=@{command='powershell.exe';args=$arguments}}}|ConvertTo-Json -Depth 10),$utf8)
 @{status='exported';client=$Client;path=$full;contains_credentials=$false;next_action='Install this local plugin using agy plugin install, or export directly into the documented plugin directory. Keep this export directory: the connection uses its absolute script path. Re-export to a fresh directory for upgrades.'}|ConvertTo-Json
 exit 0
}
$arguments=@('-NoLogo','-NoProfile','-NonInteractive','-File',([IO.Path]::GetFullPath($adapter)),'-Surface',$Surface)
$server=[ordered]@{command='powershell.exe';args=$arguments}
switch($Client){
 'generic' {$result=@{mcpServers=@{$name=$server}}}
 'vscode' {$result=@{servers=@{$name=(@{type='stdio'}+$server)}}}
 'opencode' {$result=@{mcp=@{$name=@{type='local';command=(@('powershell.exe')+$arguments);enabled=$true}}}}
 'continue' {$result=@{name=('Atlas '+$Surface);version='0.1.0-beta.4';schema='v1';mcpServers=@((@{name=$name}+$server))}}
}
$full=[IO.Path]::GetFullPath($OutputPath)
$file=[IO.File]::Open($full,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($result|ConvertTo-Json -Depth 10)+"`n")
 $file.Write($bytes,0,$bytes.Length)
}finally{$file.Dispose()}
@{status='exported';client=$Client;surface=$Surface;path=$full;contains_credentials=$false;client_configuration_modified=$false;next_action='Merge only this named server using the client-supported configuration flow. Preserve other servers. Install/load the matching Atlas skills as documented.'}|ConvertTo-Json

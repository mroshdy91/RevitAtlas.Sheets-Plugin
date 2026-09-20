# Public transport adapter only. Native implementation stays in the shared Atlas runtime.
# Windows PowerShell 5.1+; no SDK, node runtime, token entry, or background service.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('core','family','sheets','annotations')][string]$Surface)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Net.Http
$handler=[Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect=$false
$handler.UseProxy=$false
$client=[Net.Http.HttpClient]::new($handler)
$client.Timeout=[TimeSpan]::FromSeconds(150)
$endpoint='http://127.0.0.1:18765/'+$Surface+'/mcp'
$protocol='2025-03-26'

function Write-AtlasError($Id,[int]$Code,[string]$Message){
    $value=@{jsonrpc='2.0';id=$Id;error=@{code=$Code;message=$Message}}
    [Console]::Out.WriteLine(($value|ConvertTo-Json -Depth 8 -Compress))
    [Console]::Out.Flush()
}
try{
    while($null -ne ($line=[Console]::In.ReadLine())){
        if([string]::IsNullOrWhiteSpace($line)){continue}
        $request=$null;$hasId=$false;$message=$null;$response=$null
        try{
            if($line.Length -gt 16777216){Write-AtlasError $null -32600 'REQUEST_TOO_LARGE';continue}
            try{$request=ConvertFrom-Json -InputObject $line}catch{Write-AtlasError $null -32700 'Invalid JSON';continue}
            if($null -eq $request -or $request -is [array] -or $request.jsonrpc -cne '2.0' -or !($request.method -is [string])){
                Write-AtlasError $null -32600 'Invalid JSON-RPC request';continue
            }
            $hasId=$null -ne $request.PSObject.Properties['id']
            # A scoped credential supplied by the client always wins. Never retry
            # an invalid scoped credential using the account's full-access token.
            $token=[Environment]::GetEnvironmentVariable('ATLAS_BEARER_TOKEN','Process')
            if(!$token){$token=[Environment]::GetEnvironmentVariable('ATLAS_BEARER_TOKEN','User')}
            if(!$token){if($hasId){Write-AtlasError $request.id -32001 'ATLAS_SETUP_REQUIRED: use the installed Atlas Core setup skill.'};continue}
            $message=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post,$endpoint)
            $message.Headers.Authorization=[Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$token)
            [void]$message.Headers.TryAddWithoutValidation('Accept','application/json, text/event-stream')
            # Initialization negotiates the version in its own body. Supplying an
            # unrelated default header makes newer clients fail before negotiation.
            if($request.method -cne 'initialize'){
                [void]$message.Headers.TryAddWithoutValidation('MCP-Protocol-Version',$protocol)
            }
            $message.Content=[Net.Http.StringContent]::new($line,[Text.Encoding]::UTF8,'application/json')
            $response=$client.SendAsync($message,[Net.Http.HttpCompletionOption]::ResponseContentRead).GetAwaiter().GetResult()
            if(!$response.IsSuccessStatusCode){
                $code=[int]$response.StatusCode
                if($hasId){
                    if($code -eq 401){Write-AtlasError $request.id -32001 'ATLAS_AUTHENTICATION_FAILED: check local setup; no credential fallback was attempted.'}
                    elseif($code -ge 300 -and $code -lt 400){Write-AtlasError $request.id -32002 'ATLAS_REDIRECT_REJECTED: local credentials are never forwarded to another endpoint.'}
                    else{Write-AtlasError $request.id -32002 ('ATLAS_HTTP_'+$code+': inspect Atlas status and recover the original operation; do not repeat a mutation.')}
                }
                continue
            }
            if(!$hasId){continue}
            $body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if($body.Length -gt 67108864){throw 'ATLAS_RESPONSE_TOO_LARGE'}
            $payloads=[Collections.Generic.List[string]]::new()
            if($response.Content.Headers.ContentType.MediaType -eq 'text/event-stream'){
                $data=[Collections.Generic.List[string]]::new()
                foreach($row in ($body -split "`n")){
                    $row=$row.TrimEnd("`r")
                    if($row.StartsWith('data:')){$data.Add($row.Substring(5).TrimStart(' '))}
                    elseif($row.Length -eq 0 -and $data.Count -gt 0){$payloads.Add(($data -join "`n"));$data.Clear()}
                }
                if($data.Count -gt 0){$payloads.Add(($data -join "`n"))}
            }elseif($response.Content.Headers.ContentType.MediaType -eq 'application/json'){$payloads.Add($body)}
            else{throw 'ATLAS_RESPONSE_FORMAT_INVALID'}
            $matched=$false
            foreach($payload in $payloads){
                $value=ConvertFrom-Json -InputObject $payload
                if($value.jsonrpc -cne '2.0'){throw 'ATLAS_RESPONSE_FORMAT_INVALID'}
                if($null -ne $value.PSObject.Properties['id']){
                    # Match both JSON value and type; string "1" is not numeric 1.
                    if((ConvertTo-Json -InputObject $value.id -Compress) -cne (ConvertTo-Json -InputObject $request.id -Compress)){throw 'ATLAS_RESPONSE_ID_MISMATCH'}
                    if($matched){throw 'ATLAS_DUPLICATE_RESPONSE'}
                    $matched=$true
                    if($request.method -ceq 'initialize' -and $value.result.protocolVersion){$protocol=$value.result.protocolVersion}
                }elseif(!$value.method){throw 'ATLAS_RESPONSE_FORMAT_INVALID'}
            }
            if(!$matched){throw 'ATLAS_RESPONSE_MISSING'}
            # Validate the complete reply before emitting any part of it; a malformed
            # later event must not turn one request into both success and error.
            foreach($payload in $payloads){
                [Console]::Out.WriteLine(($payload -replace "`r?`n",' '))
            }
            [Console]::Out.Flush()
        }catch{
            if($hasId){
                # Never log the HTTP request, headers, token, or exception body.
                $reason='ATLAS_CONNECTION_UNAVAILABLE: open Revit after Core setup, then reconnect. If a mutation was dispatched, recover its original operation before retrying.'
                if($_.Exception.Message -match '^ATLAS_[A-Z_]+$'){$reason=$_.Exception.Message}
                Write-AtlasError $request.id -32002 $reason
            }
        }finally{if($response){$response.Dispose()};if($message){$message.Dispose()};$token=$null}
    }
}finally{$client.Dispose();$handler.Dispose()}

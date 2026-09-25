# Public transport adapter only. Native implementation stays in the shared Atlas runtime.
# Windows PowerShell 5.1+; no SDK, node runtime, token entry, or background service.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('core','family','sheets','annotations')][string]$Surface,
      [ValidateSet('v1','v2-candidate')][string]$Interface='v1')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Net.Http
$handler=[Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect=$false
$handler.UseProxy=$false
$handler.MaxConnectionsPerServer=10
$client=[Net.Http.HttpClient]::new($handler)
$client.Timeout=[Threading.Timeout]::InfiniteTimeSpan
$interfacePrefix=if($Interface -eq 'v2-candidate'){'v2/'}else{''}
$endpoint='http://127.0.0.1:18765/'+$interfacePrefix+$Surface+'/mcp'



# Small framework-only helpers keep blocking console/HTTP reads off the pump.
# No runtime dependency, credentials or native implementation is packaged here.
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Concurrent;
public sealed class AtlasAdapterInput {
 public readonly BlockingCollection<string> Lines=new BlockingCollection<string>(16);
 public AtlasAdapterInput(TextReader reader) { Task.Run(()=>{
  try { var line=new StringBuilder(); bool overflow=false; int c;
   while((c=reader.Read())>=0) {
    if(c==10) { Lines.Add(overflow?"__ATLAS_OVERSIZE__":line.ToString().TrimEnd('\r'));line.Clear();overflow=false; }
    else if(!overflow) { if(line.Length>=16777216){overflow=true;line.Clear();}else line.Append((char)c); }
   }
   if(overflow || line.Length>0) Lines.Add(overflow?"__ATLAS_OVERSIZE__":line.ToString());
  } finally { Lines.CompleteAdding(); }
 }); }
}
public sealed class AtlasAdapterBody : Stream {
 readonly Stream source; readonly long maximum; readonly CancellationToken cancellation; readonly CancellationTokenRegistration registration; long count;
 public AtlasAdapterBody(Stream source,long maximum,CancellationToken cancellation){
  this.source=source;this.maximum=maximum;this.cancellation=cancellation;
  // Framework HTTP streams do not all implement cancellable reads. Closing
  // this request's response stream makes the body deadline effective on 5.1.
  registration=cancellation.Register(()=>{try{source.Dispose();}catch{}});
 }
 public override int Read(byte[] buffer,int offset,int size){
  int read=source.ReadAsync(buffer,offset,(int)Math.Min(size,maximum-count+1),cancellation).GetAwaiter().GetResult();
  count+=read;if(count>maximum)throw new IOException("ATLAS_RESPONSE_TOO_LARGE");return read;
 }
 public override bool CanRead{get{return true;}} public override bool CanSeek{get{return false;}} public override bool CanWrite{get{return false;}}
 public override long Length{get{throw new NotSupportedException();}} public override long Position{get{throw new NotSupportedException();}set{throw new NotSupportedException();}}
 public override void Flush(){} public override long Seek(long o,SeekOrigin s){throw new NotSupportedException();}
 public override void SetLength(long v){throw new NotSupportedException();} public override void Write(byte[] b,int o,int c){throw new NotSupportedException();}
 protected override void Dispose(bool disposing){if(disposing){registration.Dispose();source.Dispose();}base.Dispose(disposing);}
}
"@
$Replies=[Collections.Concurrent.ConcurrentQueue[string]]::new()
$Shared=[hashtable]::Synchronized(@{protocol='2025-03-26'})
$InputLines=[AtlasAdapterInput]::new([Console]::In)
$Pool=[RunspaceFactory]::CreateRunspacePool(1,10);$Pool.Open()
$Active=[Collections.Generic.List[object]]::new()
$Pending=[Collections.Generic.List[object]]::new()
$Worker={
param($line,$client,$endpoint,$Replies,$Shared,$Deadline)
$ErrorActionPreference="Stop"
function Write-AtlasError($Id,[int]$Code,[string]$Message){
    $value=@{jsonrpc='2.0';id=$Id;error=@{code=$Code;message=$Message}}
    $Replies.Enqueue(($value|ConvertTo-Json -Depth 8 -Compress))

}
        $request=$null;$hasId=$false;$message=$null;$response=$null;$reader=$null
        try{
            if($line.Length -gt 16777216){Write-AtlasError $null -32600 'REQUEST_TOO_LARGE';return}
            try{$request=ConvertFrom-Json -InputObject $line}catch{Write-AtlasError $null -32700 'Invalid JSON';return}
            if($null -eq $request -or $request -is [array] -or $request.jsonrpc -cne '2.0' -or !($request.method -is [string])){
                Write-AtlasError $null -32600 'Invalid JSON-RPC request';return
            }
            $hasId=$null -ne $request.PSObject.Properties['id']
            # A scoped credential supplied by the client always wins. Never retry
            # an invalid scoped credential using the account's full-access token.
            $token=[Environment]::GetEnvironmentVariable('ATLAS_BEARER_TOKEN','Process')
            if(!$token){$token=[Environment]::GetEnvironmentVariable('ATLAS_BEARER_TOKEN','User')}
            if(!$token){if($hasId){Write-AtlasError $request.id -32001 'ATLAS_SETUP_REQUIRED: use the installed Atlas Core setup skill.'};return}
            $message=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post,$endpoint)
            $message.Headers.Authorization=[Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$token)
            [void]$message.Headers.TryAddWithoutValidation('Accept','application/json, text/event-stream')
            # Initialization negotiates the version in its own body. Supplying an
            # unrelated default header makes newer clients fail before negotiation.
            if($request.method -cne 'initialize'){
                [void]$message.Headers.TryAddWithoutValidation('MCP-Protocol-Version',$Shared.protocol)
            }
            $message.Content=[Net.Http.StringContent]::new($line,[Text.Encoding]::UTF8,'application/json')
            $response=$client.SendAsync($message,[Net.Http.HttpCompletionOption]::ResponseHeadersRead,$Deadline.Token).GetAwaiter().GetResult()
            if(!$response.IsSuccessStatusCode){
                $code=[int]$response.StatusCode
                if($hasId){
                    if($code -eq 401){Write-AtlasError $request.id -32001 'ATLAS_AUTHENTICATION_FAILED: check local setup; no credential fallback was attempted.'}
                    elseif($code -ge 300 -and $code -lt 400){Write-AtlasError $request.id -32002 'ATLAS_REDIRECT_REJECTED: local credentials are never forwarded to another endpoint.'}
                    else{Write-AtlasError $request.id -32002 ('ATLAS_HTTP_'+$code+': inspect Atlas status and recover the original operation; do not repeat a mutation.')}
                }
                return
            }
            if(!$hasId){return}
            $media=$response.Content.Headers.ContentType.MediaType
            if($media -notin @('application/json','text/event-stream')){throw 'ATLAS_RESPONSE_FORMAT_INVALID'}
            # Bound UTF-8 bytes while reading, including an unknown-length stream.
            # A deadline also covers body reads, not only HTTP response headers.
            $stream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $bounded=[AtlasAdapterBody]::new($stream,67108864,$Deadline.Token)
            $reader=[IO.StreamReader]::new($bounded,[Text.UTF8Encoding]::new($false,$true),$false,4096)
            $matched=$false
            $terminal=$null
            $eventData=[Text.StringBuilder]::new()
            do{
                $payload=$null
                if($media -eq 'application/json'){$payload=$reader.ReadToEnd();$eof=$true}
                else{
                    $row=$reader.ReadLine();$eof=$null -eq $row
                    if(!$eof -and $row.StartsWith('data:')){
                        $part=$row.Substring(5);if($part.StartsWith(' ')){$part=$part.Substring(1)}
                        [void]$eventData.AppendLine($part)
                    }elseif(($eof -or $row.Length -eq 0) -and $eventData.Length -gt 0){
                        $payload=$eventData.ToString().TrimEnd("`r","`n");[void]$eventData.Clear()
                    }
                }
                if($null -eq $payload){continue}
                $value=ConvertFrom-Json -InputObject $payload
                if($value.jsonrpc -cne '2.0'){throw 'ATLAS_RESPONSE_FORMAT_INVALID'}
                if($null -ne $value.PSObject.Properties['id']){
                    # Match both JSON value and type; string "1" is not numeric 1.
                    if((ConvertTo-Json -InputObject $value.id -Compress) -cne (ConvertTo-Json -InputObject $request.id -Compress)){throw 'ATLAS_RESPONSE_ID_MISMATCH'}
                    if($matched){throw 'ATLAS_DUPLICATE_RESPONSE'}
                    $matched=$true
                }elseif(!$value.method){throw 'ATLAS_RESPONSE_FORMAT_INVALID'}
                if($null -eq $value.PSObject.Properties['id']){
                    # Notifications may be emitted before EOF; only the terminal
                    # response is held back until duplicate/malformed checks pass.
                    $Replies.Enqueue(($payload -replace "`r?`n",' '))
                }else{$terminal=$payload -replace "`r?`n",' '}
            }while(!$eof)
            if(!$matched){throw 'ATLAS_RESPONSE_MISSING'}
            if($request.method -ceq 'initialize'){
                $negotiated=ConvertFrom-Json -InputObject $terminal
                if($negotiated.result.protocolVersion){$Shared.protocol=[string]$negotiated.result.protocolVersion}
            }
            $Replies.Enqueue($terminal)
        }catch{
            if($hasId){
                # Never log the HTTP request, headers, token, or exception body.
                $reason='ATLAS_CONNECTION_UNAVAILABLE: open Revit after Core setup, then reconnect. If a mutation was dispatched, recover its original operation before retrying.'
                $failure=$_.Exception
                while($failure){
                    if($failure.Message -match '^ATLAS_[A-Z_]+$'){$reason=$failure.Message;break}
                    $failure=$failure.InnerException
                }
                if($Deadline.IsCancellationRequested){$reason='ATLAS_HTTP_WAIT_EXPIRED: recover the original operation; the HTTP deadline does not cancel native work.'}
                Write-AtlasError $request.id -32002 $reason
            }
        }finally{if($reader){$reader.Dispose()};if($response){$response.Dispose()};if($message){$message.Dispose()};$token=$null}
}

function Write-PumpError($Id,[int]$Code,[string]$Message){
 $Replies.Enqueue((@{jsonrpc='2.0';id=$Id;error=@{code=$Code;message=$Message}}|ConvertTo-Json -Depth 8 -Compress))
}
try{
 while(!$InputLines.Lines.IsCompleted -or $Active.Count -gt 0 -or $Pending.Count -gt 0){
  foreach($job in @($Active.ToArray())){
   if($job.handle.IsCompleted){
    try{[void]$job.shell.EndInvoke($job.handle)}catch{if($job.hasId){Write-PumpError $job.id -32002 'ATLAS_CONNECTION_UNAVAILABLE: recover the original operation before retrying.'}}
    finally{$job.deadline.Dispose();$job.shell.Dispose();[void]$Active.Remove($job)}
   }
  }
  $line=$null
  # Bounded intake per pump cycle; active HTTP streams never block input.
  for($i=0;$i -lt 16 -and $InputLines.Lines.TryTake([ref]$line);$i++){
   if([string]::IsNullOrWhiteSpace($line)){continue}
   if($line -ceq '__ATLAS_OVERSIZE__'){Write-PumpError $null -32600 'REQUEST_TOO_LARGE';continue}
   try{$request=ConvertFrom-Json -InputObject $line}catch{Write-PumpError $null -32700 'Invalid JSON';continue}
   if($null -eq $request -or $request -is [array] -or $request.jsonrpc -cne '2.0' -or !($request.method -is [string])){Write-PumpError $null -32600 'Invalid JSON-RPC request';continue}
   $hasId=$null -ne $request.PSObject.Properties['id']
   $control=$request.method -eq 'notifications/cancelled' -or ($request.method -eq 'tools/call' -and $request.params.name -in @('atlas_operation','atlas_status'))
   $capacity=if($control){8}else{16}
   if(@($Pending | Where-Object control -eq $control).Count -ge $capacity){if($hasId){Write-PumpError $request.id -32002 'ATLAS_CLIENT_BUSY: request was not dispatched; observe active operations before retrying.'};continue}
   $Pending.Add(@{line=$line;id=$request.id;hasId=$hasId;control=$control;initialize=$request.method -ceq 'initialize'})
  }
  foreach($item in @($Pending.ToArray())){
   # Initialization is a negotiation barrier, even for pipelined clients.
   if(@($Active | Where-Object initialize).Count -gt 0){break}
   if($item.initialize -and $Active.Count -gt 0){break}
   $limit=if($item.control){2}else{8}
   if(@($Active | Where-Object control -eq $item.control).Count -ge $limit){continue}
   $shell=[PowerShell]::Create();$shell.RunspacePool=$Pool
   $deadline=[Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(150))
   [void]$shell.AddScript($Worker.ToString()).AddArgument($item.line).AddArgument($client).AddArgument($endpoint).AddArgument($Replies).AddArgument($Shared).AddArgument($deadline)
   $item.shell=$shell;$item.deadline=$deadline;$item.handle=$shell.BeginInvoke()
   $Active.Add($item);[void]$Pending.Remove($item)
   if($item.initialize){break}
  }
  $reply=$null
  while($Replies.TryDequeue([ref]$reply)){[Console]::Out.WriteLine($reply);[Console]::Out.Flush()}
  [Threading.Thread]::Sleep(10)
 }
 $reply=$null;while($Replies.TryDequeue([ref]$reply)){[Console]::Out.WriteLine($reply)};[Console]::Out.Flush()
}finally{
 foreach($job in $Active){$job.deadline.Cancel();$job.shell.Dispose();$job.deadline.Dispose()}
 $Pool.Dispose();$client.Dispose();$handler.Dispose()
}

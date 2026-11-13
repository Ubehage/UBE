# Qualifies a repeated ordinary UBE compiler build with retained comparison evidence.
param(
 [Parameter(Mandatory=$true)][string]$InitialCompilerExe,
 [string]$FirstGenerationDirectory = '',
 [string]$SecondGenerationDirectory = '',
 [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe',
 [ValidateSet('0','2')][string]$Optimization = '2'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube compiler rebuild '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$report=New-Object Collections.Generic.List[string]
Write-Output "Evidence: $artifacts"

# Records each successful assertion in both console output and the retained report.
function Record([string]$Text){$report.Add($Text);Write-Output $Text}

# Requires exact bytes, not text normalization or hash equality alone.
function Same-Bytes([string]$First,[string]$Second){
 $a=[IO.File]::ReadAllBytes($First);$b=[IO.File]::ReadAllBytes($Second)
 if($a.Length -ne $b.Length){return $false}
 for($i=0;$i -lt $a.Length;$i++){if($a[$i] -ne $b[$i]){return $false}}
 return $true
}

# Validates source inventory against actual files, successful build logs and fixed assets.
function Check-Package([string]$Directory){
 $directory=[IO.Path]::GetFullPath($Directory)
 foreach($leaf in @('UBE.exe','Compiler.UBE','sources.sha256','build.stdout','build.stderr','llvm/templates.bin','llvm/windows-runtime.ll','llvm/kernel32.def')){
  if(-not [IO.File]::Exists((Join-Path $directory $leaf))){throw "Missing package artifact: $directory/$leaf"}
 }
 if([IO.File]::ReadAllText((Join-Path $directory 'build.stdout'),$encoding) -notmatch '(?m)^BUILD OK\r?$' -or [IO.File]::ReadAllBytes((Join-Path $directory 'build.stderr')).Length -ne 0){throw "Package has no successful build evidence: $directory"}
 $seen=@{}
 foreach($line in [IO.File]::ReadAllLines((Join-Path $directory 'sources.sha256'),$encoding)){
  if($line -notmatch '^([0-9A-F]{64})  ([A-Za-z_][A-Za-z0-9_.-]*\.bas)$'){throw "Malformed source ledger: $directory"}
  $hash=$Matches[1];$leaf=$Matches[2]
  if($seen.ContainsKey($leaf)){throw "Duplicate ledger source: $leaf"};$seen[$leaf]=$true
  if((Get-FileHash -LiteralPath (Join-Path $directory $leaf) -Algorithm SHA256).Hash -cne $hash){throw "Changed package source: $directory/$leaf"}
 }
 $sources=@([IO.File]::ReadAllLines((Join-Path $directory 'Compiler.UBE'),$encoding)|Where-Object{$_ -match '^Source = '})
 if($sources.Count -ne $seen.Count -or $seen.Count -eq 0){throw 'Manifest/ledger source count mismatch'}
 foreach($line in $sources){if($line -notmatch '^Source = "([A-Za-z_][A-Za-z0-9_.-]*\.bas)"$' -or -not $seen.ContainsKey($Matches[1])){throw 'Manifest source missing from ledger'}}
 return $directory
}

# Quotes literal Windows command arguments without invoking a shell.
function Quote-Argument([string]$Value){
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}

# Emits the identical package using one actual compiler, with bounded waiting and exact success markers.
function Emit([string]$Executable,[string]$Manifest,[string]$Name){
 $output=Join-Path $artifacts ($Name+'.ll');$stdout=Join-Path $artifacts ($Name+'.stdout');$stderr=Join-Path $artifacts ($Name+'.stderr')
 $arguments=@('--emit-llvm',$Manifest,$output)
 $p=Start-Process -FilePath $Executable -ArgumentList (($arguments|ForEach-Object{Quote-Argument $_}) -join ' ') -WorkingDirectory $artifacts -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
 try{
  $handle=$p.Handle
  if(-not $p.WaitForExit(600000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Emission timeout: $Name"}
  $p.Refresh()
  if($null -eq $p.ExitCode -or $p.ExitCode -ne 0 -or [IO.File]::ReadAllText($stdout,$encoding) -cne "EMIT OK`r`n" -or [IO.File]::ReadAllBytes($stderr).Length -ne 0){throw "Emission failed: $Name; evidence $artifacts"}
 }finally{$p.Dispose()}
 return $output
}

# Locates only the four COFF timestamp bytes after validating AMD64 PE32+ framing.
function Timestamp-Offset([byte[]]$Bytes){
 if($Bytes.Length -lt 90 -or $Bytes[0] -ne 77 -or $Bytes[1] -ne 90){throw 'Invalid native DOS header'}
 $pe=[BitConverter]::ToInt32($Bytes,60)
 if($pe -lt 64 -or $pe -gt $Bytes.Length-26){throw 'Invalid native PE offset'}
 if([BitConverter]::ToUInt32($Bytes,$pe) -ne 17744 -or [BitConverter]::ToUInt16($Bytes,$pe+4) -ne 34404 -or [BitConverter]::ToUInt16($Bytes,$pe+24) -ne 523){throw 'Expected AMD64 PE32+ executable'}
 return $pe+8
}

try{
 $InitialCompilerExe=[IO.Path]::GetFullPath($InitialCompilerExe)
 if(-not [IO.File]::Exists($InitialCompilerExe)){throw 'Initial compiler is missing'}
 Record ('INITIAL '+$InitialCompilerExe+' SHA256 '+(Get-FileHash -LiteralPath $InitialCompilerExe -Algorithm SHA256).Hash)
 $previous=$InitialCompilerExe;$directories=@()
 foreach($index in 1..2){
  $directory=$FirstGenerationDirectory;if($index -eq 2){$directory=$SecondGenerationDirectory}
  if($directory -eq ''){
   $directory=Join-Path $artifacts ('generation-'+$index)
   & (Join-Path $root 'bootstrap/tools/build-compiler.ps1') -CompilerExe $previous -Destination $directory -Clang $Clang -Optimization $Optimization | Out-Host
   Record "BUILT generation $index using $previous"
  }else{Record "REUSED generation $index supplied explicitly: $directory; predecessor invocation not independently witnessed by this run"}
  $directory=Check-Package $directory
  $directories+=,$directory;$previous=Join-Path $directory 'UBE.exe'
 }
 foreach($leaf in @('Compiler.UBE','sources.sha256','llvm/templates.bin','llvm/windows-runtime.ll','llvm/kernel32.def')){
  if(-not (Same-Bytes (Join-Path $directories[0] $leaf) (Join-Path $directories[1] $leaf))){throw "Generation input differs: $leaf"}
 }
 Record 'PASS: source manifests, verified ledgers and all three support assets are byte-identical'
 foreach($line in [IO.File]::ReadAllLines((Join-Path $directories[0] 'sources.sha256'),$encoding)){
  $null=$line -match '^([0-9A-F]{64})  (.+)$';$hash=$Matches[1];$leaf=$Matches[2]
  $originals=@(foreach($folder in @('compiler/src','std-lib/src/portable','std-lib/src/win-lib')){ $candidate=Join-Path (Join-Path $root $folder) $leaf;if([IO.File]::Exists($candidate)){$candidate} })
  if($originals.Count -ne 1 -or (Get-FileHash -LiteralPath $originals[0] -Algorithm SHA256).Hash -cne $hash){throw "Current repository source differs or is ambiguous: $leaf"}
 }
 foreach($leaf in @('templates.bin','windows-runtime.ll','kernel32.def')){
  if(-not (Same-Bytes (Join-Path $directories[0] ('llvm/'+$leaf)) (Join-Path $root ('compiler/llvm/'+$leaf)))){throw "Current repository native asset differs: $leaf"}
 }
 Record 'PASS: every ledger source and native asset equals current repository bytes'
 $manifest=Join-Path $directories[0] 'Compiler.UBE'
 $firstIR=Emit (Join-Path $directories[0] 'UBE.exe') $manifest 'first'
 $secondIR=Emit (Join-Path $directories[1] 'UBE.exe') $manifest 'second'
 if(-not (Same-Bytes $firstIR $secondIR)){throw 'Successive UBE compiler LLVM differs'}
 Record ('PASS: successive compiler LLVM byte-identical; SHA256 '+(Get-FileHash -LiteralPath $firstIR -Algorithm SHA256).Hash)
 $a=[IO.File]::ReadAllBytes((Join-Path $directories[0] 'UBE.exe'));$b=[IO.File]::ReadAllBytes((Join-Path $directories[1] 'UBE.exe'))
 $ta=Timestamp-Offset $a;$tb=Timestamp-Offset $b
 if($a.Length -ne $b.Length -or $ta -ne $tb){throw 'Native image size or PE layout differs'}
 $differences=New-Object Collections.Generic.List[int]
 for($i=0;$i -lt $a.Length;$i++){if($a[$i] -ne $b[$i]){$differences.Add($i)}}
 if($differences.Count -eq 0){Record 'PASS: native executables raw byte-identical'}else{
  foreach($offset in $differences){if($offset -lt $ta -or $offset -gt $ta+3){throw "Native executable differs outside COFF timestamp at offset $offset"}}
  Record ('PASS: native executables differ only in COFF TimeDateStamp; field offset '+$ta+'; differing offsets '+($differences -join ',')+'; first field '+[BitConverter]::ToString($a,$ta,4)+'; second field '+[BitConverter]::ToString($b,$tb,4))
  for($i=0;$i -lt 4;$i++){$a[$ta+$i]=0;$b[$tb+$i]=0}
  [IO.File]::WriteAllBytes((Join-Path $artifacts 'first.timestamp-zero.exe'),$a)
  [IO.File]::WriteAllBytes((Join-Path $artifacts 'second.timestamp-zero.exe'),$b)
  if(-not (Same-Bytes (Join-Path $artifacts 'first.timestamp-zero.exe') (Join-Path $artifacts 'second.timestamp-zero.exe'))){throw 'Normalized native comparison failed'}
 }
 foreach($directory in $directories){Record ('NATIVE '+$directory+' SHA256 '+(Get-FileHash -LiteralPath (Join-Path $directory 'UBE.exe') -Algorithm SHA256).Hash)}
 Record 'PASS: rebuild fixed-point comparisons; reused-generation provenance is limited as recorded above'
}catch{
 $report.Add('FAIL: '+$_.Exception.Message)
 throw
}finally{[IO.File]::WriteAllLines((Join-Path $artifacts 'report.txt'),$report,$encoding)}

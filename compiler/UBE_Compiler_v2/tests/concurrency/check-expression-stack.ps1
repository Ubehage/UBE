param([string]$CandidateDirectory='',[string]$SelectionPath='',[int[]]$Stages=@(1,2),[switch]$ExpectFaults)

# Admit the existing 128-depth subset without relying on a larger PE stack.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$acceptedSelection=$null
if($CandidateDirectory -eq '') {
    if($SelectionPath -eq ''){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
    $selection=Get-VerifiedBootstrapSelection $SelectionPath;$acceptedSelection=$selection
    $compilerPaths=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $runtimePath=$selection.runtime.path
} else {
    $selection=Get-Content -LiteralPath (Join-Path $root 'bootstrap/out/v2/current.json') -Raw | ConvertFrom-Json
    $compilerPaths=@((Join-Path $CandidateDirectory 'compiler-stage1.exe'),(Join-Path $CandidateDirectory 'compiler-stage2.exe'))
    if(-not [IO.File]::Exists($compilerPaths[0])){$compilerPaths=@((Join-Path $CandidateDirectory 'ube-stage1-v2.exe'),(Join-Path $CandidateDirectory 'ube-stage2-v2.exe'))}
    $runtimePath=Join-Path $CandidateDirectory 'bootstrap_runtime.o'
}
$run=Join-Path $root ('bootstrap/out/expression-depth/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$cases=@();$checks=@();$success=$false;$faults=0
$specs=@(@{name='retained-64';body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'expression-depth.bas'));expected="64`n";code=''})
foreach($count in 64,96,128) {
    foreach($kind in 'constant','variable') {
        $term='1';if($kind -eq 'variable'){$term='Value'}
        $expression=((1..$count | ForEach-Object {$term}) -join '+')
        $specs+=@{name=($kind+'-'+$count);body="Function Main() As Long`nDim Value As Long = 1`nPrint $expression`nMain = 0`nEnd Function`n";expected=($count.ToString()+"`n");code=''}
    }
}
$specs+=@{name='call-63';body=("Function Identity(ByVal Value As Long) As Long`nIdentity = Value`nEnd Function`nFunction Main() As Long`nPrint "+('Identity('*63)+'1'+(')'*63)+"`nMain = 0`nEnd Function`n");expected="1`n";code=''}
$specs+=@{name='group-128';body=("Function Main() As Long`nPrint "+('('*128)+'1'+(')'*128)+"`nMain = 0`nEnd Function`n");expected="1`n";code=''}
$specs+=@{name='unary-127';body=("Function Main() As Long`nIf "+('Not '*127)+"False Then`nPrint 1`nElse`nPrint 0`nEnd If`nMain = 0`nEnd Function`n");expected="1`n";code=''}
$specs+=@{name='binary-129';body=("Function Main() As Long`nPrint "+((1..129 | ForEach-Object {'1'}) -join '+')+"`nMain = 0`nEnd Function`n");expected='';code='UBE3222'}
$specs+=@{name='mixed-nesting';body=("Function Main() As Long`nPrint "+('('*128)+('-'*127)+'1'+(')'*128)+"`nMain = 0`nEnd Function`n");expected="-1`n";code=''}
$specs+=@{name='thread-prefix-run';body=("Function Main() As Long`nPrint "+('CallNew '*512)+"Work()`nMain = 0`nEnd Function`n");expected='';code='UBE2240'}
$specs+=@{name='reference-members-126';classbody="UBE SOURCE 1 CLASS`nAttribute UBE_Name = `"LinkNode`"`nPublic Link As LinkNode`nPublic Value As Long`n";body=("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"MemberDepth`"`nFunction Main() As Long`nDim Owner As LinkNode`nSet Owner = New LinkNode`nSet Owner.Link = Owner`nOwner.Value = 7`nPrint Owner"+('.Link'*126)+".Value`nMain = 0`nEnd Function`n");expected="7`n";code=''}
try {
    foreach($spec in $specs) {
        $source=Join-Path $run ($spec.name+'.bas');[IO.File]::WriteAllText($source,$spec.body,$utf8)
        $inputPath=$source
        if($spec.ContainsKey('classbody')) {
            $class=Join-Path $run ($spec.name+'.cls');[IO.File]::WriteAllText($class,$spec.classbody,$utf8)
            $inputPath=Join-Path $run ($spec.name+'.UBE')
            [IO.File]::WriteAllText($inputPath,("UBE-Project 1`nName = `"MemberDepth`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `""+[IO.Path]::GetFileName($class)+"`"`nSource = `""+[IO.Path]::GetFileName($source)+"`"`n"),$utf8)
        }
        foreach($stage in $Stages) {
            $compiler=$compilerPaths[$stage-1]
            $ir=Join-Path $run ($spec.name+'-'+$stage+'.ll');$exe=[IO.Path]::ChangeExtension($ir,'.exe')
            $emit=Invoke-BoundedProcess $compiler @($inputPath,$ir) $root 20
            if($ExpectFaults -and $emit.exit -eq -1073741571){++$faults;$link=$null;$native=$null}
            elseif($spec.code -ne '') {
                if($emit.timedOut -or $emit.exit -ne 1 -or $emit.stdout -notmatch ('error '+$spec.code+':') -or [IO.File]::Exists($ir)){throw ($spec.name+' expected bounded rejection: '+($emit | ConvertTo-Json -Compress))}
                $link=$null;$native=$null
            } else {
                if($emit.timedOut -or $emit.exit -ne 0){throw ($spec.name+' emission: '+($emit | ConvertTo-Json -Compress))}
                $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-x','none',$runtimePath,$selection.unicodeRuntime.path,'-o',$exe) $root 30
                if($link.timedOut -or $link.exit -ne 0){throw ($spec.name+' link: '+$link.stderr)}
                $native=Invoke-BoundedProcess $exe @() $root 10
                if($native.timedOut -or $native.exit -ne 0 -or $native.stdout.Replace("`r",'') -cne $spec.expected -or $native.stderr -cne ''){throw ($spec.name+' native: '+($native | ConvertTo-Json -Compress))}
            }
            $cases+=[pscustomobject]@{name=$spec.name;stage=$stage;source=(Get-ArtifactIdentity $source);emit=$emit;link=$link;native=$native}
            $checks+=[pscustomobject]@{passed=$true;assertion=($spec.name+' bounded expression behavior through stage '+$stage)}
        }
    }
    if($ExpectFaults -and $faults -eq 0){throw 'No stack-overflow before case was reproduced'}
    if($null -ne $acceptedSelection){$null=Get-VerifiedBootstrapSelection $SelectionPath}
    $success=$true
}catch{$failure=$_.Exception.Message}
$report=[pscustomobject]@{success=$success;acceptedSelection=$acceptedSelection;checks=$checks;reproducedStackFaults=$faults;qualifiedConcurrency=$false;cases=$cases;failure=$(if($success){''}else{$failure})}
$path=Join-Path $run 'report.json';$report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Output ('Evidence: '+$path)
if(-not $success){throw $failure}
Write-Output ('PASS '+$checks.Count+' expression stack checks; reproduced faults='+$faults)

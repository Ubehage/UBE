# Static pre-execution audit only. Never links or executes an input artifact.
# The bound reserves 256 KiB for helpers/CRT/driver; it is not a complete bound
# on external callees, nor a claim about threads given a smaller custom stack.
function Get-ParserProbeStackSafety {
    param(
        [Parameter(Mandatory=$true)][string]$IrPath,
        [Parameter(Mandatory=$true)][string]$AssemblyPath,
        [Parameter(Mandatory=$true)][string]$ExecutablePath,
        [Parameter(Mandatory=$true)]$AbiMapping
    )
    function Read-ParserStackInput([string]$Path,[bool]$AsText) {
        $full = [IO.Path]::GetFullPath($Path)
        $bytes = [IO.File]::ReadAllBytes($full)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','') }
        finally { $sha.Dispose() }
        $decoded = $null
        if ($AsText) { $decoded = ([Text.UTF8Encoding]::new($false,$true)).GetString($bytes) }
        [pscustomobject]@{
            identity = [pscustomobject]@{path=$full;bytes=[long]$bytes.Length;sha256=$hash}
            bytes = $bytes
            text = $decoded
        }
    }
    function Get-ParserStackDefinition([string]$Raw,[string]$Symbol,[string]$Result,[string]$Arguments) {
        $pattern = '(?ms)^define ' + [regex]::Escape($Result) + ' @' + [regex]::Escape($Symbol) + '\(([^\r\n]*)\) \{\r?\n.*?^\}\r?$'
        $definitions = [regex]::Matches($Raw,$pattern)
        if ($definitions.Count -ne 1) { throw "Stack audit requires one exact $Symbol definition" }
        $actual = ''
        if ($definitions[0].Groups[1].Value.Length -gt 0) {
            $actual = @($definitions[0].Groups[1].Value -split ', ' | ForEach-Object { ($_ -split ' ')[0] }) -join ','
        }
        if ($actual -cne $Arguments) { throw "Stack audit ABI mismatch for $Symbol : $actual" }
        return $definitions[0].Value
    }

    $ir = Read-ParserStackInput $IrPath $true
    $assembly = Read-ParserStackInput $AssemblyPath $true
    $executable = Read-ParserStackInput $ExecutablePath $false
    $symbol = [string]$AbiMapping.procedures.TryTraversePrecedence
    $limitSymbol = [string]$AbiMapping.procedures.TraversalFrameLimit
    if ($symbol -notmatch '^ube\.p[0-9]+$' -or $limitSymbol -notmatch '^ube\.p[0-9]+$' -or $symbol -ceq $limitSymbol) {
        throw 'Stack audit requires distinct mapped traversal and frame-limit symbols'
    }
    $recursiveBody = Get-ParserStackDefinition $ir.text $symbol 'i1' 'ptr,ptr,i32,ptr,i32,i32,i32,i32,ptr,ptr,ptr,ptr'
    $limitBody = Get-ParserStackDefinition $ir.text $limitSymbol 'i32' ''
    $frameLimit = 384
    $limitStores = [regex]::Matches($limitBody,'(?m)^\s*store (?:atomic )?i32 ([^,]+), ptr %result(?:\s|,)')
    if (@($limitStores | Where-Object { $_.Groups[1].Value -ceq '384' }).Count -ne 1 -or
        @($limitStores | Where-Object { $_.Groups[1].Value -cne '384' -and $_.Groups[1].Value -cne '0' }).Count -ne 0 -or
        [regex]::Matches($limitBody,'(?m)^\s*ret i32 %[^\s]+\s*$').Count -ne 1 -or
        [regex]::Matches($limitBody,'(?m)^\s*%[^\s]+ = load (?:atomic )?i32, ptr %result(?:\s|,)').Count -ne 1) {
        throw 'Stack audit cannot establish the expected literal 384 frame-limit helper'
    }
    $recursiveCalls = [regex]::Matches($recursiveBody,'\bcall i1 @' + [regex]::Escape($symbol) + '\(').Count
    $guardCalls = [regex]::Matches($recursiveBody,'\bcall i32 @' + [regex]::Escape($limitSymbol) + '\(').Count
    if ($recursiveCalls -ne 3 -or $guardCalls -ne 3) {
        throw 'Stack audit requires the three frozen recursive call sites and three frame-limit guards'
    }

    # An alloca with no explicit element count is one statically sized object.
    # A literal integer count is also static; an SSA/runtime count is dynamic.
    $allocas = [regex]::Matches($recursiveBody,'(?m)^\s*%[^\r\n]+ = alloca ([^\r\n]+)\r?$')
    $dynamicAllocas = @()
    foreach ($allocation in $allocas) {
        $count = [regex]::Match($allocation.Groups[1].Value,',\s*i[0-9]+\s+([^,\s]+)')
        if ($count.Success -and $count.Groups[1].Value -notmatch '^[0-9]+$') {
            $dynamicAllocas += $allocation.Value.Trim()
        }
    }
    $asmPattern = '(?ms)^\s*\.seh_proc\s+' + [regex]::Escape($symbol) + '\s*\r?$.*?^\s*\.seh_endproc\s*\r?$'
    $asmDefinitions = [regex]::Matches($assembly.text,$asmPattern)
    if ($asmDefinitions.Count -ne 1) { throw 'Stack audit requires one exact assembly .seh_proc' }
    $asmBody = $asmDefinitions[0].Value
    $allocations = [regex]::Matches($asmBody,'(?m)^\s*\.seh_stackalloc\s+([0-9]+)\s*\r?$')
    if ($allocations.Count -ne 1) { throw 'Stack audit requires one static .seh_stackalloc allocation' }
    $pushes = [regex]::Matches($asmBody,'(?m)^\s*pushq\s+').Count
    $pushBytes = [long]$pushes * 8
    $allocationBytes = [long]::Parse($allocations[0].Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
    $frameWide = [decimal]$allocationBytes + [decimal]$pushBytes + 8
    if ($frameWide -gt [long]::MaxValue) { throw 'Static frame exceeds the supported audit arithmetic domain' }
    $frameBytes = [long]$frameWide

    $bytes = $executable.bytes
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 77 -or $bytes[1] -ne 90) { throw 'Stack audit executable is not a DOS/PE image' }
    $pe = [BitConverter]::ToInt32($bytes,60)
    if ($pe -lt 0 -or $pe -gt $bytes.Length - 24) { throw 'Stack audit executable has an invalid PE header offset' }
    if ($bytes[$pe] -ne 80 -or $bytes[$pe+1] -ne 69 -or $bytes[$pe+2] -ne 0 -or $bytes[$pe+3] -ne 0) { throw 'Stack audit executable lacks the PE signature' }
    if ([BitConverter]::ToUInt16($bytes,$pe+4) -ne 34404) { throw 'Stack audit requires the frozen x86-64 target' }
    $optional = $pe + 24
    $optionalBytes = [BitConverter]::ToUInt16($bytes,$pe+20)
    if ($optionalBytes -lt 80 -or $optional -gt $bytes.Length - $optionalBytes) { throw 'Stack audit executable has a truncated optional header' }
    if ([BitConverter]::ToUInt16($bytes,$optional) -ne 523) { throw 'Stack audit requires PE32+' }
    $reserve = [BitConverter]::ToUInt64($bytes,$optional+72)
    if ($reserve -gt [long]::MaxValue) { throw 'Stack reserve exceeds the supported audit arithmetic domain' }
    $guardedWide = [decimal]$frameLimit * [decimal]$frameBytes
    if ($guardedWide -gt [long]::MaxValue) { throw 'Guarded frames exceed the supported audit arithmetic domain' }
    $guardedBytes = [long]$guardedWide
    $requiredHeadroom = [long]262144
    $headroom = [long]$reserve - $guardedBytes
    $reasons = @()
    if ($dynamicAllocas.Count -ne 0) { $reasons += 'Recursive LLVM contains dynamically sized allocas' }
    if ($headroom -lt $requiredHeadroom) { $reasons += 'Guarded recursive frames leave less than 256 KiB for helpers/CRT/driver' }

    # Source inspection is supplementary, not an external-callee frame proof.
    # The driver allocates generated input, expected arrays and root holders on
    # the heap. Numeric bracket values (bounds and indexes, not a C declaration
    # parser) are retained for supplementary source review only.
    $driver = Read-ParserStackInput (Join-Path $PSScriptRoot 'probe.c') $true
    $literalExtents = @([regex]::Matches($driver.text,'\[\s*([0-9]+)\s*\]') | ForEach-Object { [long]$_.Groups[1].Value } | Sort-Object -Unique)
    [pscustomobject]@{
        executed = $false
        safeForGuardedDepth = $reasons.Count -eq 0
        reasons = @($reasons)
        ir = $ir.identity
        assembly = $assembly.identity
        executable = $executable.identity
        driver = $driver.identity
        symbol = $symbol
        frameLimitSymbol = $limitSymbol
        frameLimit = $frameLimit
        recursiveCallSites = $recursiveCalls
        frameLimitGuardCalls = $guardCalls
        guardControlFlowBasis = 'Frozen UBE caller-before-recursion guards, independently reviewed; this helper checks signatures, call-site counts and the literal limit, not general LLVM dominance.'
        dynamicAllocas = @($dynamicAllocas)
        dynamicAllocaCount = $dynamicAllocas.Count
        staticAllocaCount = $allocas.Count - $dynamicAllocas.Count
        assemblyStackAllocationBytes = $allocationBytes
        assemblyPushCount = $pushes
        assemblyPushBytes = $pushBytes
        returnAddressBytes = 8
        frameBytes = $frameBytes
        stackReserveBytes = [long]$reserve
        guardedFrameBytes = $guardedBytes
        requiredHeadroomBytes = $requiredHeadroom
        headroomBytes = $headroom
        driverNumericBracketValues = @($literalExtents)
        scope = 'Static recursive-frame arithmetic only. Excludes external helper/CRT/adapter/driver stack usage; the reserved 256 KiB is a safety allowance, not a measured complete bound. Applies to the executable default stack, not smaller custom thread stacks. No artifact was executed and no stack reservation was changed.'
    }
}

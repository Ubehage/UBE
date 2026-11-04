param([Parameter(Mandatory = $true)][string] $Compiler)

$ErrorActionPreference = 'Stop'
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$projects = @(
    'boolean-eager/BooleanEager.UBE',
    'nested-exit/NestedExit.UBE',
    'single-line-if/SingleLineIf.UBE',
    'initializer-error/InitializerError.UBE',
    'initializer-self/InitializerSelf.UBE',
    'error-order/ErrorOrder.UBE',
    'error-replace-division/ErrorReplaceDivision.UBE',
    'error-replace-overflow/ErrorReplaceOverflow.UBE',
    'division-signs/DivisionSigns.UBE',
    'call-effects/CallEffects.UBE',
    'nested-arguments/NestedArguments.UBE',
    'argument-error/ArgumentError.UBE',
    'optional-value/OptionalValue.UBE',
    'native-extrema/NativeExtrema.UBE',
    'native-signed-boundaries/NativeSignedBoundaries.UBE',
    'native-neutral/NativeNeutral.UBE',
    'native-byte-neutral/NativeByteNeutral.UBE',
    'longlong-values/LongLongValues.UBE',
    'native-byte-extrema/NativeByteExtrema.UBE',
    'debug-sources/DebugSources.UBE',
    'debug-sources/DebugSourcesNoDebug.UBE',
    'longlong-overflow/LongLongOverflow.UBE',
    'exit-min/ExitMin.UBE',
    'exit-max/ExitMax.UBE',
    'initializer-order/InitializerOrder.UBE',
    'initializer-events/InitializerEvents.UBE',
    'initializer-events/InitializerEventsModulesReversed.UBE',
    'initializer-events/InitializerEventsDeclarationsReversed.UBE',
    'initializer-early-access/InitializerEarlyAccess.UBE',
    'initializer-cycle/InitializerCycle.UBE',
    'initializer-indirect-cycle/InitializerIndirectCycle.UBE',
    'initializer-indirect-acyclic/InitializerIndirectAcyclic.UBE',
    'initializer-cycle-branch/InitializerCycleBranch.UBE',
    'initializer-early-call/InitializerEarlyCall.UBE',
    'initializer-unused-helper/InitializerUnusedHelper.UBE',
    'reference-init-order/ReferenceInitOrder.UBE',
    'reference-initializer-error/ReferenceInitializerError.UBE',
    'native-byval-copy/NativeByValCopy.UBE',
    'native-many-arguments/NativeManyArguments.UBE',
    'byte-bitwise/ByteBitwise.UBE',
    'comparison-boundaries/ComparisonBoundaries.UBE',
    'signed-comparisons/SignedComparisons.UBE',
    'stack-call-effects/StackCallEffects.UBE',
    'tail-recursion/TailRecursion.UBE',
    'tail-recursion/TailRecursionNoDebug.UBE',
    'multiply-overflow/MultiplyOverflow.UBE',
    'subtraction-extrema/SubtractionExtrema.UBE',
    'narrowing-boundaries/NarrowingBoundaries.UBE',
    'division-overflow/DivisionOverflow.UBE',
    'remainder-minimum/RemainderMinimum.UBE',
    'negate-minimum/NegateMinimum.UBE',
    'remainder-integer-min/RemainderIntegerMin.UBE',
    'remainder-longlong-min/RemainderLongLongMin.UBE',
    'initializer-alias-read/InitializerAliasRead.UBE',
    'initializer-alias-write/InitializerAliasWrite.UBE',
    'initializer-alias-forward/InitializerAliasForward.UBE',
    'initializer-alias-unused/InitializerAliasUnused.UBE',
    'initializer-alias-local/InitializerAliasLocal.UBE',
    'initializer-alias-byval/InitializerAliasByVal.UBE',
    'initializer-alias-forced/InitializerAliasForced.UBE',
    'initializer-alias-default/InitializerAliasDefault.UBE',
    'initializer-early-write/InitializerEarlyWrite.UBE',
    'initializer-neutral-reset/InitializerNeutralReset.UBE'
)
$count = 0
foreach ($project in $projects) {
    $manifest = Join-Path $PSScriptRoot $project
    foreach ($jobs in @(1, 4)) {
        $output = @(& $compilerPath --check $manifest --jobs $jobs 2>&1)
        $status = $LASTEXITCODE
        if ($status -ne 0 -or $output.Count -ne 0) {
            throw "Admission failed for $project at jobs $jobs (exit $status): $($output -join [Environment]::NewLine)"
        }
        $count++
    }
}
Write-Output "Passed $count additional frontend admission checks."

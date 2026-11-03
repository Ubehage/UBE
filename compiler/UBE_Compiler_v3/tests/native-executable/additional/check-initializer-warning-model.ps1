# Test-only graph policy model. Inputs and expected edges/groups are hand-authored;
# this does not consume compiler output or implement a production warning pass.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Body($owner, $ops, $parameters=@()) { return @{ owner=$owner; ops=@($ops); parameters=@($parameters) } }
function Access($target, $at) { return @{ kind='access'; target=$target; at=$at } }
function Call($target, $at, $actual='', $argumentAt=-1) {
    if ($argumentAt -lt 0) { $argumentAt=$at }
    return @{ kind='call'; target=$target; at=$at; actual=$actual; argumentAt=$argumentAt }
}
function Case($name, $count, $bodies, $edges, $warnings) {
    return @{ name=$name; count=$count; bodies=$bodies; edges=$edges; warnings=$warnings }
}
# Positions are independent synthetic source offsets, not offsets in .bas files.
# One ByRef formal named p is enough for these forwarding/temporary controls.
$cases=@(
    (Case 'direct' 2 @{ i0=(Body 0 @((Access 1 10))); i1=(Body 1 @((Access 0 20))) } '0>1@0:10;1>0@1:20' '0,1@0:10'),
    (Case 'helper' 2 @{ i0=(Body 0 @((Call 'h0' 10))); i1=(Body 1 @((Access 0 20))); h0=(Body 0 @((Access 1 50))) } '0>1@0:50;1>0@1:20' '0,1@0:50'),
    (Case 'uncalled-helper' 2 @{ i0=(Body 0 @((Access 1 10))); i1=(Body 1 @()); h1=(Body 1 @((Access 0 20))) } '0>1@0:10' ''),
    (Case 'cycle-with-branch' 3 @{ i0=(Body 0 @((Access 1 10))); i1=(Body 1 @((Access 0 20),(Access 2 30))); i2=(Body 2 @()) } '0>1@0:10;1>0@1:20;1>2@1:30' '0,1@0:10'),
    (Case 'own-module-read' 1 @{ i0=(Body 0 @((Access 0 10),(Call 'h0' 20))); h0=(Body 0 @((Access 0 30))) } '' ''),
    (Case 'foreign-helper-reentry' 2 @{ i0=(Body 0 @((Call 'h1' 10))); i1=(Body 1 @()); h1=(Body 1 @((Access 0 30))) } '0>0@1:30;0>1@0:10' '0@1:30'),
    (Case 'recursive-helper' 2 @{ i0=(Body 0 @((Call 'h0' 10))); i1=(Body 1 @((Access 0 20))); h0=(Body 0 @((Call 'h0' 40),(Access 1 50))) } '0>1@0:50;1>0@1:20' '0,1@0:50'),
    (Case 'two-cycles' 4 @{ i0=(Body 0 @((Access 1 10))); i1=(Body 1 @((Access 0 20))); i2=(Body 2 @((Access 3 30))); i3=(Body 3 @((Access 2 40))) } '0>1@0:10;1>0@1:20;2>3@2:30;3>2@3:40' '0,1@0:10;2,3@2:30'),
    (Case 'byref-direct' 2 @{ i0=(Body 0 @((Call 'h1' 10 'module:0'))); i1=(Body 1 @()); h1=(Body 1 @() @('p')) } '0>0@0:10;0>1@0:10' '0@0:10'),
    (Case 'byref-forwarded' 2 @{ i0=(Body 0 @((Call 'h0' 10 'module:0'))); i1=(Body 1 @()); h0=(Body 0 @((Call 'h1' 40 'param:h0.p')) @('p')); h1=(Body 1 @() @('p')) } '0>0@0:40;0>1@0:40' '0@0:40'),
    (Case 'byref-local' 2 @{ i0=(Body 0 @((Call 'h0' 10 'local'))); i1=(Body 1 @()); h0=(Body 0 @((Call 'h1' 40 'param:h0.p')) @('p')); h1=(Body 1 @() @('p')) } '0>1@0:40' ''),
    (Case 'byref-temporary' 2 @{ i0=(Body 0 @((Call 'h1' 10 'temporary'))); i1=(Body 1 @()); h1=(Body 1 @() @('p')) } '0>1@0:10' ''),
    (Case 'byref-own-helper' 1 @{ i0=(Body 0 @((Call 'h0' 10 'module:0'))); h0=(Body 0 @((Access 0 20)) @('p')) } '' ''),
    (Case 'byref-union' 2 @{ i0=(Body 0 @((Call 'h0' 10 'local'),(Call 'h0' 20 'module:0'))); i1=(Body 1 @()); h0=(Body 0 @((Call 'h1' 40 'param:h0.p')) @('p')); h1=(Body 1 @() @('p')) } '0>0@0:40;0>1@0:40' '0@0:40'),
    (Case 'byval-copy' 2 @{ i0=(Body 0 @((Call 'h1' 10 'value'))); i1=(Body 1 @()); h1=(Body 1 @() @('p')) } '0>1@0:10' ''),
    (Case 'byref-earliest-last' 2 @{ i0=(Body 0 @((Call 'h1' 40 'module:0'),(Call 'h1' 10 'module:0'))); i1=(Body 1 @()); h1=(Body 1 @() @('p')) } '0>0@0:10;0>1@0:10' '0@0:10'),
    (Case 'byref-local-not-witness' 2 @{ i0=(Body 0 @((Call 'h1' 10 'local'),(Call 'h1' 40 'module:0'))); i1=(Body 1 @()); h1=(Body 1 @() @('p')) } '0>0@0:40;0>1@0:10' '0@0:40'),
    (Case 'byref-recursive-seeded' 2 @{ i0=(Body 0 @((Call 'h0' 10 'module:0'))); i1=(Body 1 @()); h0=(Body 0 @((Call 'h0' 30 'param:h0.p'),(Call 'h1' 40 'param:h0.p')) @('p')); h1=(Body 1 @() @('p')) } '0>0@0:40;0>1@0:40' '0@0:40'),
    (Case 'byref-recursive-unseeded' 2 @{ i0=(Body 0 @((Call 'h0' 10 'temporary'))); i1=(Body 1 @()); h0=(Body 0 @((Call 'h0' 30 'param:h0.p'),(Call 'h1' 40 'param:h0.p')) @('p')); h1=(Body 1 @() @('p')) } '0>1@0:40' ''),
    (Case 'byref-other-module-storage' 2 @{ i0=(Body 0 @((Call 'h0' 10 'module:1' 11))); i1=(Body 1 @()); h0=(Body 0 @() @('p')) } '0>1@0:11' ''),
    (Case 'shared-witness-tie' 4 @{ i0=(Body 0 @()); i1=(Body 1 @((Call 'h0' 20 'module:1'))); i2=(Body 2 @((Call 'h0' 30 'module:2'))); i3=(Body 3 @()); h0=(Body 0 @((Call 'h3' 10 'param:h0.p')) @('p')); h3=(Body 3 @() @('p')) } '1>0@1:20;1>1@0:10;1>3@0:10;2>0@2:30;2>2@0:10;2>3@0:10' '1@0:10;2@0:10')
)
function Model($case, $omitHelpers=$false, $allBodies=$false, $omitAliases=$false) {
    $edges=@{}
    function Add-Edge($from,$to,$source,$at) {
        $key="$from>$to"
        if (-not $edges.ContainsKey($key) -or $source -lt $edges[$key].source -or
            ($source -eq $edges[$key].source -and $at -lt $edges[$key].at)) {
            $edges[$key]=@{from=$from;to=$to;source=$source;at=$at}
        }
    }
    for ($root=0;$root -lt $case.count;$root++) {
        $queue=[Collections.Generic.Queue[string]]::new(); $seen=@{}
        $queue.Enqueue("i$root")
        if ($allBodies) { foreach ($id in $case.bodies.Keys) { if ($case.bodies[$id].owner -eq $root) { $queue.Enqueue($id) } } }
        $seeds=[Collections.Generic.List[object]]::new(); $flows=@{}
        $bodyVisits=0
        while ($queue.Count) {
            $id=$queue.Dequeue()
            if ($seen.ContainsKey($id)) { continue }
            $seen[$id]=$true; $bodyVisits++
            $body=$case.bodies[$id]
            foreach ($op in $body.ops) {
                if ($op.kind -eq 'access') {
                    if ($body.owner -ne $op.target) { Add-Edge $root $op.target $body.owner $op.at }
                } else {
                    $target=$case.bodies[$op.target]
                    if ($body.owner -ne $target.owner) { Add-Edge $root $target.owner $body.owner $op.at }
                    # Storage access uses its expression span; alias self-edges
                    # below use the call span.
                    if ($op.actual.StartsWith('module:')) {
                        $storageOwner=[int]$op.actual.Substring(7)
                        if ($body.owner -ne $storageOwner) { Add-Edge $root $storageOwner $body.owner $op.argumentAt }
                    }
                    if (-not $omitHelpers) { $queue.Enqueue($op.target) }
                    if ($op.actual -and -not $omitAliases) {
                        if ($target.parameters -notcontains 'p') { throw 'Missing target formal in model' }
                        $flow=@{to=($op.target+'.p');owner=$target.owner;source=$body.owner;at=$op.at}
                        if ($op.actual -eq "module:$root") { $seeds.Add($flow) }
                        elseif ($op.actual.StartsWith('param:')) {
                            $formal=$op.actual.Substring(6)
                            if (-not $flows.ContainsKey($formal)) { $flows[$formal]=[Collections.Generic.List[object]]::new() }
                            $flows[$formal].Add($flow)
                        }
                    }
                }
            }
        }
        if ($bodyVisits -gt $case.bodies.Count) { throw 'Body traversal exceeded one visit per root' }
        $pending=[Collections.Generic.Queue[object]]::new(); $trueFormals=@{}
        foreach ($seed in $seeds) { $pending.Enqueue($seed) }
        while ($pending.Count) {
            $flow=$pending.Dequeue()
            # Check each incoming call edge even if its target bit was already set.
            if ($flow.owner -ne $root) { Add-Edge $root $root $flow.source $flow.at }
            if ($trueFormals.ContainsKey($flow.to)) { continue }
            $trueFormals[$flow.to]=$true
            if ($flows.ContainsKey($flow.to)) { foreach ($next in $flows[$flow.to]) { $pending.Enqueue($next) } }
        }
    }
    # Independent small-model grouping by transitive closure, rather than the
    # iterative SCC traversal selected for production. No runtime code is run.
    $reach=New-Object 'bool[,]' $case.count,$case.count
    foreach ($edge in $edges.Values) { $reach[$edge.from,$edge.to]=$true }
    for ($k=0;$k -lt $case.count;$k++) { for ($i=0;$i -lt $case.count;$i++) { for ($j=0;$j -lt $case.count;$j++) {
        $reach[$i,$j]=$reach[$i,$j] -or ($reach[$i,$k] -and $reach[$k,$j])
    } } }
    $grouped=@{}; $warnings=@()
    for ($i=0;$i -lt $case.count;$i++) {
        if ($grouped.ContainsKey($i) -or -not $reach[$i,$i]) { continue }
        $members=@()
        for ($j=0;$j -lt $case.count;$j++) { if ($reach[$i,$j] -and $reach[$j,$i]) { $members+=$j; $grouped[$j]=$true } }
        $witness=@($edges.Values | Where-Object { $members -contains $_.from -and $members -contains $_.to } | Sort-Object { $_.source },{ $_.at })[0]
        $warnings+=@{text=(($members -join ',')+'@'+$witness.source+':'+$witness.at);source=$witness.source;at=$witness.at;minimum=$members[0]}
    }
    $edgeText=(@($edges.Keys | Sort-Object | ForEach-Object { $_+'@'+$edges[$_].source+':'+$edges[$_].at }) -join ';')
    # Reverse collection order to exercise the explicit tie-break rather than
    # relying on discovery order or sort stability.
    [Array]::Reverse($warnings)
    $warningText=(@($warnings | Sort-Object { $_.source },{ $_.at },{ $_.minimum } | ForEach-Object { $_.text }) -join ';')
    return @{edges=$edgeText;warnings=$warningText}
}
foreach ($case in $cases) {
    $actual=Model $case
    if ($actual.edges -cne $case.edges -or $actual.warnings -cne $case.warnings) {
        throw "$($case.name): edges=$($actual.edges), warnings=$($actual.warnings)"
    }
    Write-Output "$($case.name): expected dependencies, groups and anchors matched."
}
foreach ($control in @(@{name='helper';helpers=$true;all=$false;aliases=$false},
                       @{name='uncalled-helper';helpers=$false;all=$true;aliases=$false},
                       @{name='byref-forwarded';helpers=$false;all=$false;aliases=$true})) {
    $case=@($cases | Where-Object { $_.name -eq $control.name })[0]
    $actual=Model $case $control.helpers $control.all $control.aliases
    if ($actual.warnings -ceq $case.warnings) { throw 'Omitted-analysis control not distinguished' }
}
Write-Output "$($cases.Count) independent graph cases and 3 omitted/overinclusive-analysis controls passed. No compiler or native warning implementation tested."

param([Parameter(Mandatory=$true)][string]$Counts)
$bytes=[IO.File]::ReadAllBytes($Counts)
if($bytes.Length -ne 576){throw 'Incomplete counter dump'}
$values=for($i=0;$i -lt 72;$i++){[BitConverter]::ToUInt64($bytes,$i*8)}
$names=@('collect','new','snapshot','clear','install','box.drop','copybytes','other')
for($i=0;$i -lt 8;$i++){
 [pscustomobject]@{Operation=$names[$i];Acquisitions=$values[$i*8];FailedCAS=$values[$i*8+1];ContendedAcquisitions=$values[$i*8+2]}
}
[pscustomobject]@{CollectorScans=$values[64];ScannedBlocks=$values[65];FreedBlocks=$values[66];EmptyHeapCalls=$values[67];NoReclaimCalls=$values[68];MaximumScan=$values[69];SnapshotCalls=$values[70];CollectionRequests=$values[71]}|ConvertTo-Json -Compress

# Test-only process orchestration. Each native range owns a separate real root
# registry and immutable executable. This does not implement a UBE scheduler.
function Invoke-ParserRootRanges([string]$Executable,[object[]]$Ranges,[string]$VerificationHelper,[string]$WorkingDirectory,[int]$MaximumJobs=4){
    if($MaximumJobs -lt 1 -or $MaximumJobs -gt 4){throw 'Parser root test concurrency must be one through four'}
    $pool=[runspacefactory]::CreateRunspacePool(1,$MaximumJobs)
    $active=New-Object 'System.Collections.Generic.List[object]'
    $next=0;$firstFailure=''
    $pool.Open()
    try{
        while($next -lt $Ranges.Count -or $active.Count){
            while(-not $firstFailure -and $next -lt $Ranges.Count -and $active.Count -lt $MaximumJobs){
                $range=$Ranges[$next];++$next
                $worker=[powershell]::Create();$worker.RunspacePool=$pool
                $script='param($Helper,$Exe,$ArgsVector,$Directory) . $Helper; Invoke-BoundedProcess $Exe $ArgsVector $Directory 120'
                $arguments=@('--suite','roots','--root-actor',[string]$range.actor,'--root-first',[string]$range.first,'--root-last',[string]$range.last)
                $null=$worker.AddScript($script).AddArgument($VerificationHelper).AddArgument($Executable).AddArgument($arguments).AddArgument($WorkingDirectory)
                $handle=$worker.BeginInvoke()
                $active.Add([pscustomobject]@{range=$range;worker=$worker;handle=$handle})
            }
            $finished=@($active|Where-Object {$_.handle.IsCompleted})
            if(-not $finished.Count){
                if(-not $active.Count){break}
                $handles=[Threading.WaitHandle[]]@($active|ForEach-Object {$_.handle.AsyncWaitHandle})
                $null=[Threading.WaitHandle]::WaitAny($handles,1000)
                continue
            }
            foreach($job in $finished){
                try{
                    $result=@($job.worker.EndInvoke($job.handle))
                    if($job.worker.HadErrors -or $result.Count -ne 1){throw "Root range worker failed: $($job.worker.Streams.Error -join '; ')"}
                    Write-Output ([pscustomobject]@{range=$job.range;actual=$result[0]})
                    if($result[0].timedOut -or $result[0].exit -ne 0){$firstFailure='A bounded root range failed; already started workers are drained without starting more ranges.'}
                }catch{if(-not $firstFailure){$firstFailure=$_.Exception.Message}}
                finally{$job.worker.Dispose();$null=$active.Remove($job)}
            }
        }
        if($firstFailure){throw $firstFailure}
        if($next -ne $Ranges.Count){throw 'Root range scheduler did not start every required range'}
    }finally{
        # EndInvoke lets bounded native work finish even when the caller rejects
        # an earlier result; no background native process is left unobserved.
        foreach($job in $active){try{$null=$job.worker.EndInvoke($job.handle)}finally{$job.worker.Dispose()}}
        $pool.Close();$pool.Dispose()
    }
}

UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerExecutor"

' Phase 2 deliberately has a capacity of one.  The state and ownership rules
' are permanent; later phases may replace the worker pump without changing the
' coordinator contract.
Type CompilerTask
    TaskKind As Long
    OutputMode As Long
    Argument1 As String
    Argument2 As String
    Argument3 As String
    Argument4 As String
    Argument5 As String
    Argument6 As String
    Argument7 As String
End Type

Type CompilerTaskResult
    ExitCode As Long
    ArenaAllocated As Long
    ArtifactsOwned As Long
    OutputPath As String
    ProfilePath As String
    HeaderPath As String
    IntermediatePath As String
End Type

Type CompilerExecutor
    RequestedJobs As Long
    EffectiveJobs As Long
    WorkerCapacity As Long
    RegisteredWorkers As Long
    LiveWorkers As Long
    PublishedTasks As Long
    RunningTasks As Long
    CompletedTasks As Long
    CancelRequested As Long
    Drained As Long
    CaptureCount As Long
    FaultSite As String
End Type

Sub InitializeCompilerExecutor(ByRef Executor As CompilerExecutor, ByVal RequestedJobs As Long, ByVal FaultSite As String)
    Executor.RequestedJobs = RequestedJobs
    Executor.EffectiveJobs = 1
    Executor.WorkerCapacity = 1
    Executor.RegisteredWorkers = 0
    Executor.LiveWorkers = 0
    Executor.PublishedTasks = 0
    Executor.RunningTasks = 0
    Executor.CompletedTasks = 0
    Executor.CancelRequested = 0
    Executor.Drained = 0
    Executor.CaptureCount = 0
    Executor.FaultSite = FaultSite
End Sub

Function ExecutorFaultIs(ByRef Executor As CompilerExecutor, ByVal Site As String) As Long
    If EqualsFolded(Executor.FaultSite, Site) <> 0 Then
        ExecutorFaultIs = 1
    Else
        ExecutorFaultIs = 0
    End If
End Function

Sub ReportExecutorFailure(ByVal Code As String, ByVal Message As String)
    Print "error " & Code & ": " & Message
End Sub

Function RegisterCompilerWorker(ByRef Executor As CompilerExecutor) As Long
    If ExecutorFaultIs(Executor, "worker-creation") <> 0 Then
        Call ReportExecutorFailure("UBE5301", "compiler worker registration failed")
        RegisterCompilerWorker = 0
        Exit Function
    End If
    Executor.RegisteredWorkers = 1
    Executor.LiveWorkers = 1
    Executor.CaptureCount = 1
    RegisterCompilerWorker = 1
End Function

Function PublishCompilerTask(ByRef Executor As CompilerExecutor) As Long
    If ExecutorFaultIs(Executor, "task-publication") <> 0 Then
        Call ReportExecutorFailure("UBE5302", "compiler task publication failed")
        PublishCompilerTask = 0
        Exit Function
    End If
    Executor.PublishedTasks = 1
    PublishCompilerTask = 1
End Function

Function AllocateCompilerResult(ByRef Executor As CompilerExecutor, ByRef Result As CompilerTaskResult) As Long
    If ExecutorFaultIs(Executor, "result-allocation") <> 0 Then
        Call ReportExecutorFailure("UBE5303", "compiler worker result allocation failed")
        AllocateCompilerResult = 0
        Exit Function
    End If
    Result.ArenaAllocated = 1
    AllocateCompilerResult = 1
End Function

Sub RequestCompilerCancellation(ByRef Executor As CompilerExecutor)
    Executor.CancelRequested = 1
End Sub

Sub DrainCompilerExecutor(ByRef Executor As CompilerExecutor)
    Executor.RunningTasks = 0
    Executor.LiveWorkers = 0
    Executor.RegisteredWorkers = 0
    Executor.CaptureCount = 0
    Executor.Drained = 1
End Sub

Sub ReleaseCompilerResult(ByRef Result As CompilerTaskResult)
    Result.ExitCode = 1
    Result.ArenaAllocated = 0
    Result.ArtifactsOwned = 0
    Result.OutputPath = ""
    Result.ProfilePath = ""
    Result.HeaderPath = ""
    Result.IntermediatePath = ""
End Sub

Sub CleanupCompilerResultArtifacts(ByRef Result As CompilerTaskResult)
    Dim CleanupStatus As Long = 0
    If Result.ArtifactsOwned = 0 Then
        Exit Sub
    End If
    If StringLength(Result.OutputPath) > 0 Then
        CleanupStatus = CompilerDeleteFile(Result.OutputPath)
    End If
    If StringLength(Result.ProfilePath) > 0 Then
        CleanupStatus = CompilerDeleteFile(Result.ProfilePath)
    End If
    If StringLength(Result.HeaderPath) > 0 Then
        CleanupStatus = CompilerDeleteFile(Result.HeaderPath)
    End If
    If StringLength(Result.IntermediatePath) > 0 Then
        CleanupStatus = CompilerDeleteFile(Result.IntermediatePath)
    End If
    Result.ArtifactsOwned = 0
End Sub

Function CompilerExecutorIsDrained(ByRef Executor As CompilerExecutor, ByRef Result As CompilerTaskResult) As Long
    If Executor.Drained = 0 Then
        CompilerExecutorIsDrained = 0
        Exit Function
    End If
    If Executor.LiveWorkers <> 0 Or Executor.RegisteredWorkers <> 0 Or Executor.RunningTasks <> 0 Then
        CompilerExecutorIsDrained = 0
        Exit Function
    End If
    If Executor.CaptureCount <> 0 Or Result.ArenaAllocated <> 0 Or Result.ArtifactsOwned <> 0 Then
        CompilerExecutorIsDrained = 0
        Exit Function
    End If
    CompilerExecutorIsDrained = 1
End Function

Sub DescribeCompilerResultArtifacts(ByRef Task As CompilerTask, ByRef Result As CompilerTaskResult)
    If Task.TaskKind = 1 Then
        If Task.OutputMode = 5 Then
            Result.OutputPath = Task.Argument3
            Result.ProfilePath = Task.Argument4
            Result.HeaderPath = Task.Argument3 & ".h"
        End If
    End If
    If Task.TaskKind = 3 Then
        Result.OutputPath = Task.Argument6
        Result.HeaderPath = Task.Argument6 & ".h"
        Result.IntermediatePath = Task.Argument7
    End If
End Sub

Function ExecuteCompilerTaskOnWorker(ByRef Executor As CompilerExecutor, ByRef Task As CompilerTask, ByRef Result As CompilerTaskResult) As Long
    Executor.RunningTasks = 1
    If Task.TaskKind = 1 Then
        Result.ExitCode = RunCompilerDriver(Task.Argument1, Task.Argument2, Task.OutputMode, Task.Argument3, Task.Argument4)
    Else
        If Task.TaskKind = 2 Then
            Result.ExitCode = RunProjectGroupDriver(Task.Argument1, Task.Argument2)
        Else
            Result.ExitCode = RunNativeCompilerDriver(Task.Argument1, Task.Argument2, Task.Argument3, Task.Argument4, Task.Argument5, Task.Argument6, Task.Argument7)
        End If
    End If
    Executor.RunningTasks = 0
    Executor.CompletedTasks = 1
    ExecuteCompilerTaskOnWorker = Result.ExitCode
End Function

Function MergeCompilerTaskResult(ByRef Executor As CompilerExecutor, ByRef Result As CompilerTaskResult) As Long
    If ExecutorFaultIs(Executor, "merge") <> 0 Then
        Call ReportExecutorFailure("UBE5305", "compiler result merge failed")
        MergeCompilerTaskResult = 0
        Exit Function
    End If
    MergeCompilerTaskResult = 1
End Function

Function FinishFailedCompilerExecutor(ByRef Executor As CompilerExecutor, ByRef Result As CompilerTaskResult) As Long
    Call RequestCompilerCancellation(Executor)
    Call CleanupCompilerResultArtifacts(Result)
    Call DrainCompilerExecutor(Executor)
    Call ReleaseCompilerResult(Result)
    If CompilerExecutorIsDrained(Executor, Result) = 0 Then
        Call ReportExecutorFailure("UBE5306", "compiler executor did not release all owned state")
    End If
    FinishFailedCompilerExecutor = 1
End Function

Function RunCompilerExecutorTask(ByRef Task As CompilerTask, ByVal RequestedJobs As Long, ByVal FaultSite As String) As Long
    Dim Executor As CompilerExecutor
    Dim Result As CompilerTaskResult
    Call InitializeCompilerExecutor(Executor, RequestedJobs, FaultSite)
    Call DescribeCompilerResultArtifacts(Task, Result)

    If RegisterCompilerWorker(Executor) = 0 Then
        RunCompilerExecutorTask = FinishFailedCompilerExecutor(Executor, Result)
        Exit Function
    End If
    If PublishCompilerTask(Executor) = 0 Then
        RunCompilerExecutorTask = FinishFailedCompilerExecutor(Executor, Result)
        Exit Function
    End If
    If AllocateCompilerResult(Executor, Result) = 0 Then
        RunCompilerExecutorTask = FinishFailedCompilerExecutor(Executor, Result)
        Exit Function
    End If
    If ExecutorFaultIs(Executor, "cancellation") <> 0 Then
        Call ReportExecutorFailure("UBE5304", "compiler task cancelled")
        RunCompilerExecutorTask = FinishFailedCompilerExecutor(Executor, Result)
        Exit Function
    End If

    Dim WorkerStatus As Long = ExecuteCompilerTaskOnWorker(Executor, Task, Result)
    If WorkerStatus <> 0 Then
        RunCompilerExecutorTask = FinishFailedCompilerExecutor(Executor, Result)
        RunCompilerExecutorTask = WorkerStatus
        Exit Function
    End If
    Result.ArtifactsOwned = 1
    If MergeCompilerTaskResult(Executor, Result) = 0 Then
        RunCompilerExecutorTask = FinishFailedCompilerExecutor(Executor, Result)
        Exit Function
    End If

    Call DrainCompilerExecutor(Executor)
    Call ReleaseCompilerResult(Result)
    If CompilerExecutorIsDrained(Executor, Result) = 0 Then
        Call ReportExecutorFailure("UBE5306", "compiler executor did not release all owned state")
        RunCompilerExecutorTask = 1
        Exit Function
    End If
    RunCompilerExecutorTask = 0
End Function

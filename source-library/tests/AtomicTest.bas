UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Dim Small As New AtomicLong
    Dim Large As New AtomicLongLong
    Dim Ready As New AtomicBoolean
    Print Small.Store(4)
    Print Small.Increment()
    Print Small.CompareExchange(5, 8)
    Print Small.Load()
    Print Large.Store(4000000000)
    Print Large.Add(9)
    Print Ready.Store(True)
    Print Ready.Load()
    Dim First As LongLong
    Dim Second As LongLong
    First = CallNew AddMany(Small)
    Second = CallNew AddMany(Small)
    Print ThreadWaitTimeout(First, 5000)
    Print ThreadWaitTimeout(Second, 5000)
    Print Small.Load()
    Dim Pulse As ThreadEvent
    Set Pulse = CreateThreadEvent(False, False)
    Print Pulse.Wait(0)
    Print Pulse.Set()
    Print Pulse.Wait(0)
    Print Pulse.Wait(0)
    Dim Gate As Semaphore
    Set Gate = CreateSemaphore(1, 1)
    Print Gate.Wait(0)
    Print Gate.Wait(0)
    Print Gate.Release(1)
    Print Gate.Wait(0)
    Dim FirstObject As New AtomicTestObject
    Dim SecondObject As New AtomicTestObject
    Dim ObjectCell As New AtomicObject
    Dim ObservedObject As Object
    Print ObjectCell.Store(FirstObject)
    Set ObservedObject = ObjectCell.Load()
    Set ObservedObject = ObjectCell.CompareExchange(FirstObject, SecondObject)
    Set ObservedObject = ObjectCell.Load()
    Dim Messages As New MessageQueue
    Dim SentValue As Variant
    Dim ReceivedValue As Variant
    Dim NumberValue As Long
    SentValue = CreateLongVariant(42)
    Print Messages.Enqueue(SentValue)
    Print Messages.Dequeue(ReceivedValue, 0)
    Print TryGetVariantLong(ReceivedValue, NumberValue)
    Print NumberValue
    Print Messages.Dequeue(ReceivedValue, 0)
End Sub

Sub AddMany(ByVal Counter As AtomicLong)
    Dim Index As Long
    While Index < 1000
        Call Counter.Increment()
        Index = Index + 1
    Wend
End Sub

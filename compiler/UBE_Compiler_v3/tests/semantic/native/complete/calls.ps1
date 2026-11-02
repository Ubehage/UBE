Begin-Project 'argument-modes-and-control'
$change=@'
Public Sub Change(Optional ByRef first As Long = 10, Optional ByVal amount As Long = 2)
    first = first + amount
End Sub
'@
$positive=@'
Private Function IsPositive(ByVal value As Long) As Boolean
    IsPositive = value > 0
End Function
'@
$main=@'
Public Sub Main()
    Dim a As Long = 1
    Call Change(a)
    Call Change(amount:=3, first:=(a))
    Call Change(, amount:=4)
    Dim ok As Boolean = IsPositive(a) AndAlso IsPositive(0)
    If ok Then
        While a < 5
            a = a + 1
            Exit While
        Wend
    Else
        Exit Sub
    End If
End Sub
'@
Add-Source 0 app CallsApp CallsApp.bas ("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"CallsApp`"`nOption Explicit`nOption Compare Binary`nOption Base 0`n"+$change+"`n"+$positive+"`n"+$main)
D module module CallsApp callsapp package:app Void public (W module-name CallsApp 'Attribute UBE_Name = "CallsApp"') (W module-all $script:p.sources[0].text) ([ordered]@{region='region.module';source=0;privateModule=$false;headerAt=(W module-header 'UBE SOURCE 1 MODULE')})
D change sub Change change region.module Void public (W change-name Change 'Public Sub Change(Optional ByRef first As Long = 10, Optional ByVal amount As Long = 2)') (W change-declaration $change) ([ordered]@{writtenVisibility='Public';parameters=@('change.first','change.amount');region='region.change';resultNeutral='none';body=@('s.change.assign');terminator=(W change-end 'End Sub' $change);primitive='';typeForm='none'})
D change.first parameter first first region.change Long parameter (W first-name first 'Optional ByRef first As Long = 10') (W first-declaration 'Optional ByRef first As Long = 10') ([ordered]@{passing='ByRef';writtenPassing='ByRef';optional=$true;default='first.default';defaultValue='v.first.default';typeForm='As';writable=$true})
D change.amount parameter amount amount region.change Long parameter (W amount-name amount 'Optional ByVal amount As Long = 2') (W amount-declaration 'Optional ByVal amount As Long = 2') ([ordered]@{passing='ByVal';writtenPassing='ByVal';optional=$true;default='amount.default';defaultValue='v.amount.default';typeForm='As';writable=$true})
D positive function IsPositive ispositive region.module Boolean private (W positive-name IsPositive 'Private Function IsPositive(ByVal value As Long) As Boolean') (W positive-declaration $positive) ([ordered]@{writtenVisibility='Private';parameters=@('positive.value');region='region.positive';resultNeutral='False';body=@('s.positive.result');terminator=(W positive-end 'End Function');primitive='';typeForm='As'})
D positive.value parameter value value region.positive Long parameter (W positive-value-name value 'ByVal value As Long') (W positive-value-declaration 'ByVal value As Long') ([ordered]@{passing='ByVal';writtenPassing='ByVal';optional=$false;default='';defaultValue='';typeForm='As';writable=$true})
D main sub Main main region.module Void public (W main-name Main 'Public Sub Main()') (W main-declaration $main) ([ordered]@{writtenVisibility='Public';parameters=@();region='region.main';resultNeutral='none';body=@('s.a','s.call1','s.call2','s.call3','s.ok','s.if');terminator=(W main-end 'End Sub' $main);primitive='';typeForm='none'})
D a local a a region.main Long local (W a-name a 'Dim a As Long = 1') (W a-declaration 'Dim a As Long = 1') ([ordered]@{initializer='a.one';valueRoot='v.a.one';neutral='0';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
D ok local ok ok region.main Boolean local (W ok-name ok 'Dim ok As Boolean = IsPositive(a) AndAlso IsPositive(0)') (W ok-declaration 'Dim ok As Boolean = IsPositive(a) AndAlso IsPositive(0)') ([ordered]@{initializer='ok.andalso';valueRoot='v.ok.andalso';neutral='False';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
Region region.module module module @('change','positive','main')
Region region.change procedure change @('change.first','change.amount')
Region region.positive procedure positive @('positive.value') positive
Region region.main procedure main @('a','ok')
Attribute module.name (W module-attribute 'Attribute UBE_Name = "CallsApp"') module UBE_Name CallsApp (W module-value '"CallsApp"')
Add-Record options ([ordered]@{id='explicit';at=(W explicit 'Option Explicit');kind='Explicit';value='On'})
Add-Record options ([ordered]@{id='compare';at=(W compare 'Option Compare Binary');kind='Compare';value='Binary'})
Add-Record options ([ordered]@{id='base';at=(W base 'Option Base 0');kind='Base';value='0'})
T tr.first (W first-type Long 'Optional ByRef first As Long = 10') change.first parameter Long
T tr.amount (W amount-type Long 'Optional ByVal amount As Long = 2') change.amount parameter Long
T tr.positive.value (W positive-value-type Long 'ByVal value As Long') positive.value parameter Long
T tr.positive.result (W positive-result-type Boolean 'Private Function IsPositive(ByVal value As Long) As Boolean') positive result Boolean
T tr.a (W a-type Long 'Dim a As Long = 1') a local Long
T tr.ok (W ok-type Boolean 'Dim ok As Boolean = IsPositive(a) AndAlso IsPositive(0)') ok local Boolean
B b.change.target (W first-write first 'first = first + amount' 0) change.first assignment-target procedure
B b.change.first (W first-read first 'first = first + amount' 1) change.first read procedure
B b.change.amount (W amount-read amount 'first = first + amount') change.amount read procedure
B b.positive.result (W positive-result-use IsPositive 'IsPositive = value > 0') positive result-storage current-result
B b.positive.value (W positive-value-use value 'IsPositive = value > 0') positive.value read procedure
B b.call1.target (W call1-target Change 'Call Change(a)') change call-target own-module
B b.call1.a (W call1-a a 'Call Change(a)' 2) a argument-storage procedure
B b.call2.target (W call2-target Change 'Call Change(amount:=3, first:=(a))') change call-target own-module
B b.call2.amount-name (W call2-amount-name amount 'amount:=3') change.amount named-parameter signature
B b.call2.first-name (W call2-first-name first 'first:=(a)') change.first named-parameter signature
B b.call2.a (W call2-a a 'first:=(a)') a read procedure
B b.call3.target (W call3-target Change 'Call Change(, amount:=4)') change call-target own-module
B b.call3.amount-name (W call3-amount-name amount 'amount:=4') change.amount named-parameter signature
B b.ok.left.target (W ok-left-target IsPositive 'IsPositive(a)') positive call-target own-module
B b.ok.left.a (W ok-left-a a 'IsPositive(a)') a read procedure
B b.ok.right.target (W ok-right-target IsPositive 'IsPositive(0)') positive call-target own-module
B b.if.ok (W if-ok ok 'If ok Then') ok read procedure
B b.while.a (W while-a a 'a < 5') a read procedure
B b.increment.target (W increment-target a 'a = a + 1' 0) a assignment-target procedure
B b.increment.a (W increment-a a 'a = a + 1' 1) a read procedure
E first.default (W first-default 10 'Optional ByRef first As Long = 10') literal Long Long destination @() 10 '' none literal
E amount.default (W amount-default 2 'Optional ByVal amount As Long = 2') literal Long Long destination @() 2 '' none literal
E change.first first-read name Long Long fixed @() '' b.change.first read none
E change.amount amount-read name Long Long fixed @() '' b.change.amount read none
E change.add (W change-add 'first + amount') add Long Long fixed @('change.first','change.amount') '' '' left-to-right-eager none
E positive.value positive-value-use name Long '' fixed @() '' b.positive.value read none
E positive.zero (W positive-zero 0 'IsPositive = value > 0') literal Long '' default @() 0 '' none literal
E positive.compare (W positive-compare 'value > 0') greater Boolean '' fixed @('positive.value','positive.zero') '' '' left-to-right-eager none
E a.one (W a-one 1 'Dim a As Long = 1') literal Long Long destination @() 1 '' none literal
E call1.a call1-a name Long '' fixed @() '' b.call1.a locate-storage none
E call1 (W call1 'Call Change(a)') call Void '' fixed @('call1.a') '' b.call1.target call-left-to-right none
E call2.amount (W call2-three 3 'amount:=3') literal Long Long destination @() 3 '' none literal
E call2.a call2-a name Long Long fixed @() '' b.call2.a read none
E call2.group (W call2-group '(a)' 'first:=(a)') group Long Long fixed @('call2.a') '' '' group none
E call2 (W call2 'Call Change(amount:=3, first:=(a))') call Void '' fixed @('call2.amount','call2.group') '' b.call2.target call-left-to-right none
E call3.amount (W call3-four 4 'amount:=4') literal Long Long destination @() 4 '' none literal
E call3 (W call3 'Call Change(, amount:=4)') call Void '' fixed @('call3.amount') '' b.call3.target call-left-to-right none
E ok.a ok-left-a name Long Long fixed @() '' b.ok.left.a read none
E ok.left (W ok-left 'IsPositive(a)') call Boolean '' fixed @('ok.a') '' b.ok.left.target call-left-to-right none
E ok.zero (W ok-zero 0 'IsPositive(0)') literal Long Long destination @() 0 '' none literal
E ok.right (W ok-right 'IsPositive(0)') call Boolean '' fixed @('ok.zero') '' b.ok.right.target call-left-to-right none
E ok.andalso (W ok-andalso 'IsPositive(a) AndAlso IsPositive(0)') andalso Boolean '' fixed @('ok.left','ok.right') '' '' left-to-right-conditional-right none
E if.ok if-ok name Boolean '' fixed @() '' b.if.ok read none
E while.a while-a name Long '' fixed @() '' b.while.a read none
E while.five (W while-five 5 'a < 5') literal Long '' default @() 5 '' none literal
E while.compare (W while-compare 'a < 5') less Boolean '' fixed @('while.a','while.five') '' '' left-to-right-eager none
E increment.a increment-a name Long Long fixed @() '' b.increment.a read none
E increment.one (W increment-one 1 'a = a + 1') literal Long Long destination @() 1 '' none literal
E increment.add (W increment-add 'a + 1' 'a = a + 1') add Long Long fixed @('increment.a','increment.one') '' '' left-to-right-eager none
V v.first.default first.default constant Long @() '' '' 10 $false none
V v.amount.default amount.default constant Long @() '' '' 2 $false none
V v.change.first change.first read Long @() '' change.first '' $false read
V v.change.amount change.amount read Long @() '' change.amount '' $false read
V v.change.add change.add binary Long @('v.change.first','v.change.amount') + '' '' $true left-to-right-eager
V v.positive.value positive.value read Long @() '' positive.value '' $false read
V v.positive.zero positive.zero constant Long @() '' '' 0 $false none
V v.positive.compare positive.compare binary Boolean @('v.positive.value','v.positive.zero') '>' '' '' $false left-to-right-eager
V v.a.one a.one constant Long @() '' '' 1 $false none
V v.call1.a call1.a storage Long @() '' a '' $false locate-storage
V v.call1.default-amount amount.default constant Long @() '' '' 2 $false none
V v.call1 call1 call Void @('v.call1.a') '' change '' $false call-left-to-right
V v.call2.amount call2.amount constant Long @() '' '' 3 $false none
V v.call2.a call2.a read Long @() '' a '' $false read
V v.call2 call2 call Void @('v.call2.amount','v.call2.a') '' change '' $false call-left-to-right
V v.call3.default-first first.default constant Long @() '' '' 10 $false none
V v.call3.amount call3.amount constant Long @() '' '' 4 $false none
V v.call3 call3 call Void @('v.call3.amount') '' change '' $false call-left-to-right
V v.ok.a ok.a read Long @() '' a '' $false read
V v.ok.left ok.left call Boolean @('v.ok.a') '' positive '' $false call-left-to-right
V v.ok.zero ok.zero constant Long @() '' '' 0 $false none
V v.ok.right ok.right call Boolean @('v.ok.zero') '' positive '' $false call-left-to-right
V v.ok.andalso ok.andalso binary Boolean @('v.ok.left','v.ok.right') AndAlso '' '' $false left-to-right-conditional-right
V v.if.ok if.ok read Boolean @() '' ok '' $false read
V v.while.a while.a read Long @() '' a '' $false read
V v.while.five while.five constant Long @() '' '' 5 $false none
V v.while.compare while.compare binary Boolean @('v.while.a','v.while.five') '<' '' '' $false left-to-right-eager
V v.increment.a increment.a read Long @() '' a '' $false read
V v.increment.one increment.one constant Long @() '' '' 1 $false none
V v.increment.add increment.add binary Long @('v.increment.a','v.increment.one') + '' '' $true left-to-right-eager
C c.first.default first-default optional-default first.default change.first Long Long identity 10
C c.amount.default amount-default optional-default amount.default change.amount Long Long identity 2
C c.change.left first-read operand change.first change.add Long Long identity ''
C c.change.right amount-read operand change.amount change.add Long Long identity ''
C c.change.assign change-add assignment change.add change.first Long Long identity ''
C c.positive.left positive-value-use operand positive.value positive.compare Long Long identity ''
C c.positive.right positive-zero operand positive.zero positive.compare Long Long identity 0
C c.positive.result positive-compare result-assignment positive.compare positive Boolean Boolean identity ''
C c.a a-one variable-initializer a.one a Long Long identity 1
C c.call1.first call1-a argument call1.a change.first Long Long identity ''
C c.call1.amount (W call1-missing 'Call Change(a)' '' 0 end) default-argument amount.default change.amount Long Long identity 2
C c.call2.amount call2-three argument call2.amount change.amount Long Long identity 3
C c.call2.first call2-group argument call2.group change.first Long Long identity ''
C c.call3.first (W call3-omitted ',' 'Call Change(, amount:=4)' 0 start) default-argument first.default change.first Long Long identity 10
C c.call3.amount call3-four argument call3.amount change.amount Long Long identity 4
C c.ok.left.argument ok-left-a argument ok.a positive.value Long Long identity ''
C c.ok.right.argument ok-zero argument ok.zero positive.value Long Long identity 0
C c.ok.left ok-left operand ok.left ok.andalso Boolean Boolean identity ''
C c.ok.right ok-right operand ok.right ok.andalso Boolean Boolean identity ''
C c.ok.destination ok-andalso variable-initializer ok.andalso ok Boolean Boolean identity ''
C c.if if-ok condition if.ok s.if Boolean Boolean identity ''
C c.while.left while-a operand while.a while.compare Long Long identity ''
C c.while.right while-five operand while.five while.compare Long Long identity 5
C c.while.condition while-compare condition while.compare s.while Boolean Boolean identity ''
C c.increment.left increment-a operand increment.a increment.add Long Long identity ''
C c.increment.right increment-one operand increment.one increment.add Long Long identity 1
C c.increment.destination increment-add assignment increment.add a Long Long identity ''
$call1args=@(
 [ordered]@{slot=0;at='call1-a';nameAt='';expression='call1.a';value='v.call1.a';parameter='change.first';parameterIndex=0;mode='alias';conversion='c.call1.first';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'},
 [ordered]@{slot=-1;at='call1-missing';nameAt='';expression='';value='v.call1.default-amount';parameter='change.amount';parameterIndex=1;mode='default-value';conversion='c.call1.amount';defaultExpression='amount.default';freshTemporary=$false;discardWrites=$false;origin='missing'}
)
$call2args=@(
 [ordered]@{slot=0;at=(W call2-amount-slot 'amount:=3');nameAt='call2-amount-name';expression='call2.amount';value='v.call2.amount';parameter='change.amount';parameterIndex=1;mode='value';conversion='c.call2.amount';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'},
 [ordered]@{slot=1;at=(W call2-first-slot 'first:=(a)');nameAt='call2-first-name';expression='call2.group';value='v.call2.a';parameter='change.first';parameterIndex=0;mode='temporary';conversion='c.call2.first';defaultExpression='';freshTemporary=$true;discardWrites=$true;origin='written'}
)
$call3args=@(
 [ordered]@{slot=0;at='call3-omitted';nameAt='';expression='';value='v.call3.default-first';parameter='change.first';parameterIndex=0;mode='default-temporary';conversion='c.call3.first';defaultExpression='first.default';freshTemporary=$true;discardWrites=$true;origin='omitted'},
 [ordered]@{slot=1;at=(W call3-amount-slot 'amount:=4');nameAt='call3-amount-name';expression='call3.amount';value='v.call3.amount';parameter='change.amount';parameterIndex=1;mode='value';conversion='c.call3.amount';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'}
)
Add-Record calls ([ordered]@{id='call.change1';at='call1';expression='call1';target='change';resultType='Void';valueRoot='v.call1';form='Call-parenthesized';primitive='';nativeType='';sourceSlotCount=1;evaluationOrder=@(0);arguments=$call1args;parameterMap=@(0,-1);discardResult=$false})
Add-Record calls ([ordered]@{id='call.change2';at='call2';expression='call2';target='change';resultType='Void';valueRoot='v.call2';form='Call-parenthesized';primitive='';nativeType='';sourceSlotCount=2;evaluationOrder=@(0,1);arguments=$call2args;parameterMap=@(1,0);discardResult=$false})
Add-Record calls ([ordered]@{id='call.change3';at='call3';expression='call3';target='change';resultType='Void';valueRoot='v.call3';form='Call-parenthesized';primitive='';nativeType='';sourceSlotCount=2;evaluationOrder=@(1);arguments=$call3args;parameterMap=@(0,1);discardResult=$false})
Add-Record calls ([ordered]@{id='call.positive-left';at='ok-left';expression='ok.left';target='positive';resultType='Boolean';valueRoot='v.ok.left';form='expression-parenthesized';primitive='';nativeType='';sourceSlotCount=1;evaluationOrder=@(0);arguments=@([ordered]@{slot=0;at='ok-left-a';nameAt='';expression='ok.a';value='v.ok.a';parameter='positive.value';parameterIndex=0;mode='value';conversion='c.ok.left.argument';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'});parameterMap=@(0);discardResult=$false})
Add-Record calls ([ordered]@{id='call.positive-right';at='ok-right';expression='ok.right';target='positive';resultType='Boolean';valueRoot='v.ok.right';form='expression-parenthesized';primitive='';nativeType='';sourceSlotCount=1;evaluationOrder=@(0);arguments=@([ordered]@{slot=0;at='ok-zero';nameAt='';expression='ok.zero';value='v.ok.zero';parameter='positive.value';parameterIndex=0;mode='value';conversion='c.ok.right.argument';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'});parameterMap=@(0);discardResult=$false})
S s.change.assign (W change-assignment 'first = first + amount') assignment region.change ([ordered]@{target='change.first';targetBinding='b.change.target';expression='change.add';value='v.change.add';conversion='c.change.assign'})
S s.positive.result (W positive-result-statement 'IsPositive = value > 0') result-assignment region.positive ([ordered]@{target='positive';targetBinding='b.positive.result';expression='positive.compare';value='v.positive.compare';conversion='c.positive.result'})
S s.a a-declaration variable-declaration region.main ([ordered]@{declaration='a';establishNeutralBefore='a.one';expression='a.one';value='v.a.one';conversion='c.a'})
S s.call1 call1 call region.main ([ordered]@{call='call.change1'})
S s.call2 call2 call region.main ([ordered]@{call='call.change2'})
S s.call3 call3 call region.main ([ordered]@{call='call.change3'})
S s.ok ok-declaration variable-declaration region.main ([ordered]@{declaration='ok';establishNeutralBefore='ok.andalso';expression='ok.andalso';value='v.ok.andalso';conversion='c.ok.destination'})
S s.if (W if-statement "If ok Then`n        While a < 5`n            a = a + 1`n            Exit While`n        Wend`n    Else`n        Exit Sub`n    End If") if region.main ([ordered]@{condition='if.ok';value='v.if.ok';conversion='c.if';then=@('s.while');else=@('s.exit-sub')})
S s.while (W while-statement "While a < 5`n            a = a + 1`n            Exit While`n        Wend") while region.main ([ordered]@{condition='while.compare';value='v.while.compare';conversion='c.while.condition';body=@('s.increment','s.exit-while')})
S s.increment (W increment-statement 'a = a + 1') assignment region.main ([ordered]@{target='a';targetBinding='b.increment.target';expression='increment.add';value='v.increment.add';conversion='c.increment.destination'})
S s.exit-while (W exit-while 'Exit While') exit-while region.main ([ordered]@{loop='s.while';writtenKind='While'})
S s.exit-sub (W exit-sub 'Exit Sub') exit-sub region.main ([ordered]@{procedure='main';writtenKind='Sub'})
$script:p.entryPoint=[ordered]@{declaration='main';kind='Sub';resultType='Void';parameterCount=0;package='app'}
Finish-Project

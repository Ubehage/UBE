$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$homeDir=$PSScriptRoot
$utf8=New-Object Text.UTF8Encoding($false,$true)
$projects=New-Object 'System.Collections.Generic.List[object]'
$sections=@('sources','witnesses','regions','declarations','typeReferences','bindings','expressions','valueNodes','conversions','calls','statements','attributes','options')
function Begin-Project([string]$Id){
 $script:p=[ordered]@{id=$Id;outcome='checked';packages=@([ordered]@{id='app';kind='Exe';references=@()});entryPoint=$null;failure=$null}
 foreach($section in $sections){$script:p[$section]=New-Object 'System.Collections.Generic.List[object]'}
}
function Add-Source([int]$Id,[string]$Package,[string]$Module,[string]$File,[string]$Text){
 $Text=$Text.Replace("`r`n","`n").TrimEnd([char]10)+"`n"
 $directory=Join-Path $homeDir ('sources/'+$script:p.id);$null=New-Item -ItemType Directory -Path $directory -Force
 [IO.File]::WriteAllText((Join-Path $directory $File),$Text,$utf8)
 $script:p.sources.Add([ordered]@{id=$Id;package=$Package;module=$Module;file=('sources/'+$script:p.id+'/'+$File);text=$Text})
}
function W([string]$Id,[string]$Text,[string]$Within='',[int]$Occurrence=0,[string]$Mode='span',[int]$Source=0){
 $script:p.witnesses.Add([ordered]@{id=$Id;source=$Source;text=$Text;within=$Within;occurrence=$Occurrence;mode=$Mode})
 return $Id
}
function Add-Record([string]$Section,$Record){
 if($Section -ceq 'calls' -and -not $Record.Contains('moduleBinding')){$Record['moduleBinding']=''}
 $script:p[$Section].Add($Record)
}
function Region([string]$Id,[string]$Kind,[string]$Owner,[string[]]$Members,[string]$Result=''){
 Add-Record regions ([ordered]@{id=$Id;kind=$Kind;owner=$Owner;members=@($Members);resultTarget=$Result})
}
function D([string]$Id,[string]$Kind,[string]$Name,[string]$Canonical,[string]$Scope,[string]$Type,[string]$Visibility,[string]$NameAt,[string]$WholeAt,$Details){
 Add-Record declarations ([ordered]@{id=$Id;kind=$Kind;name=$Name;canonical=$Canonical;scope=$Scope;type=$Type;visibility=$Visibility;nameAt=$NameAt;wholeAt=$WholeAt;details=$Details})
}
function T([string]$Id,[string]$At,[string]$Owner,[string]$Role,[string]$Type,[string]$ModuleBinding='',[string]$NameAt=''){
 if($NameAt -eq ''){$NameAt=$At}
 Add-Record typeReferences ([ordered]@{id=$Id;at=$At;nameAt=$NameAt;owner=$Owner;role=$Role;type=$Type;moduleBinding=$ModuleBinding})
}
function B([string]$Id,[string]$At,[string]$Target,[string]$Role,[string]$Level){
 Add-Record bindings ([ordered]@{id=$Id;at=$At;target=$Target;role=$Role;level=$Level})
}
function E([string]$Id,[string]$At,[string]$Kind,[string]$Type,[string]$Context,[string]$Selection,[string[]]$Operands,[string]$Constant,[string]$Binding,[string]$Evaluation,[string]$Folding){
 Add-Record expressions ([ordered]@{id=$Id;at=$At;kind=$Kind;type=$Type;integerContext=$Context;selection=$Selection;operands=@($Operands);constant=$Constant;binding=$Binding;evaluation=$Evaluation;folding=$Folding})
}
function V([string]$Id,[string]$Origin,[string]$Kind,[string]$Type,[string[]]$Operands,[string]$Operation,[string]$Binding,[string]$Constant,[bool]$Checked,[string]$Evaluation){
 Add-Record valueNodes ([ordered]@{id=$Id;origin=$Origin;kind=$Kind;type=$Type;operands=@($Operands);operation=$Operation;binding=$Binding;constant=$Constant;checked=$Checked;evaluation=$Evaluation})
}
function C([string]$Id,[string]$At,[string]$Placement,[string]$Expression,[string]$Target,[string]$From,[string]$To,[string]$Mode,[string]$Constant){
 Add-Record conversions ([ordered]@{id=$Id;at=$At;placement=$Placement;expression=$Expression;target=$Target;from=$From;to=$To;mode=$Mode;constantResult=$Constant})
}
function S([string]$Id,[string]$At,[string]$Kind,[string]$Scope,$Details){
 Add-Record statements ([ordered]@{id=$Id;at=$At;kind=$Kind;scope=$Scope;details=$Details})
}
function Attribute([string]$Id,[string]$At,[string]$Target,[string]$Name,[string]$Value,[string]$ValueAt){
 Add-Record attributes ([ordered]@{id=$Id;at=$At;target=$Target;name=$Name;value=$Value;valueAt=$ValueAt})
}
function Finish-Project{
 $result=[ordered]@{}
 foreach($key in $script:p.Keys){if($sections -contains $key){$result[$key]=$script:p[$key].ToArray()}else{$result[$key]=$script:p[$key]}}
 switch($script:p.id){
  'scalar-context-and-storage'{$result['expectedCounts']=[ordered]@{sources=1;regions=3;declarations=8;typeReferences=7;bindings=8;expressions=15;valueNodes=11;conversions=15;calls=1;statements=5;attributes=1;options=1}}
  'explicit-native-library'{$result['expectedCounts']=[ordered]@{sources=2;regions=5;declarations=12;typeReferences=10;bindings=15;expressions=11;valueNodes=11;conversions=11;calls=2;statements=7;attributes=4;options=0}}
  'argument-modes-and-control'{$result['expectedCounts']=[ordered]@{sources=1;regions=4;declarations=9;typeReferences=6;bindings=20;expressions=29;valueNodes=30;conversions=27;calls=5;statements=12;attributes=1;options=3}}
  'duplicate-folded-name-preserves-result'{$result['expectedCounts']=[ordered]@{sources=1;regions=0;declarations=0;typeReferences=0;bindings=0;expressions=0;valueNodes=0;conversions=0;calls=0;statements=0;attributes=0;options=0}}
 }
 $projects.Add($result)
}

Begin-Project 'scalar-context-and-storage'
$const='Private Const Offset As Long = 2'
$add=@'
Private Function AddOffset(ByVal value As Long) As Long
    AddOffset = value + Offset
End Function
'@
$main=@'
Public Function Main() As Long
    Dim small As Integer = 40000 - 10000
    Dim wide As LongLong = 2147483647 + 1
    Dim self As Long = self + Offset
    Main = AddOffset(small)
End Function
'@
Add-Source 0 app ScalarApp ScalarApp.bas ("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"ScalarApp`"`nOption Explicit`n"+$const+"`n"+$add+"`n"+$main)
$m=W module 'ScalarApp' 'Attribute UBE_Name = "ScalarApp"';$mh=W module-header 'UBE SOURCE 1 MODULE'
Attribute module-name (W module-attribute 'Attribute UBE_Name = "ScalarApp"') module UBE_Name ScalarApp (W module-value '"ScalarApp"')
Add-Record options ([ordered]@{id='explicit';at=(W explicit 'Option Explicit');kind='Explicit';value='On'})
D module module ScalarApp scalarapp package:app Void public $m (W module-all $script:p.sources[0].text) ([ordered]@{region='region.module';source=0;privateModule=$false;headerAt=$mh})
D offset constant Offset offset region.module Long private (W offset-name Offset $const) (W offset-declaration $const) ([ordered]@{writtenVisibility='Private';initializer='offset.literal';valueRoot='v.offset';constant='2';typeForm='As'})
D add function AddOffset addoffset region.module Long private (W add-name AddOffset 'Private Function AddOffset(ByVal value As Long) As Long') (W add-declaration $add) ([ordered]@{writtenVisibility='Private';parameters=@('add.value');region='region.add';resultNeutral='0';body=@('s.add.result');terminator=(W add-end 'End Function' $add);primitive='';typeForm='As'})
D add.value parameter value value region.add Long parameter (W add-value-name value 'ByVal value As Long') (W add-value-declaration 'ByVal value As Long') ([ordered]@{passing='ByVal';writtenPassing='ByVal';optional=$false;default='';defaultValue='';typeForm='As';writable=$true})
D main function Main main region.module Long public (W main-name Main 'Public Function Main() As Long') (W main-declaration $main) ([ordered]@{writtenVisibility='Public';parameters=@();region='region.main';resultNeutral='0';body=@('s.small','s.wide','s.self','s.main.result');terminator=(W main-end 'End Function' $main);primitive='';typeForm='As'})
D small local small small region.main Integer local (W small-name small 'Dim small As Integer = 40000 - 10000') (W small-declaration 'Dim small As Integer = 40000 - 10000') ([ordered]@{initializer='small.subtract';valueRoot='v.small';neutral='0';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
D wide local wide wide region.main LongLong local (W wide-name wide 'Dim wide As LongLong = 2147483647 + 1') (W wide-declaration 'Dim wide As LongLong = 2147483647 + 1') ([ordered]@{initializer='wide.add';valueRoot='v.wide';neutral='0';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
D self local self self region.main Long local (W self-name self 'Dim self As Long = self + Offset' 0) (W self-declaration 'Dim self As Long = self + Offset') ([ordered]@{initializer='self.add';valueRoot='v.self.add';neutral='0';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
Region region.module module module @('offset','add','main')
Region region.add procedure add @('add.value') add
Region region.main procedure main @('small','wide','self') main
T tr.offset (W offset-type Long $const) offset constant Long
T tr.add.value (W add-value-type Long 'Private Function AddOffset(ByVal value As Long) As Long' 0) add.value parameter Long
T tr.add.result (W add-result-type Long 'Private Function AddOffset(ByVal value As Long) As Long' 1) add result Long
T tr.main.result (W main-result-type Long 'Public Function Main() As Long') main result Long
T tr.small (W small-type Integer 'Dim small As Integer = 40000 - 10000') small local Integer
T tr.wide (W wide-type LongLong 'Dim wide As LongLong = 2147483647 + 1') wide local LongLong
T tr.self (W self-type Long 'Dim self As Long = self + Offset') self local Long
B b.add.result (W add-result-use AddOffset 'AddOffset = value + Offset') add result-storage current-result
B b.add.value (W add-value-use value 'AddOffset = value + Offset') add.value read procedure
B b.add.offset (W add-offset-use Offset 'AddOffset = value + Offset' 1) offset constant-read own-module
B b.self.self (W self-self-use self 'Dim self As Long = self + Offset' 1) self read procedure
B b.self.offset (W self-offset-use Offset 'Dim self As Long = self + Offset') offset constant-read own-module
B b.main.result (W main-result-use Main 'Main = AddOffset(small)') main result-storage current-result
B b.main.add (W main-add-use AddOffset 'Main = AddOffset(small)') add call-target own-module
B b.main.small (W main-small-use small 'Main = AddOffset(small)') small read procedure
E offset.literal (W offset-literal 2 $const) literal Long Long destination @() 2 '' none literal
E add.value-use add-value-use name Long Long fixed @() '' b.add.value read none
E add.offset-use add-offset-use name Long Long fixed @() 2 b.add.offset constant constant-reference
E add.sum (W add-sum 'value + Offset' 'AddOffset = value + Offset') add Long Long fixed @('add.value-use','add.offset-use') '' '' left-to-right-eager none
E small.left (W small-left 40000 'Dim small As Integer = 40000 - 10000') literal Long Integer widened-destination @() 40000 '' none literal
E small.right (W small-right 10000 'Dim small As Integer = 40000 - 10000') literal Integer Integer destination @() 10000 '' none literal
E small.subtract (W small-subtract '40000 - 10000' 'Dim small As Integer = 40000 - 10000') subtract Long Integer fixed @('small.left','small.right') 30000 '' left-to-right-eager required-literal-arithmetic
E wide.left (W wide-left 2147483647 'Dim wide As LongLong = 2147483647 + 1') literal LongLong LongLong destination @() 2147483647 '' none literal
E wide.right (W wide-right 1 'Dim wide As LongLong = 2147483647 + 1' 1) literal LongLong LongLong destination @() 1 '' none literal
E wide.add (W wide-add '2147483647 + 1' 'Dim wide As LongLong = 2147483647 + 1') add LongLong LongLong fixed @('wide.left','wide.right') 2147483648 '' left-to-right-eager required-literal-arithmetic
E self.read self-self-use name Long Long fixed @() '' b.self.self read none
E self.offset self-offset-use name Long Long fixed @() 2 b.self.offset constant constant-reference
E self.add (W self-add 'self + Offset' 'Dim self As Long = self + Offset') add Long Long fixed @('self.read','self.offset') '' '' left-to-right-eager none
E main.small main-small-use name Integer Long fixed @() '' b.main.small read none
E main.call (W main-call 'AddOffset(small)' 'Main = AddOffset(small)') call Long Long fixed @('main.small') '' b.main.add call-left-to-right none
V v.offset offset.literal constant Long @() '' '' 2 $false none
V v.add.value add.value-use read Long @() '' add.value '' $false read
V v.add.offset add.offset-use constant Long @() '' offset 2 $false none
V v.add.sum add.sum binary Long @('v.add.value','v.add.offset') + '' '' $true left-to-right-eager
V v.small small.subtract constant Long @() '' '' 30000 $false none
V v.wide wide.add constant LongLong @() '' '' 2147483648 $false none
V v.self.read self.read read Long @() '' self '' $false read
V v.self.offset self.offset constant Long @() '' offset 2 $false none
V v.self.add self.add binary Long @('v.self.read','v.self.offset') + '' '' $true left-to-right-eager
V v.main.small main.small read Integer @() '' small '' $false read
V v.main.call main.call call Long @('v.main.small') '' add '' $false call-left-to-right
C c.offset offset-literal constant-initializer offset.literal offset Long Long identity 2
C c.add.left add-value-use operand add.value-use add.sum Long Long identity ''
C c.add.right add-offset-use operand add.offset-use add.sum Long Long identity 2
C c.add.result add-sum result-assignment add.sum add Long Long identity ''
C c.small.left small-left operand small.left small.subtract Long Long identity 40000
C c.small.right small-right operand small.right small.subtract Integer Long checked 10000
C c.small.destination small-subtract variable-initializer small.subtract small Long Integer checked 30000
C c.wide.left wide-left operand wide.left wide.add LongLong LongLong identity 2147483647
C c.wide.right wide-right operand wide.right wide.add LongLong LongLong identity 1
C c.wide.destination wide-add variable-initializer wide.add wide LongLong LongLong identity 2147483648
C c.self.left self-self-use operand self.read self.add Long Long identity ''
C c.self.right self-offset-use operand self.offset self.add Long Long identity 2
C c.self.destination self-add variable-initializer self.add self Long Long identity ''
C c.main.argument main-small-use argument main.small add.value Integer Long checked ''
C c.main.result main-call result-assignment main.call main Long Long identity ''
Add-Record calls ([ordered]@{id='call.main.add';at='main-call';expression='main.call';target='add';resultType='Long';valueRoot='v.main.call';form='expression-parenthesized';primitive='';nativeType='';moduleBinding='';sourceSlotCount=1;evaluationOrder=@(0);arguments=@([ordered]@{slot=0;at='main-small-use';nameAt='';expression='main.small';value='v.main.small';parameter='add.value';parameterIndex=0;mode='value';conversion='c.main.argument';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'});parameterMap=@(0);discardResult=$false})
S s.add.result (W add-result-statement 'AddOffset = value + Offset') result-assignment region.add ([ordered]@{target='add';targetBinding='b.add.result';expression='add.sum';value='v.add.sum';conversion='c.add.result'})
S s.small small-declaration variable-declaration region.main ([ordered]@{declaration='small';establishNeutralBefore='small.subtract';expression='small.subtract';value='v.small';conversion='c.small.destination'})
S s.wide wide-declaration variable-declaration region.main ([ordered]@{declaration='wide';establishNeutralBefore='wide.add';expression='wide.add';value='v.wide';conversion='c.wide.destination'})
S s.self self-declaration variable-declaration region.main ([ordered]@{declaration='self';establishNeutralBefore='self.add';expression='self.add';value='v.self.add';conversion='c.self.destination'})
S s.main.result (W main-result-statement 'Main = AddOffset(small)') result-assignment region.main ([ordered]@{target='main';targetBinding='b.main.result';expression='main.call';value='v.main.call';conversion='c.main.result'})
$script:p.entryPoint=[ordered]@{declaration='main';kind='Function';resultType='Long';parameterCount=0;package='app'}
Finish-Project

. (Join-Path $homeDir 'native.ps1')
. (Join-Path $homeDir 'calls.ps1')
. (Join-Path $homeDir 'failure.ps1')
$manifests=@{
 'sources/scalar-context-and-storage/ScalarContext.UBE'="UBE-Project 1`nName = `"ScalarContext`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"ScalarApp.bas`"`n";
 'sources/explicit-native-library/NativeConsumer.UBE'="UBE-Project 1`nName = `"NativeConsumer`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"NativeApp.bas`"`nReference = `"UBECore.UBE`"`n";
 'sources/explicit-native-library/UBECore.UBE'="UBE-Project 1`nName = `"UBECore`"`nKind = `"Library`"`nSource = `"NativeBytes.bas`"`n";
 'sources/argument-modes-and-control/ArgumentModes.UBE'="UBE-Project 1`nName = `"ArgumentModes`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"CallsApp.bas`"`n";
 'sources/duplicate-folded-name-preserves-result/DuplicateNames.UBE'="UBE-Project 1`nName = `"DuplicateNames`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"Broken.bas`"`n"
}
foreach($entry in $manifests.GetEnumerator()){[IO.File]::WriteAllText((Join-Path $homeDir $entry.Key),$entry.Value,$utf8)}
$package=[ordered]@{schema='ube-complete-semantic-oracles-draft-1';definitionOnly=$true;semanticImplemented=$false;builtinTypes=@('Void','Boolean','Byte','Integer','Long','LongLong');projects=$projects.ToArray()}
$destination=Join-Path $homeDir 'complete.json'
[IO.File]::WriteAllText($destination,($package|ConvertTo-Json -Depth 80)+"`n",$utf8)
Write-Output "Authored definitions: $destination"

Begin-Project 'explicit-native-library'
$script:p.packages=@([ordered]@{id='app';kind='Exe';references=@('ubecore')},[ordered]@{id='ubecore';kind='Library';references=@()})
$main=@'
Public Function Main() As Long
    Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)
    Dim copy As NativeBytes.Octet = item
    Dim raw As Byte = NativeBytes.ReadByte(copy)
    Dim same As Boolean = item = copy
    If same Then
        raw = 9
    End If
    Main = 0
End Function
'@
$native=@'
Public Type Octet As Byte
End Type
'@
$pack=@'
Public Intrinsic Function CreateByte(ByVal bits As Byte) As Octet
Attribute CreateByte.UBE_Primitive = "Value.Pack"
End Function
'@
$unpack=@'
Public Intrinsic Function ReadByte(ByVal boxed As Octet) As Byte
Attribute ReadByte.UBE_Primitive = "Value.Unpack"
End Function
'@
Add-Source 0 app NativeApp NativeApp.bas ("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"NativeApp`"`n"+$main)
Add-Source 1 ubecore NativeBytes NativeBytes.bas ("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"NativeBytes`"`n"+$native+"`n"+$pack+"`n"+$unpack)
D app.module module NativeApp nativeapp package:app Void public (W app-module-name NativeApp 'Attribute UBE_Name = "NativeApp"') (W app-module-all $script:p.sources[0].text) ([ordered]@{region='region.app-module';source=0;privateModule=$false;headerAt=(W app-header 'UBE SOURCE 1 MODULE')})
D main function Main main region.app-module Long public (W main-name Main 'Public Function Main() As Long') (W main-declaration $main) ([ordered]@{writtenVisibility='Public';parameters=@();region='region.main';resultNeutral='0';body=@('s.item','s.copy','s.raw','s.same','s.if','s.result');terminator=(W main-end 'End Function');primitive='';typeForm='As'})
D item local item item region.main native:octet local (W item-name item 'Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)') (W item-declaration 'Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)') ([ordered]@{initializer='item.pack';valueRoot='v.item.pack';neutral='native-neutral';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
D copy local copy copy region.main native:octet local (W copy-name copy 'Dim copy As NativeBytes.Octet = item') (W copy-declaration 'Dim copy As NativeBytes.Octet = item') ([ordered]@{initializer='copy.item';valueRoot='v.copy.item';neutral='native-neutral';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
D raw local raw raw region.main Byte local (W raw-name raw 'Dim raw As Byte = NativeBytes.ReadByte(copy)') (W raw-declaration 'Dim raw As Byte = NativeBytes.ReadByte(copy)') ([ordered]@{initializer='raw.unpack';valueRoot='v.raw.unpack';neutral='0';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
D same local same same region.main Boolean local (W same-name same 'Dim same As Boolean = item = copy') (W same-declaration 'Dim same As Boolean = item = copy') ([ordered]@{initializer='same.equal';valueRoot='v.same.equal';neutral='False';establishedBeforeInitializer=$true;survivesRuntimeInitializerFailure=$true;typeForm='As';writable=$true})
D lib.module module NativeBytes nativebytes package:ubecore Void public (W lib-module-name NativeBytes 'Attribute UBE_Name = "NativeBytes"' 0 span 1) (W lib-module-all $script:p.sources[1].text '' 0 span 1) ([ordered]@{region='region.lib-module';source=1;privateModule=$false;headerAt=(W lib-header 'UBE SOURCE 1 MODULE' '' 0 span 1)})
D octet native-type Octet octet region.lib-module native:octet public (W octet-name Octet 'Public Type Octet As Byte' 0 span 1) (W octet-declaration $native '' 0 span 1) ([ordered]@{writtenVisibility='Public';representation='Byte';terminator=(W octet-end 'End Type' '' 0 span 1);pack='pack';unpack='unpack'})
D pack function CreateByte createbyte region.lib-module native:octet public (W pack-name CreateByte 'Public Intrinsic Function CreateByte(ByVal bits As Byte) As Octet' 0 span 1) (W pack-declaration $pack '' 0 span 1) ([ordered]@{writtenVisibility='Public';parameters=@('pack.bits');region='region.pack';resultNeutral='native-neutral';body=@();terminator=(W pack-end 'End Function' $pack 0 span 1);primitive='Value.Pack';typeForm='As'})
D pack.bits parameter bits bits region.pack Byte parameter (W bits-name bits 'ByVal bits As Byte' 0 span 1) (W bits-declaration 'ByVal bits As Byte' '' 0 span 1) ([ordered]@{passing='ByVal';writtenPassing='ByVal';optional=$false;default='';defaultValue='';typeForm='As';writable=$true})
D unpack function ReadByte readbyte region.lib-module Byte public (W unpack-name ReadByte 'Public Intrinsic Function ReadByte(ByVal boxed As Octet) As Byte' 0 span 1) (W unpack-declaration $unpack '' 0 span 1) ([ordered]@{writtenVisibility='Public';parameters=@('unpack.boxed');region='region.unpack';resultNeutral='0';body=@();terminator=(W unpack-end 'End Function' $unpack 0 span 1);primitive='Value.Unpack';typeForm='As'})
D unpack.boxed parameter boxed boxed region.unpack native:octet parameter (W boxed-name boxed 'ByVal boxed As Octet' 0 span 1) (W boxed-declaration 'ByVal boxed As Octet' '' 0 span 1) ([ordered]@{passing='ByVal';writtenPassing='ByVal';optional=$false;default='';defaultValue='';typeForm='As';writable=$true})
Region region.app-module module app.module @('main')
Region region.main procedure main @('item','copy','raw','same') main
Region region.lib-module module lib.module @('octet','pack','unpack')
Region region.pack procedure pack @('pack.bits') pack
Region region.unpack procedure unpack @('unpack.boxed') unpack
Attribute app.name (W app-name-attribute 'Attribute UBE_Name = "NativeApp"') app.module UBE_Name NativeApp (W app-name-value '"NativeApp"')
Attribute lib.name (W lib-name-attribute 'Attribute UBE_Name = "NativeBytes"' '' 0 span 1) lib.module UBE_Name NativeBytes (W lib-name-value '"NativeBytes"' '' 0 span 1)
Attribute pack.role (W pack-role-attribute 'Attribute CreateByte.UBE_Primitive = "Value.Pack"' '' 0 span 1) pack UBE_Primitive Value.Pack (W pack-role-value '"Value.Pack"' '' 0 span 1)
Attribute unpack.role (W unpack-role-attribute 'Attribute ReadByte.UBE_Primitive = "Value.Unpack"' '' 0 span 1) unpack UBE_Primitive Value.Unpack (W unpack-role-value '"Value.Unpack"' '' 0 span 1)
T tr.main (W main-type Long 'Public Function Main() As Long') main result Long
T tr.item (W item-type NativeBytes.Octet 'Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)') item local native:octet b.item.type-module (W item-native-member Octet 'Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)')
T tr.copy (W copy-type NativeBytes.Octet 'Dim copy As NativeBytes.Octet = item') copy local native:octet b.copy.type-module (W copy-native-member Octet 'Dim copy As NativeBytes.Octet = item')
T tr.raw (W raw-type Byte 'Dim raw As Byte = NativeBytes.ReadByte(copy)' 0) raw local Byte
T tr.same (W same-type Boolean 'Dim same As Boolean = item = copy') same local Boolean
T tr.representation (W representation-type Byte 'Public Type Octet As Byte' 0 span 1) octet representation Byte
T tr.bits (W bits-type Byte 'ByVal bits As Byte' 0 span 1) pack.bits parameter Byte
T tr.pack.result (W pack-result-type Octet 'Public Intrinsic Function CreateByte(ByVal bits As Byte) As Octet' 0 span 1) pack result native:octet
T tr.boxed (W boxed-type Octet 'ByVal boxed As Octet' 0 span 1) unpack.boxed parameter native:octet
T tr.unpack.result (W unpack-result-type Byte 'Public Intrinsic Function ReadByte(ByVal boxed As Octet) As Byte' 1 span 1) unpack result Byte
B b.item.type-module (W item-type-module NativeBytes 'Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)' 0) lib.module type-module-qualifier direct-reference
B b.copy.type-module (W copy-type-module NativeBytes 'Dim copy As NativeBytes.Octet = item') lib.module type-module-qualifier direct-reference
B b.item.call-module (W item-call-module NativeBytes 'Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)' 1) lib.module call-module-qualifier direct-reference
B b.item.pack (W item-pack-target CreateByte 'Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)') pack call-target qualified-module
B b.copy.item (W copy-item-read item 'Dim copy As NativeBytes.Octet = item') item read procedure
B b.raw.call-module (W raw-call-module NativeBytes 'Dim raw As Byte = NativeBytes.ReadByte(copy)') lib.module call-module-qualifier direct-reference
B b.raw.unpack (W raw-unpack-target ReadByte 'Dim raw As Byte = NativeBytes.ReadByte(copy)') unpack call-target qualified-module
B b.raw.copy (W raw-copy-read copy 'Dim raw As Byte = NativeBytes.ReadByte(copy)') copy read procedure
B b.same.item (W same-item-read item 'Dim same As Boolean = item = copy') item read procedure
B b.same.copy (W same-copy-read copy 'Dim same As Boolean = item = copy') copy read procedure
B b.if.same (W if-same-read same 'If same Then') same read procedure
B b.raw.target (W raw-write raw 'raw = 9') raw assignment-target procedure
B b.main.result (W main-result-use Main 'Main = 0') main result-storage current-result
B b.pack.attribute (W pack-attribute-target CreateByte 'Attribute CreateByte.UBE_Primitive = "Value.Pack"' 0 span 1) pack attribute-target enclosing-declaration
B b.unpack.attribute (W unpack-attribute-target ReadByte 'Attribute ReadByte.UBE_Primitive = "Value.Unpack"' 0 span 1) unpack attribute-target enclosing-declaration
E item.bits (W item-bits 7 'NativeBytes.CreateByte(7)') literal Byte Byte destination @() 7 '' none literal
E item.pack (W item-pack-call 'NativeBytes.CreateByte(7)') call native:octet '' fixed @('item.bits') '' b.item.pack call-left-to-right none
E copy.item copy-item-read name native:octet '' fixed @() '' b.copy.item read none
E raw.copy raw-copy-read name native:octet '' fixed @() '' b.raw.copy read none
E raw.unpack (W raw-unpack-call 'NativeBytes.ReadByte(copy)') call Byte Byte fixed @('raw.copy') '' b.raw.unpack call-left-to-right none
E same.item same-item-read name native:octet '' fixed @() '' b.same.item read none
E same.copy same-copy-read name native:octet '' fixed @() '' b.same.copy read none
E same.equal (W same-equality 'item = copy' 'Dim same As Boolean = item = copy') equal Boolean '' fixed @('same.item','same.copy') '' '' left-to-right-eager none
E if.same if-same-read name Boolean '' fixed @() '' b.if.same read none
E raw.nine (W raw-nine 9 'raw = 9') literal Byte Byte destination @() 9 '' none literal
E main.zero (W main-zero 0 'Main = 0') literal Long Long destination @() 0 '' none literal
V v.item.bits item.bits constant Byte @() '' '' 7 $false none
V v.item.pack item.pack call native:octet @('v.item.bits') '' pack '' $false call-left-to-right
V v.copy.item copy.item read native:octet @() '' item '' $false read
V v.raw.copy raw.copy read native:octet @() '' copy '' $false read
V v.raw.unpack raw.unpack call Byte @('v.raw.copy') '' unpack '' $false call-left-to-right
V v.same.item same.item read native:octet @() '' item '' $false read
V v.same.copy same.copy read native:octet @() '' copy '' $false read
V v.same.equal same.equal binary Boolean @('v.same.item','v.same.copy') = '' '' $false left-to-right-eager
V v.if.same if.same read Boolean @() '' same '' $false read
V v.raw.nine raw.nine constant Byte @() '' '' 9 $false none
V v.main.zero main.zero constant Long @() '' '' 0 $false none
C c.pack.bits item-bits argument item.bits pack.bits Byte Byte identity 7
C c.item item-pack-call variable-initializer item.pack item native:octet native:octet identity ''
C c.copy copy-item-read variable-initializer copy.item copy native:octet native:octet identity ''
C c.unpack.boxed raw-copy-read argument raw.copy unpack.boxed native:octet native:octet identity ''
C c.raw raw-unpack-call variable-initializer raw.unpack raw Byte Byte identity ''
C c.same.left same-item-read operand same.item same.equal native:octet native:octet identity ''
C c.same.right same-copy-read operand same.copy same.equal native:octet native:octet identity ''
C c.same same-equality variable-initializer same.equal same Boolean Boolean identity ''
C c.if if-same-read condition if.same s.if Boolean Boolean identity ''
C c.raw.nine raw-nine assignment raw.nine raw Byte Byte identity 9
C c.main main-zero result-assignment main.zero main Long Long identity 0
Add-Record calls ([ordered]@{id='call.pack';at='item-pack-call';expression='item.pack';target='pack';resultType='native:octet';valueRoot='v.item.pack';form='expression-parenthesized';primitive='Value.Pack';nativeType='native:octet';moduleBinding='b.item.call-module';sourceSlotCount=1;evaluationOrder=@(0);arguments=@([ordered]@{slot=0;at='item-bits';nameAt='';expression='item.bits';value='v.item.bits';parameter='pack.bits';parameterIndex=0;mode='value';conversion='c.pack.bits';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'});parameterMap=@(0);discardResult=$false})
Add-Record calls ([ordered]@{id='call.unpack';at='raw-unpack-call';expression='raw.unpack';target='unpack';resultType='Byte';valueRoot='v.raw.unpack';form='expression-parenthesized';primitive='Value.Unpack';nativeType='native:octet';moduleBinding='b.raw.call-module';sourceSlotCount=1;evaluationOrder=@(0);arguments=@([ordered]@{slot=0;at='raw-copy-read';nameAt='';expression='raw.copy';value='v.raw.copy';parameter='unpack.boxed';parameterIndex=0;mode='value';conversion='c.unpack.boxed';defaultExpression='';freshTemporary=$false;discardWrites=$false;origin='written'});parameterMap=@(0);discardResult=$false})
S s.item item-declaration variable-declaration region.main ([ordered]@{declaration='item';establishNeutralBefore='item.pack';expression='item.pack';value='v.item.pack';conversion='c.item';copySemantics='independent-value-copy'})
S s.copy copy-declaration variable-declaration region.main ([ordered]@{declaration='copy';establishNeutralBefore='copy.item';expression='copy.item';value='v.copy.item';conversion='c.copy';copySemantics='independent-value-copy'})
S s.raw raw-declaration variable-declaration region.main ([ordered]@{declaration='raw';establishNeutralBefore='raw.unpack';expression='raw.unpack';value='v.raw.unpack';conversion='c.raw'})
S s.same same-declaration variable-declaration region.main ([ordered]@{declaration='same';establishNeutralBefore='same.equal';expression='same.equal';value='v.same.equal';conversion='c.same'})
S s.if (W if-statement "If same Then`n        raw = 9`n    End If") if region.main ([ordered]@{condition='if.same';value='v.if.same';conversion='c.if';then=@('s.raw.nine');else=@()})
S s.raw.nine (W raw-nine-statement 'raw = 9') assignment region.main ([ordered]@{target='raw';targetBinding='b.raw.target';expression='raw.nine';value='v.raw.nine';conversion='c.raw.nine'})
S s.result (W main-result-statement 'Main = 0') result-assignment region.main ([ordered]@{target='main';targetBinding='b.main.result';expression='main.zero';value='v.main.zero';conversion='c.main'})
$script:p.entryPoint=[ordered]@{declaration='main';kind='Function';resultType='Long';parameterCount=0;package='app'}
Finish-Project

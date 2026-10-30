# VB6/VBA7 objects, constants, controls, and compatibility boundaries

Status: reference inventory for the finished library; no listed API is
implemented by the fresh UBECore. Reviewed on 2026-10-30.

This companion to [the runtime inventory](vb6-runtime.md) records the surface
that would otherwise disappear behind the phrase “the VB6 runtime.” Inclusion
means the name or capability must receive a disposition. It does not freeze a
signature, promise COM binary compatibility, or place every component in the
portable UBECore project.

Microsoft distinguishes the VB6 base runtime from runtime extended files and
other supplied components [S1]. The inventory follows that distinction. VBA
references below establish shared language-library members and constant names;
Office application objects and Microsoft Forms 2.0 are not the VB6 UI library.
VBA7 is included as requested, with its additions separated from the VB6
baseline and from the currently frozen UBE contract.

## Placement and evidence labels

- **Core candidate:** ordinary portable API or constant proposed for UBECore;
  its complete declaration and behavior still need review.
- **Required UBE behavior:** already governed by the normative UBE contract;
  a VB6 compatibility name must obey that contract.
- **Framework candidate:** native UI, graphics, printing, or component service
  in a separate library, with explicit platform adapters.
- **Compatibility candidate:** optional, explicit platform/COM support whose
  inclusion and semantics need an owner decision.
- **Member reconciliation:** named review checklist, not a verified complete
  class definition. Original VB6 type-library/member evidence is still required.

Exact function inventories for `CreateObject`, `GetObject`, `CallByName`,
`LoadPicture`, `LoadResPicture`, `LoadResData`, `LoadResString`, `SavePicture`,
`MsgBox`, `InputBox`, `AppActivate`, `Shell`, and `DoEvents` are owned by
[vb6-runtime.md](vb6-runtime.md). They are not counted again here as callable
definitions.

## Shared runtime objects

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| `Err` / `ErrObject` | Global error facade / class | Current execution thread's recoverable error record. | Required UBE behavior; no automatic modal failure UI. | [S2], [U1] |
| `Err.Number` | Property | Error identity. | Required UBE behavior; successful operations retain earlier error state. | [S2], [U1] |
| `Err.Description` | Property | Human-readable error detail. | Core candidate; define deterministic fallback/localization policy. | [S2] |
| `Err.Source` | Property | Error origin. | Core candidate; avoid exposing raw addresses. | [S2] |
| `Err.HelpFile` | Property | Legacy help-document metadata. | Compatibility candidate; optional metadata, not an installed help dependency. | [S2] |
| `Err.HelpContext` | Property | Legacy help-topic identifier. | Compatibility candidate. | [S2] |
| `Err.LastDllError` | Property | Error from a native-library transition. | Platform/ABI candidate; cannot assume a Windows error namespace in portable code. | [S3] |
| `Err.Clear` | Method | Explicitly clear the current thread's error. | Required UBE behavior; do not import VBA's implicit-clear rules. | [S2], [U1] |
| `Err.Raise` | Method | Explicitly record/raise a recoverable error. | Core compatibility candidate; trapping and caller propagation must follow UBE decisions. | [S2], [U1] |
| `Collection` | Class | Ordered heterogeneous items with optional keys. | Core candidate; key comparison, duplicate keys, mutation during iteration, and copying need contracts. | [S4] |
| `Collection.Add` | Method | Insert an item, optionally keyed or positioned. | Core candidate. | [S4] |
| `Collection.Item` | Indexed member | Retrieve by position or key. | Core candidate; explicit indexed default-member support, not hidden scalar conversion. | [S4], [U1] |
| `Collection.Remove` | Method | Remove a selected item. | Core candidate. | [S4] |
| `Collection.Count` | Property | Item count. | Core candidate; choose a range appropriate to 64-bit UBE. | [S4] |
| `Collection` enumeration | Iteration protocol | `For Each` traversal. | Compiler/library boundary; keep any foreign `_NewEnum` bridge separate from the public UBE protocol. | [S4], [U1] |

## VB6 globals and supporting object types

The member clusters below are a reconciliation checklist. [S5] documents
selected VB6 globals in Microsoft's migration material; that material is not
an exhaustive original VB6 member catalog. [S6] confirms native executable
information in `App`. Unverified clusters are explicitly marked and must be
checked through the acceptance gate at the end of this document.

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| `App` | Global facade | Application identity and execution metadata. | Framework/platform candidate. | [S5], [S6] |
| `App.EXEName`, `App.Path`, `App.hInstance` | Properties | Executable identity and native module access. | Member reconciliation; `hInstance` is a platform handle, never a portable `Long` pointer. | [S6], VB6 export required |
| `App.Major`, `App.Minor`, `App.Revision`, `App.Title` | Properties | Version and display identity. | Member reconciliation. | [S5], VB6 export required |
| `App.CompanyName`, `App.FileDescription`, `App.LegalCopyright`, `App.LegalTrademarks`, `App.ProductName`, `App.Comments` | Properties | Build metadata. | Member reconciliation; map to explicit project metadata. | VB6 export required |
| `App.HelpFile`, `App.PrevInstance`, `App.TaskVisible` | Properties | Legacy help, instance, and task-list behavior. | Member reconciliation; platform semantics require review. | [S5], VB6 export required |
| `App.StartMode`, `App.ThreadID`, `App.UnattendedApp`, `App.NonModalAllowed` | Properties | Hosting/execution context. | Compatibility member reconciliation; UBE has its own thread identity and lifecycle. | VB6 export required, [U2] |
| `App.OleRequestPendingMsg`, `App.OleRequestPendingTimeout`, `App.OleRequestPendingTitle`, `App.OleServerBusyMsg`, `App.OleServerBusyRaiseError`, `App.OleServerBusyTimeout`, `App.OleServerBusyTitle` | Properties | OLE interaction policy. | Compatibility member reconciliation; never automatic UBE runtime dialogs. | VB6 export required, [U1] |
| `App.LogEvent`, `App.StartLogging`, `App.LogMode`, `App.LogPath` | Methods / properties | Application logging. | Platform member reconciliation; reusable logging API may be portable, legacy event-log behavior is separate. | VB6 export required |
| `Screen` | Global facade | Display and active UI state. | Framework candidate. | [S5] |
| `Screen.ActiveControl`, `Screen.ActiveForm` | Properties | Focused UI identities. | Member reconciliation; native UI dispatch follows UBE rules. | [S5], [U2] |
| `Screen.Width`, `Screen.Height`, `Screen.TwipsPerPixelX`, `Screen.TwipsPerPixelY` | Properties | Display dimensions and unit conversion. | Member reconciliation; DPI/multiple-display behavior needs definition. | [S5], VB6 export required |
| `Screen.FontCount`, `Screen.Fonts`, `Screen.MouseIcon`, `Screen.MousePointer` | Properties | Font enumeration and pointer appearance. | Member reconciliation. | [S5], VB6 export required |
| `Clipboard` | Global service | Transfer text, images, and other registered formats. | Framework/platform candidate. | [S5] |
| `Clipboard.Clear`, `Clipboard.GetData`, `Clipboard.GetFormat`, `Clipboard.GetText`, `Clipboard.SetData`, `Clipboard.SetText` | Methods | Read/write clipboard contents. | Member reconciliation; specify formats, ownership, failures, and UI-thread dispatch. | [S5], VB6 export required |
| `Printer` | Global facade / object | Selected printer and drawing target. | Separate printing/framework candidate. | [S5] |
| `Printer.Copies`, `Printer.DeviceName`, `Printer.DriverName`, `Printer.Orientation`, `Printer.PaperSize`, `Printer.PrintQuality`, `Printer.Port`, `Printer.ColorMode`, `Printer.Page`, `Printer.hDC` | Properties | Printer/job/device settings. | Member reconciliation; raw handles only in explicit platform APIs. | [S5], VB6 export required |
| `Printer.Print`, `Printer.NewPage`, `Printer.EndDoc`, `Printer.KillDoc` | Methods | Write, paginate, finish, or cancel a print job. | Member reconciliation; explicit job-resource cleanup. | [S5], VB6 export required |
| `Printer` drawing, font, and scale members | Member family | Reconcile drawing/font/measurement members listed below for applicable printer support. | Member reconciliation; no claim of complete member parity. | [S5], VB6 export required |
| `Printers`, `Printers.Count`, `Printers.Item` | Collection / members | Enumerate available printers. | Printing/framework member reconciliation. | [S5], VB6 export required |
| `Forms`, `Forms.Count`, `Forms.Item` | Collection / members | Enumerate loaded forms. | Framework member reconciliation; obey UBE loaded-event-source lifetimes. | [S5], [U1] |
| `Debug.Print` | Method-shaped syntax/service | Explicit diagnostic output. | Debugger/library boundary; not automatic runtime error UI. | [S34], [U1] |
| `Debug.Assert` | Debug facility | Explicit debugging condition. | Compiler/debugger candidate; failure and release-build policy need definition. | [S35] |
| `PropertyBag`, `ReadProperty`, `WriteProperty`, `Contents` | Class / members | Persist named component properties. | Framework/serialization member reconciliation; no implicit executable deserialization. | [S5], VB6 export required |
| `StdFont`, `Font`, `IFont`, `IFontDisp` | OLE types / aliases | Classic font representation and Automation interface. | Compatibility candidate; portable font API and OLE interface are separate. | [S8], VB6/stdole export required |
| `StdPicture`, `Picture`, `IPicture`, `IPictureDisp` | OLE types / aliases | Classic picture representation and Automation interface. | Compatibility candidate; no moving managed address exposed as a picture handle. | [S8], VB6/stdole export required |
| `OLE_COLOR`, `OLE_HANDLE`, `OLE_XPOS_PIXELS`, `OLE_YPOS_PIXELS`, `OLE_XSIZE_PIXELS`, `OLE_YSIZE_PIXELS`, `OLE_XPOS_HIMETRIC`, `OLE_YPOS_HIMETRIC`, `OLE_XSIZE_HIMETRIC`, `OLE_YSIZE_HIMETRIC` | Automation aliases | Color/handle/coordinate ABI types. | Compatibility member reconciliation; width and ownership must be specified per target. | VB6/stdole export required |
| `DataObject`, `DataObject.Files` | Drag/drop objects | Clipboard-format payloads and file lists. | Framework/compatibility member reconciliation; do not confuse with `vbDataObject` Variant tag. | VB6 export required |
| `Licenses`, `Licenses.Add`, `Licenses.Remove`, `Licenses.Count`, `Licenses.Item` | Licensing collection | ActiveX design/runtime licensing. | Optional compatibility member reconciliation. | VB6 export required |
| `Controls`, `Controls.Add`, `Controls.Remove`, `Controls.Count`, `Controls.Item` | Container collection | Find or dynamically host controls. | Framework member reconciliation; dynamic control-array `Load` remains outside UBE 1.0. | VB6 export required, [U1] |
| `Control` | Generic control type | Represent a control through the common VB6 control surface. | Framework member reconciliation; UBE's static member lookup and generic Object restrictions remain authoritative. | VB6 export required, [U1] |
| `VBControlExtender`, `ObjectEvent` | Hosting type / event | Wrap a dynamically hosted control and forward its events. | Explicit framework/ActiveX member reconciliation; not an implicit UBE dynamic-event feature. | VB6 export required |
| `AmbientProperties`, `Extender`, `ParentControls`, `ContainedControls` | Hosting objects / collections | Expose host settings and container relationships to controls. | Framework member reconciliation; exact types, members, and availability need VB6 export. | VB6 export required |
| `DataFormat`, `StdDataFormat`, `StdDataFormats` | Data-format objects | Format and parse bound values through the data-formatting library. | Separate data/framework member reconciliation; no hidden conversion policy in compiler lowering. | VB6/component export required |

## Native form and intrinsic-control surface

These are class/control inventory entries, not parser keywords or promises to
embed Windows/COM into UBECore. The base VB6 intrinsic-control set is distinct
from extra OCXs [S1], [S9]. The toolbox selection pointer is an editor tool,
not another runtime control. Microsoft Forms 2.0 `UserForm`, `MultiPage`,
`ToggleButton`, and Office-host models must not be substituted for VB6 types.

Every class below has **member reconciliation pending**. Naming the class is
not evidence that all of its properties, methods, events, defaults, hidden
members, and designer serialization have been inventoried.

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| `Form` | Native UI class | Top-level or owned window. | Framework candidate; UBE form lifecycle already constrained. | [S5], [U1] |
| `MDIForm` | Native UI class | Multiple-document parent window. | Framework compatibility candidate. | [S5], VB6 export required |
| `UserControl` | Component class | Reusable custom control. | Framework candidate; ActiveX hosting is separate. | [S9], [U1] |
| `UserDocument` | Active document class | Hosted document/component. | Optional compatibility candidate. | [S9] |
| `PropertyPage` | Designer component class | Edit component properties. | Tooling/framework compatibility candidate. | [S9] |
| `PictureBox` | Intrinsic control | Image/drawing surface and child container. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `Label` | Intrinsic control | Display text. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `TextBox` | Intrinsic control | Text input/editing. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `Frame` | Intrinsic control | Group child controls. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `CommandButton` | Intrinsic control | Invoke an action. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `CheckBox` | Intrinsic control | Select a Boolean or mixed state. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `OptionButton` | Intrinsic control | Select one item in a group. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `ComboBox` | Intrinsic control | Combine text and list selection. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `ListBox` | Intrinsic control | Select list items. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `HScrollBar` | Intrinsic control | Horizontal value selection. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `VScrollBar` | Intrinsic control | Vertical value selection. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `Timer` | Intrinsic control | Register timed callbacks. | Framework candidate; active-source liveness and cancellation must follow UBE. | [S5], [U2] |
| `DriveListBox` | Intrinsic control | Select a drive. | Framework/platform compatibility candidate. | [S5], VB6 export required |
| `DirListBox` | Intrinsic control | Browse directories. | Framework/platform compatibility candidate. | [S5], VB6 export required |
| `FileListBox` | Intrinsic control | Select directory entries. | Framework/platform compatibility candidate. | [S5], VB6 export required |
| `Shape` | Intrinsic control | Draw a simple shape. | Graphics/framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `Line` control | Intrinsic control | Display a line. | Graphics/framework candidate; distinct from reserved drawing statement. | [S5], [U1] |
| `Image` | Intrinsic control | Display a picture. | Graphics/framework candidate; member reconciliation pending. | [S5], VB6 export required |
| `Data` | Intrinsic control | Legacy DAO data binding. | Explicit database/compatibility candidate, not silently mandatory UBECore. | [S9], VB6 export required |
| `OLE` / OLE container | Intrinsic control | Host linked/embedded OLE content. | Explicit COM/compatibility candidate. | [S9], VB6 export required |
| `Menu` | Intrinsic menu component | Menu and accelerator entries. | Framework candidate; member reconciliation pending. | [S5], VB6 export required |

### Member families that need per-class expansion

The rows are proposed reconciliation groups. Names here are not evidence that
every control supports the member; acceptance requires a class/member matrix.

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| `Name`, `Index`, `Tag`, `Parent`, `Container`, `Controls` | Identity/container properties | Identify and contain components. | Framework member reconciliation. | VB6 export required |
| `Left`, `Top`, `Width`, `Height`, `Move`, `Align` | Layout properties / method | Position and size components. | Framework member reconciliation. | [S5], VB6 export required |
| `Visible`, `Enabled`, `TabIndex`, `TabStop`, `SetFocus`, `ZOrder`, `Refresh` | Interaction members | Visibility, activation, focus, and redraw. | Framework member reconciliation. | VB6 export required |
| `Caption`, `Text`, `Value`, `ToolTipText`, `WhatsThisHelpID`, `HelpContextID` | Content/help properties | Display or edit content and help metadata. | Framework member reconciliation. | VB6 export required |
| `BackColor`, `ForeColor`, `BackStyle`, `BorderStyle`, `Appearance`, `Font`, `MouseIcon`, `MousePointer`, `RightToLeft` | Appearance properties | Visual presentation. | Framework member reconciliation. | VB6 export required |
| `FontName`, `FontSize`, `FontBold`, `FontItalic`, `FontUnderline`, `FontStrikethru`, `FontTransparent`, `FontCount`, `Fonts` | Font members | Legacy font facade and enumeration. | Graphics/printing member reconciliation. | VB6 export required |
| `Scale`, `ScaleX`, `ScaleY`, `ScaleMode`, `ScaleLeft`, `ScaleTop`, `ScaleWidth`, `ScaleHeight`, `CurrentX`, `CurrentY` | Coordinate members | Drawing coordinates and unit conversion. | Graphics member reconciliation; portable units need an explicit contract. | VB6 export required |
| `Cls`, `Circle`, `Line`, `PSet`, `Point`, `PaintPicture`, `Print`, `TextWidth`, `TextHeight` | Drawing/text methods | Render primitives, pictures, and text. | Graphics member reconciliation; reserved drawing syntax is not full UBE 1.0 graphics support. | [U1], [U3], VB6 export required |
| `DrawMode`, `DrawStyle`, `DrawWidth`, `FillColor`, `FillStyle`, `AutoRedraw`, `AutoSize`, `Picture`, `Image`, `ClipControls` | Drawing properties | Configure rendering and backing images. | Graphics member reconciliation. | VB6 export required |
| `hWnd`, `hDC`, `hPal`, `OLEDropMode`, `OLEDragMode`, `DragMode`, `DragIcon`, `Drag`, `OLEDrag` | Native/drag members | Native handles and drag/drop. | Explicit platform/compatibility member reconciliation. | VB6 export required |
| `Show`, `Hide`, `PopupMenu`, `PrintForm`, `ValidateControls`, `WhatsThisMode` | Form methods | Present, interact with, validate, or print a window. | Framework member reconciliation. | [S5], VB6 export required |
| `MDIChild`, `WindowState`, `WindowList`, `StartUpPosition`, `ControlBox`, `MinButton`, `MaxButton`, `KeyPreview`, `ShowInTaskbar`, `Icon`, `LinkMode`, `LinkTopic` | Form/window properties | Window configuration and legacy links. | Framework/compatibility member reconciliation. | VB6 export required |
| `Load`, `Unload`, `Initialize`, `Terminate`, `QueryUnload`, `Activate`, `Deactivate`, `Resize`, `Paint` | Lifecycle/UI events | Component lifetime and presentation notifications. | Reconcile with UBE's specified `Class_Initialize`, `Class_Terminate`, `Form_Load`, and cancellable `Form_Unload`; do not replace them by assumption. | [U1], VB6 export required |
| `Click`, `DblClick`, `GotFocus`, `LostFocus`, `Validate`, `Change` | Interaction events | User interaction and validation. | Framework member reconciliation. | VB6 export required |
| `KeyDown`, `KeyUp`, `KeyPress`, `MouseDown`, `MouseUp`, `MouseMove`, `DragDrop`, `DragOver` | Input events | Keyboard, pointing, and classic drag/drop. | Framework member reconciliation. | [S10], VB6 export required |
| `OLEStartDrag`, `OLESetData`, `OLEGiveFeedback`, `OLEDragOver`, `OLEDragDrop`, `OLECompleteDrag` | Drag/drop events | Data-object drag/drop lifecycle. | Explicit platform/compatibility member reconciliation. | VB6 export required |
| `SelStart`, `SelLength`, `SelText`, `MultiLine`, `MaxLength`, `PasswordChar`, `Locked`, `ScrollBars`, `HideSelection` | TextBox members | Text selection and editing policy. | Framework member reconciliation. | VB6 export required |
| `AddItem`, `RemoveItem`, `Clear`, `List`, `ListCount`, `ListIndex`, `ItemData`, `NewIndex`, `TopIndex`, `Selected`, `SelCount`, `Sorted`, `Style`, `MultiSelect`, `IntegralHeight`, `Columns` | List/Combo members | Collection-backed selection and presentation. | Framework member reconciliation; exact support differs by control. | VB6 export required |
| `Min`, `Max`, `Value`, `SmallChange`, `LargeChange`, `Change`, `Scroll` | ScrollBar members | Bounded scrolling and change notification. | Framework member reconciliation. | VB6 export required |
| `Interval`, `Enabled`, `Timer` event | Timer members | Start/stop and receive timer ticks. | Framework member reconciliation; no hidden event-source leak. | [U2], VB6 export required |
| `Path`, `Drive`, `Pattern`, `FileName`, `Archive`, `Hidden`, `Normal`, `ReadOnly`, `System`, `Refresh` | File-list members | File browsing and filtering. | Platform member reconciliation; not all members apply to all three file controls. | VB6 export required |
| `ClientSite`, `Ambient`, `Extender`, `Parent`, `PropertyChanged`, `ReadProperties`, `WriteProperties`, `InitProperties` | UserControl/hosting members | Hosting and property persistence. | Framework/ActiveX member reconciliation. | [S9], VB6 export required |
| `DataSource`, `DataMember`, `DataField`, `DataFormat`, `DataChanged` | Data-binding members | Bind UI values to data services. | Separate data/framework compatibility member reconciliation. | [S9], VB6 export required |

## Runtime constants and enumeration types

These are candidate source-level names. Numeric values and ABI widths must be
recorded in the eventual declaration ledger. A current VBA reference does not
by itself prove that every listed value existed in VB6. No VB.NET enums or
Office-specific `xl*`, `wd*`, `ac*`, `fm*` constants are imported here.

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| `vbCrLf`, `vbCr`, `vbLf`, `vbNewLine`, `vbTab`, `vbBack`, `vbFormFeed`, `vbVerticalTab`, `vbNullChar` | Text constants | Line/control characters. | Core candidates; define platform newline separately from UBE's accepted source line endings. | [S11] |
| `vbNullString` | ABI-sensitive string constant | Legacy distinction from an empty string at foreign boundaries. | Compatibility candidate; no exposed raw pointer and no silent change to UBE String values. | [S11], [U4] |
| `vbObjectError` | Error constant | Base for legacy application-defined Automation errors. | Compatibility candidate; native UBE error namespace still needs an explicit mapping. | [S11] |
| `VbVarType`: `vbEmpty`, `vbNull`, `vbInteger`, `vbLong`, `vbSingle`, `vbDouble`, `vbCurrency`, `vbDate`, `vbString`, `vbObject`, `vbError`, `vbBoolean`, `vbVariant`, `vbDataObject`, `vbDecimal`, `vbByte`, `vbArray` | Enum/flag family | Legacy Variant tags and array flag. | Core compatibility candidates; UBE adds types and preserves exact tags, so do not infer its internal layout from VB values. | [S12], [U1] |
| `vbLongLong`, `vbUserDefinedType` in current VBA | Later/expanded tag names | Additional runtime type tags documented by current VBA. | UBE mapping decision; not asserted as VB6 baseline constants. | [S12] |
| `VbCompareMethod`: `vbBinaryCompare`, `vbTextCompare`, `vbDatabaseCompare` | Enum | String comparison selection. | First two core candidates; Database behavior unsupported in UBE 1.0 and must diagnose rather than silently map. | [S13], [U1] |
| `VbStrConv`: `vbUpperCase`, `vbLowerCase`, `vbProperCase`, `vbWide`, `vbNarrow`, `vbKatakana`, `vbHiragana`, `vbUnicode`, `vbFromUnicode` | Enum/flags | Case, width, script, and encoding conversion. | Core/platform candidates; legacy code-page behavior must be explicit. | [S14] |
| `VbTriState`: `vbTrue`, `vbFalse`, `vbUseDefault` | Enum | Three-way formatting options. | Core candidate; distinct from Boolean storage representation. | [S15] |
| `VbCalendar`: `vbCalGreg`, `vbCalHijri` | Enum | Calendar selection. | Explicit library compatibility candidate; UBE core Date stays proleptic Gregorian. | [S16], [U1] |
| `VbDayOfWeek`: `vbUseSystemDayOfWeek`, `vbSunday`, `vbMonday`, `vbTuesday`, `vbWednesday`, `vbThursday`, `vbFriday`, `vbSaturday` | Enum | Weekday/first-weekday selection. | Core/library candidates; system-dependent defaults need explicit policy. | [S17] |
| `VbFirstWeekOfYear`: `vbUseSystem`, `vbFirstJan1`, `vbFirstFourDays`, `vbFirstFullWeek` | Enum | Week-number rules. | Core/library candidates. | [S17] |
| `VbDateTimeFormat`: `vbGeneralDate`, `vbLongDate`, `vbShortDate`, `vbLongTime`, `vbShortTime` | Enum | Named date/time presentation. | Core/library candidates; distinguish invariant defaults from localized formatting. | [S18] |
| `VbFileAttribute`: `vbNormal`, `vbReadOnly`, `vbHidden`, `vbSystem`, `vbVolume`, `vbDirectory`, `vbArchive`, `vbAlias` | Enum/flags | File metadata/filter bits. | Portable facade with explicit unsupported-platform behavior; `vbAlias` is a platform variant, not asserted as Windows VB6 behavior. | [S19], [S20] |
| `VbAppWinStyle`: `vbHide`, `vbNormalFocus`, `vbMinimizedFocus`, `vbMaximizedFocus`, `vbNormalNoFocus`, `vbMinimizedNoFocus` | Enum | Process launch window behavior. | Platform interaction candidate. | [S21] |
| `VbCallType`: `vbMethod`, `vbGet`, `vbLet`, `vbSet` | Enum | Explicit runtime member dispatch. | Compatibility candidate; does not authorize implicit Object/Variant member-name lookup in UBE. | [S22], [U1] |
| `VbMsgBoxStyle`: `vbOKOnly`, `vbOKCancel`, `vbAbortRetryIgnore`, `vbYesNoCancel`, `vbYesNo`, `vbRetryCancel`, `vbCritical`, `vbQuestion`, `vbExclamation`, `vbInformation`, `vbDefaultButton1`, `vbDefaultButton2`, `vbDefaultButton3`, `vbDefaultButton4`, `vbApplicationModal`, `vbSystemModal`, `vbMsgBoxHelpButton`, `vbMsgBoxSetForeground`, `vbMsgBoxRight`, `vbMsgBoxRtlReading` | Enum/flags | Explicit dialog options. | Framework candidate; never automatic recoverable-error policy. | [S23], [U1] |
| `VbMsgBoxResult`: `vbOK`, `vbCancel`, `vbAbort`, `vbRetry`, `vbIgnore`, `vbYes`, `vbNo` | Enum | Dialog result. | Framework candidate. | [S23] |
| `ColorConstants`: `vbBlack`, `vbRed`, `vbGreen`, `vbYellow`, `vbBlue`, `vbMagenta`, `vbCyan`, `vbWhite` | Constants | Basic color names. | Graphics/framework candidates. | [S24] |
| `SystemColorConstants`: `vbScrollBars`, `vbDesktop`, `vbActiveTitleBar`, `vbInactiveTitleBar`, `vbMenuBar`, `vbWindowBackground`, `vbWindowFrame`, `vbMenuText`, `vbWindowText`, `vbTitleBarText`, `vbActiveBorder`, `vbInactiveBorder`, `vbApplicationWorkspace`, `vbHighlight`, `vbHighlightText`, `vbButtonFace`, `vbButtonShadow`, `vbGrayText`, `vbButtonText`, `vbInactiveCaptionText`, `vb3DHighlight`, `vb3DDKShadow`, `vb3DLight`, `vbInfoText`, `vbInfoBackground` | Constants | Theme/system-color selectors. | Framework/platform candidates; system-color tokens are not ordinary fixed RGB values. | [S25] |
| `KeyCodeConstants` named nonalphanumeric keys | Constants | `vbKeyLButton`, `vbKeyRButton`, `vbKeyCancel`, `vbKeyMButton`, `vbKeyBack`, `vbKeyTab`, `vbKeyClear`, `vbKeyReturn`, `vbKeyShift`, `vbKeyControl`, `vbKeyMenu`, `vbKeyPause`, `vbKeyCapital`, `vbKeyEscape`, `vbKeySpace`, `vbKeyPageUp`, `vbKeyPageDown`, `vbKeyEnd`, `vbKeyHome`, `vbKeyLeft`, `vbKeyUp`, `vbKeyRight`, `vbKeyDown`, `vbKeySelect`, `vbKeyPrint`, `vbKeyExecute`, `vbKeySnapshot`, `vbKeyInsert`, `vbKeyDelete`, `vbKeyHelp`, `vbKeyNumlock`. | Framework input compatibility candidates. | [S10] |
| `KeyCodeConstants` alphabet | Constants | `vbKeyA`, `vbKeyB`, `vbKeyC`, `vbKeyD`, `vbKeyE`, `vbKeyF`, `vbKeyG`, `vbKeyH`, `vbKeyI`, `vbKeyJ`, `vbKeyK`, `vbKeyL`, `vbKeyM`, `vbKeyN`, `vbKeyO`, `vbKeyP`, `vbKeyQ`, `vbKeyR`, `vbKeyS`, `vbKeyT`, `vbKeyU`, `vbKeyV`, `vbKeyW`, `vbKeyX`, `vbKeyY`, `vbKeyZ`. | Framework input compatibility candidates. | [S10] |
| `KeyCodeConstants` digits | Constants | `vbKey0`, `vbKey1`, `vbKey2`, `vbKey3`, `vbKey4`, `vbKey5`, `vbKey6`, `vbKey7`, `vbKey8`, `vbKey9`. | Framework input compatibility candidates. | [S10] |
| `KeyCodeConstants` keypad | Constants | `vbKeyNumpad0`, `vbKeyNumpad1`, `vbKeyNumpad2`, `vbKeyNumpad3`, `vbKeyNumpad4`, `vbKeyNumpad5`, `vbKeyNumpad6`, `vbKeyNumpad7`, `vbKeyNumpad8`, `vbKeyNumpad9`, `vbKeyMultiply`, `vbKeyAdd`, `vbKeySeparator`, `vbKeySubtract`, `vbKeyDecimal`, `vbKeyDivide`. | Framework input compatibility candidates. | [S10] |
| `KeyCodeConstants` function keys | Constants | `vbKeyF1`, `vbKeyF2`, `vbKeyF3`, `vbKeyF4`, `vbKeyF5`, `vbKeyF6`, `vbKeyF7`, `vbKeyF8`, `vbKeyF9`, `vbKeyF10`, `vbKeyF11`, `vbKeyF12`, `vbKeyF13`, `vbKeyF14`, `vbKeyF15`, `vbKeyF16`. | Framework input compatibility candidates; remaining host keys require baseline export review. | [S10] |
| `VbQueryClose`: `vbFormControlMenu`, `vbFormCode`, `vbAppWindows`, `vbAppTaskManager` | Enum | Legacy close-origin codes. | Compatibility candidate; does not change UBE's cancellable unload contract. | [S26], [U1] |
| `FormShowConstants`: `vbModal`, `vbModeless` | Enum | Explicit form presentation mode. | Framework compatibility candidate. | [S16] |
| `LogEventTypeConstants`: `vbLogEventTypeError`, `vbLogEventTypeWarning`, `vbLogEventTypeInformation` | Enum | Legacy log severity. | Platform member reconciliation; numeric values require VB6 export. | VB6 export required |
| `LogModeConstants`: `vbLogAuto`, `vbLogOff`, `vbLogToFile`, `vbLogToNT`, `vbLogOverwrite` | Enum/flags | Legacy logging destination/options. | Platform member reconciliation. | VB6 export required |
| `VbIMEStatus`: `vbIMEModeNoControl`, `vbIMEModeOn`, `vbIMEModeOff`, `vbIMEModeDisable`, `vbIMEModeHiragana`, `vbIMEModeKatakana`, `vbIMEModeKatakanaHalf`, `vbIMEModeAlphaFull`, `vbIMEModeAlpha`, `vbIMEModeHangulFull`, `vbIMEModeHangul` | Input-method family | Regional `IMEStatus` result names. | Platform candidate; reconcile original VB6 declarations and regional availability. | [S36], VB6 export required |
| VB6 UI constant families | Enum-family checklist | Align/Alignment, Appearance, BorderStyle, CheckBox values, ComboBox/ListBox Style, MultiSelect, ScrollBars, MousePointer, mouse button/shift masks, drag modes/over states, OLE drag/drop effects, ScaleMode, DrawMode, DrawStyle, FillStyle, Shape, WindowState, Arrange, PictureType, print orientation/quality/bin/paper/duplex/color. | Separate framework inventory; enumerate all exact type/member names from VB6 before claiming completeness. | [S9], VB6 export required |

### VBA7 and compilation-environment compatibility

VBA7 compatibility is part of the requested inventory. These names remain
proposals where frozen UBE has no equivalent. The compiler must determine
target facts separately from host facts; copying Office's environment tests
without a documented UBE mapping would be incorrect.

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| `VBA7` | Conditional compiler constant | Test compatibility with VBA7 source features, independently of process bitness. | Compiler compatibility candidate; never claim full VBA7 support just because UBE has 64-bit integers. | [S30] |
| `VBA6` | Conditional compiler constant | Test compatibility with the VBA6 language baseline. | Compiler compatibility candidate; exact truth conditions require a UBE compatibility policy. | [S30] |
| `Win64` | Conditional compiler constant | Select a 64-bit Windows environment branch in VBA. | Compiler compatibility candidate; distinguish target architecture from build host. | [S30] |
| `Win32` | Conditional compiler constant | Select Win32-compatible code; VBA documents it as true in both Windows bitness environments. | Compiler compatibility candidate; preserve this legacy distinction if accepted. | [S30] |
| `Win16` | Conditional compiler constant | Identify the legacy 16-bit environment. | Import compatibility candidate; does not add a 16-bit UBE target. | [S30] |
| `Mac` | Conditional compiler constant | Identify Macintosh-host/platform branches. | Compiler compatibility candidate; portable UBE APIs do not inherit Office host assumptions. | [S30] |
| `LongPtr` | VBA7 type alias | Resolves to the host VBA's pointer-width signed integer. | Source-compatibility alias candidate; frozen UBE names `IntPtr`/`UIntPtr` do not themselves authorize a new alias. | [S31], [U1] |
| `LongLong` in VBA7 | VBA7 scalar | Signed 64-bit integer available in 64-bit VBA. | UBE already defines `LongLong`; apply UBE conversions rather than VBA's narrower-assignment restrictions. | [S31], [U1] |
| `PtrSafe` | VBA7 Declare modifier | Explicit foreign declaration compatibility assertion. | Compiler syntax candidate; does not prove pointer widths, layouts, ownership, or ABI safety. | [S32], [U4] |
| `CLngPtr`, `CLngLng` | VBA7 conversion names | Explicit pointer-width / 64-bit integral conversion. | Callable inventory is in [vb6-runtime.md](vb6-runtime.md); UBE signatures/semantics require review. | [S31] |
| `VarPtr`, `ObjPtr`, `StrPtr` in VBA7 | Pointer-returning compatibility functions | Pointer-width return behavior differs from legacy 32-bit VBA. | Explicit unsafe/ABI disposition; UBE's movable managed values and opaque handles preclude an unscoped raw-address contract. | [S33], [U4] |
| `Calendar` Get / Let | Global VBA property | Select Gregorian/Hijri interpretation for VBA date operations. | Library compatibility candidate; cannot change UBE core Gregorian Date or introduce an undocumented process-global race. | [S16], [U1] |

## Error-code families

The numbers below are VB compatibility reference points, not newly assigned
UBE error numbers. Microsoft lists many additional errors [S27]. UBE's
neutral-result, thread-local state, and controlled-failure rules take
precedence over VB's automatic dialog and termination behavior.

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| Arithmetic/conversion: `5`, `6`, `11`, `13`, `94` | Error family | Invalid argument, overflow, divide by zero, type mismatch, Null extraction. | Error-ledger compatibility review. | [S27], [U1] |
| Storage/bounds: `7`, `9`, `10`, `14`, `28` | Error family | Memory, array bounds/locking, string space, stack exhaustion. | Controlled-failure and recovery mapping required. | [S27], [U1] |
| Error-control flow: `3`, `20` | Error family | Return without GoSub; Resume without error. | Compiler/runtime boundary. | [S27] |
| File/device/path: `52`, `53`, `54`, `55`, `57`, `58`, `59`, `61`, `62`, `63`, `67`, `68`, `70`, `71`, `74`, `75`, `76` | Error family | File identity/modes, I/O, full disk, permissions, paths. | Portable file error model with platform detail. | [S27] |
| Component/library loading: `47`, `48`, `49`, `298`, `335`, `336`, `337`, `338`, `368` | Error family | ABI/library/resource/registration failures. | Explicit platform/compatibility mapping. | [S27] |
| Forms/controls: `360`, `361`, `363`, `364`, `365`, `371`, `380`, `381`, `382`, `383`, `385`, `387`, `393`, `394`, `400`, `402` | Error family | Load/unload, properties, modal presentation. | Framework mapping; preserve UBE identity-wide unload rules. | [S27], [U1] |
| Object/Automation: `91`, `419`, `422`, `423`, `424`, `425`, `429`, `430`, `432`, `438`, `440`, `445`, `446`, `447`, `448`, `449`, `450`, `451`, `452`, `453`, `454`, `455`, `457`, `458`, `459`, `460`, `461`, `462` | Error family | Missing/stale objects, dispatch, arguments, registration, duplicate keys. | Core/framework/COM disposition per code; not an implicit late-binding feature. | [S27], [U1] |
| User-defined and provider errors | Error namespace | Application values above legacy `vbObjectError`, plus external provider codes. | Explicit namespace/status mapping; never assume a stale nonzero Err is a new failure. | [S11], [U1], [U4] |

## Extended libraries and external component ecosystem

The rows retain scope visibility without declaring every historical OCX a
portable UBECore obligation. An optional replacement still needs its own API,
license/dependency decision, native target adapters, and tests. Microsoft's
runtime distribution/support list establishes this boundary [S1]; it does not
grant permission to bundle those binaries.

| Identifier | Kind | Purpose | Placement/status | Source |
|---|---|---|---|---|
| COM/OLE Automation | Interoperation layer | `IUnknown`/`IDispatch`, type information, activation, marshaling, BSTR/VARIANT/SAFEARRAY conversion. | Optional Windows compatibility library; UBE's foreign ABI remains independent. | [S8], [U4] |
| ActiveX DLL / EXE / control hosting | Component model | In-process/out-of-process objects and controls. | Optional compatibility library; no automatic COM binary-compatibility promise. | [S9], [U4] |
| Windows Common Controls (`MSCOMCTL.OCX`) | Control family | `TreeView`, `ListView`, `ImageList`, `Toolbar`, `StatusBar`, `ProgressBar`, `Slider`, `TabStrip`. | Separate framework/compatibility inventory; member/value export pending. | [S1] |
| Windows Common Controls-2 (`MSCOMCT2.OCX`) | Control family | `Animation`, `UpDown`, `MonthView`, `DTPicker`, `FlatScrollBar`. | Separate framework/compatibility inventory. | [S1] |
| Common Controls-3 / `CoolBar` | Control family | Rebar-style tool grouping. | Optional compatibility inventory. | [S1] |
| `CommonDialog` (`COMDLG32.OCX`) | Control | File, font, color, print, and help dialogs. | Framework/platform candidate; exact members and flags pending. | [S1] |
| `RichTextBox` (`RICHTX32.OCX`) | Control | Rich text editing. | Separate framework candidate. | [S1] |
| `SSTab` (`TABCTL32.OCX`) | Control | Tabbed containers. | Separate framework/compatibility candidate. | [S1] |
| `MSFlexGrid`, `MSHFlexGrid` | Controls | Tabular presentation and hierarchical binding. | Separate framework/data candidates. | [S1] |
| `MSChart` | Control | Chart presentation. | Separate graphics/data candidate. | [S1] |
| `DataGrid`, `DataList`, `DataCombo`, `DataRepeater`, `DBGrid`, `DBList`, `DBCombo` | Data-bound controls | Legacy data binding. | Separate data/framework compatibility candidates. | [S1], [S9] |
| `Adodc` / ADO Data Control | Data component | ADO binding facade. | Optional data compatibility library. | [S1], [S9] |
| ADO | Data library | `Connection`, `Command`, `Recordset`, `Record`, `Stream`, `Parameter`, `Field`, `Error` and collections. | Optional database library; full API is a separate inventory. | [S9], [S28] |
| DAO | Data library | `DBEngine`, `Workspace`, `Database`, `TableDef`, `QueryDef`, `Recordset`, `Field`, `Index`, `Relation`, and collections. | Optional database compatibility library. | [S9] |
| RDO / RemoteData control | Data library/control | Legacy remote database access. | Optional compatibility inventory. | [S1], [S9] |
| `Winsock` (`MSWINSCK.OCX`) | Networking control | Socket endpoints and events. | Portable networking capability may be separate UBE library; OCX API is explicit compatibility work. | [S1] |
| `Inet` / Internet Transfer | Networking control | Legacy transfer protocols. | Optional networking compatibility inventory. | [S1] |
| `MSComm` | Communications control | Serial-port access/events. | Separate platform library candidate. | [S1] |
| MAPI controls | Messaging controls | Legacy mail sessions/messages. | Optional platform compatibility inventory. | [S1] |
| Multimedia / `MMControl` (`MCI32.OCX`) | Media control | Legacy media device commands. | Separate media/platform candidate. | [S1] |
| `PictureClip` | Graphics control | Image clipping/slicing. | Separate graphics/compatibility candidate. | [S1] |
| `MaskedEdit` / `MaskEdBox` | Input control | Masked text entry. | Separate framework candidate. | [S1] |
| `SysInfo` | System control | Platform/system notifications. | Explicit platform candidate. | [S1] |
| Script Control | Embedding component | Host another scripting engine. | Optional external integration; not UBE execution machinery. | [S1] |
| Windowless controls | Control family | Lightweight control variants. | Separate framework/compatibility inventory. | [S1] |
| Microsoft Scripting Runtime | External library | `Dictionary`, `FileSystemObject`, `File`, `Folder`, `Drive`, `TextStream` and collections. | Useful portable equivalents may be designed independently; original COM API is separate optional compatibility. | [S29] |
| WebBrowser / DHTML / WebClass / IIS integration | External/host framework | Browser/document/server hosting. | Optional external integration; no webview shell for UBE native tools. | [S9], [U1] |
| Data Environment / Data Report / Data Binding Collection | Designers/data components | Database tooling, report output, binding. | Separate tooling/data scope; full members pending original component export. | [S9] |
| Legacy/discontinued vendor controls and IDE wizards | Optional components/tooling | Historic gauges, spin buttons, graphs, 3-D controls, application/data/chart wizards. | Not automatically UBECore; retain disposition records if compatibility is requested. | [S1], [S9] |
| Windows API declarations and constants | Platform API catalog | OS memory, files, messages, graphics, registry, processes, and native handles. | Explicit platform libraries; cannot be exhaustively equated with the VB6 runtime. | [S9], [U4] |
| VBIDE extensibility, Office objects, third-party OCXs | External tool/application APIs | IDE automation and referenced applications/components. | Separate optional inventories selected by actual references; not silently imported. | [S7], [S9] |

## Completeness gate and decisions still required

This is a broad named baseline, not a claim to have enumerated every UI member
or every component ever shipped on a VB6 CD. No per-class UI member inventory
is marked complete. To close that gap:

1. Pin an available, licensed VB6 installation/version/service pack and record
   the identity of its `VBA`, `VB`, and `stdole` libraries. Do not substitute an
   Office VBA7 or VB.NET assembly for the VB6 baseline. Export a separately
   pinned VBA7 library for the additional requested VBA7 coverage.
2. Export every class, module, enum, constant, alias, property Get/Let/Set,
   method, event, parameter/default, return type, default member, and hidden
   enumeration member visible in those type libraries. Record numeric values
   and source library identity. Record designer metadata separately.
3. Diff the export against this inventory. Every exported name needs a row or
   a named disposition: core, separate framework, explicit platform support,
   deferred compatibility, or intentionally unsupported with a documented
   reason. Each control needs an explicit applicability/member matrix.
4. Repeat for each selected extended library. Full ADO/DAO, common-control,
   printer paper/bin values, UI enum members, regional constants, control
   arrays, and designer persistence remain explicit expansion work.
5. Reconcile behavior with frozen UBE semantics before approving declarations.
   In particular: thread-local errors; no implicit Object/Variant late lookup;
   no class implementation inheritance; no Shared class-member surface;
   explicit `Set`; parameterless construction; managed handles rather than
   exposed GC addresses; precise roots and cycle collection; synchronous
   events and transparent UI dispatch; cancellable identity-wide unload.

For constants already named here, values and signatures remain unverified
against an original VB6 export. The owner still needs dispositions for COM,
legacy UI/printing, database integration, and platform-specific compatibility
where the UBE contract does not decide the question. Those choices must not
block the first portable byte/text facilities or invent new core-language
semantics.

## Sources

All web sources are Microsoft primary references. Shared VBA sources are used
only for the named common surface, with later/host-only differences noted.
Unverified member clusters say so explicitly rather than citing a broad page
as proof of exact member coverage.

[S1]: https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/visual-basic-6-support-policy "Microsoft: VB6 runtime and extended-file support boundary"
[S2]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/err-object "Microsoft: Err object"
[S3]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/error-statement "Microsoft: Error statement and LastDllError"
[S4]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/collection-object "Microsoft: Collection object"
[S5]: https://download.microsoft.com/download/1/6/d/16d24ada-5317-4de1-b2b2-890b51813d6e/VS2005_VB_en-us.pdf "Microsoft: VB6-to-VB2005 migration reference; use only explicitly VB6 portions"
[S6]: https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/visual-basic/language-compilers/check-if-program-is-running "Microsoft: App.EXEName and hInstance"
[S7]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/object-browser "Microsoft: object-library browsing"
[S8]: https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/visual-basic-6.0-documentation "Microsoft: VB6 resource center and COM boundary"
[S9]: https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa232759(v=vs.60) "Microsoft: original VB6 documentation map"
[S10]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/keycode-constants "Microsoft: keycode constants"
[S11]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/miscellaneous-constants "Microsoft: text and error constants"
[S12]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/vartype-function "Microsoft: VarType tags; contains post-VB6 additions"
[S13]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/strcomp-function "Microsoft: string comparison choices"
[S14]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/strconv-constants "Microsoft: StrConv constants"
[S15]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/formatnumber-function "Microsoft: tristate formatting choices"
[S16]: https://download.microsoft.com/download/0/a/6/0a6f7755-9af5-448b-907d-13985accf53e/%5Bms-vbal%5D.pdf "Microsoft: MS-VBAL predefined enums"
[S17]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/date-constants "Microsoft: weekday and week-number constants"
[S18]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/formatdatetime-function "Microsoft: date/time format choices"
[S19]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/getattr-function "Microsoft: file-attribute flags"
[S20]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/dir-function "Microsoft: directory filter flags"
[S21]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/shell-constants "Microsoft: Shell constants"
[S22]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/callbyname-function "Microsoft: explicit dispatch modes"
[S23]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/msgbox-constants "Microsoft: dialog styles and results"
[S24]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/color-constants "Microsoft: fixed color constants"
[S25]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/system-color-constants "Microsoft: system-color tokens"
[S26]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/queryclose-constants "Microsoft: close-origin constants"
[S27]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/trappable-errors "Microsoft: trappable error identities"
[S28]: https://learn.microsoft.com/en-us/office/client-developer/access/desktop-database-reference/ado-api-reference "Microsoft: separate ADO library reference"
[S29]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/filesystemobject-object "Microsoft: referenced scripting FileSystemObject"
[S30]: https://learn.microsoft.com/en-us/office/vba/Language/Concepts/Getting-Started/compiler-constants "Microsoft: VBA6/VBA7 and platform compilation constants"
[S31]: https://learn.microsoft.com/en-us/office/vba/Language/Concepts/Getting-Started/64-bit-visual-basic-for-applications-overview "Microsoft: VBA7 64-bit language additions"
[S32]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/ptrsafe-keyword "Microsoft: PtrSafe foreign declarations"
[S33]: https://learn.microsoft.com/en-us/office/client-developer/shared/compatibility-between-the-32-bit-and-64-bit-versions-of-office "Microsoft: pointer-function compatibility"
[S34]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/print-method "Microsoft: Debug.Print syntax"
[S35]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/assert-method "Microsoft: Debug.Assert"
[S36]: https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/imestatus-function "Microsoft: IMEStatus regional constants"
[U1]: ../../lang-doc/language-spec.md "Normative UBE core language contract"
[U2]: ../../lang-doc/threading.md "Normative UBE threading contract"
[U3]: ../../lang-doc/deferred-questions.md "Reserved graphics and unresolved behavior"
[U4]: ../../lang-doc/foreign-abi.md "Normative UBE foreign ABI"

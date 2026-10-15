"use strict";

(function () {
  var groups = {
    f: ["False", "FileCopy", "For", "ForceInline", "Form", "Friend", "Function"],
    g: ["Get", "Global", "GoSub", "GoTo"],
    h: [],
    i: ["If", "Imp", "Implements", "In", "Inline", "Input", "Integer", "Interface", "IntPtr", "Intrinsic", "Is", "IsEmpty", "IsNot", "IsNull"],
    j: [],
    k: ["Kill"],
    l: ["Len", "Let", "Lib", "Like", "Line", "Load", "Lock", "Long", "LongLong", "Loop", "LSet"],
    m: ["Me", "MessageQueue", "Mid", "MkDir", "Mod", "Module"],
    n: ["Name", "New", "Next", "Not", "Nothing", "Null"],
    o: ["Object", "Off", "On", "Open", "Option", "Optional", "Or", "OrElse", "Output"],
    p: ["Page", "ParamArray", "Preserve", "Print", "Private", "Property", "Public", "Put"],
    q: [],
    r: ["RaiseEvent", "Random", "Read", "ReDim", "Reference", "Rem", "Resume", "Return", "RmDir", "RSet"],
    s: ["SavePicture", "Seek", "Select", "Semaphore", "Set", "Shared", "Single", "Source", "Spc", "Static", "Step", "Stop", "String", "Sub", "SyncLock"],
    t: ["Tab", "Text", "Then", "ThreadEvent", "ThreadIsAlive", "ThreadRequestStop", "ThreadStopRequested", "ThreadWait", "ThreadYield", "To", "True", "Type", "TypeOf"],
    u: ["UBE", "UIntPtr", "Unload", "Unlock", "Until", "UserControl"],
    v: ["Variable", "Variant", "Version"],
    w: ["Wend", "While", "Width", "With", "WithEvents", "Write"],
    x: ["Xor"],
    y: [],
    z: []
  };

  function slug(word) {
    return word.toLocaleLowerCase();
  }

  function find(items, id) {
    var result = null;
    items.some(function (item) {
      if (item.id === id) {
        result = item;
        return true;
      }
      if (item.children) result = find(item.children, id);
      return result !== null;
    });
    return result;
  }

  if (!window.UBE_DOCS || !Array.isArray(window.UBE_DOCS.sections)) return;

  Object.keys(groups).forEach(function (letter) {
    var branch = find(window.UBE_DOCS.sections, "language.words." + letter);
    if (!branch) return;
    branch.path = "language/words/" + letter + "/index.html";
    branch.children = groups[letter].map(function (word) {
      var wordSlug = slug(word);
      return {
        id: "language.word." + wordSlug,
        title: word,
        path: "language/words/" + letter + "/" + wordSlug + ".html"
      };
    });
  });
}());

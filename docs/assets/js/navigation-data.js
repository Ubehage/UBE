"use strict";

window.UBE_DOCS = {
  defaultPath: "about/index.html",
  sections: [
    {
      id: "about",
      title: "About UBE",
      open: true,
      children: [
        { id: "about.overview", title: "UBE overview", path: "about/index.html", aliases: ["what is UBE", "welcome"] },
        { id: "about.goals", title: "Goals and principles", path: "about/goals.html", aliases: ["design", "philosophy"] },
        { id: "about.status", title: "Project status", path: "about/status.html", aliases: ["release", "platforms", "pre-release"] },
        { id: "about.generations", title: "Development and releases", path: "about/compiler-generations.html", aliases: ["compiler generations", "v2", "v3", "self-hosting"] },
        { id: "about.documentation-status", title: "Documentation status", path: "about/documentation-status.html", aliases: ["implemented", "specified", "planned"] },
        { id: "about.glossary", title: "Glossary", path: "about/glossary.html", aliases: ["terms", "definitions"] }
      ]
    },
    {
      id: "learn.index",
      title: "Learn UBE",
      path: "learn/index.html",
      children: [
        { id: "learn.first-program", title: "Write your first program", path: "learn/first-program.html" },
        { id: "learn.language-tour", title: "Language tour", path: "learn/language-tour.html" },
        { id: "learn.projects-modules", title: "Projects, modules, and files", path: "learn/projects-modules.html" },
        { id: "learn.variables-types", title: "Variables and types", path: "learn/variables-types.html" },
        { id: "learn.procedures-parameters", title: "Procedures and parameters", path: "learn/procedures-parameters.html" },
        { id: "learn.control-flow", title: "Decisions and loops", path: "learn/control-flow.html" },
        { id: "learn.errors", title: "Errors and Err", path: "learn/errors.html" },
        { id: "learn.memory-resources", title: "Memory and resources", path: "learn/memory-resources.html" },
        { id: "learn.threads-callnew", title: "Threads and CallNew", path: "learn/threads-callnew.html" }
      ]
    },
    {
      id: "language.topics",
      title: "Language reference",
      path: "language/topics/index.html",
      children: [
        { id: "language.lexical", title: "Lexical structure", path: "language/topics/lexical-structure.html" },
        { id: "language.conditional-compilation", title: "Conditional compilation", path: "language/topics/conditional-compilation.html", aliases: ["#Const", "#If", "#ElseIf"] },
        {
          id: "language.words",
          title: "A–Z language word index",
          path: "language/words/index.html",
          children: [
            {
              id: "language.words.a", title: "A", path: "language/words/a/index.html", children: [
                { id: "language.word.access", title: "Access", path: "language/words/a/access.html" },
                { id: "language.word.addressof", title: "AddressOf", path: "language/words/a/addressof.html" },
                { id: "language.word.alias", title: "Alias", path: "language/words/a/alias.html" },
                { id: "language.word.and", title: "And", path: "language/words/a/and.html" },
                { id: "language.word.andalso", title: "AndAlso", path: "language/words/a/andalso.html" },
                { id: "language.word.any", title: "Any", path: "language/words/a/any.html" },
                { id: "language.word.append", title: "Append", path: "language/words/a/append.html" },
                { id: "language.word.as", title: "As", path: "language/words/a/as.html" },
                { id: "language.word.asm", title: "Asm", path: "language/words/a/asm.html" },
                { id: "language.word.attribute", title: "Attribute", path: "language/words/a/attribute.html" }
                ,{ id: "language.word.atomicboolean", title: "AtomicBoolean", path: "language/words/a/atomicboolean.html" }
                ,{ id: "language.word.atomiclong", title: "AtomicLong", path: "language/words/a/atomiclong.html" }
                ,{ id: "language.word.atomiclonglong", title: "AtomicLongLong", path: "language/words/a/atomiclonglong.html" }
                ,{ id: "language.word.atomicobject", title: "AtomicObject", path: "language/words/a/atomicobject.html" }
              ]
            },
            {
              id: "language.words.b", title: "B", path: "language/words/b/index.html", children: [
                { id: "language.word.base", title: "Base", path: "language/words/b/base.html" },
                { id: "language.word.begin", title: "Begin", path: "language/words/b/begin.html" },
                { id: "language.word.beginproperty", title: "BeginProperty", path: "language/words/b/beginproperty.html" },
                { id: "language.word.binary", title: "Binary", path: "language/words/b/binary.html" },
                { id: "language.word.boolean", title: "Boolean", path: "language/words/b/boolean.html" },
                { id: "language.word.byref", title: "ByRef", path: "language/words/b/byref.html" },
                { id: "language.word.byte", title: "Byte", path: "language/words/b/byte.html" },
                { id: "language.word.bytecode", title: "Bytecode", path: "language/words/b/bytecode.html" },
                { id: "language.word.byval", title: "ByVal", path: "language/words/b/byval.html" }
              ]
            },
            {
              id: "language.words.c", title: "C", path: "language/words/c/index.html", children: [
                { id: "language.word.call", title: "Call", path: "language/words/c/call.html" },
                { id: "language.word.callnew", title: "CallNew", path: "language/words/c/callnew.html" },
                { id: "language.word.case", title: "Case", path: "language/words/c/case.html" },
                { id: "language.word.chdir", title: "ChDir", path: "language/words/c/chdir.html" },
                { id: "language.word.chdrive", title: "ChDrive", path: "language/words/c/chdrive.html" },
                { id: "language.word.class", title: "CLASS", path: "language/words/c/class.html" },
                { id: "language.word.close", title: "Close", path: "language/words/c/close.html" },
                { id: "language.word.collectgarbage", title: "CollectGarbage", path: "language/words/c/collectgarbage.html" },
                { id: "language.word.compare", title: "Compare", path: "language/words/c/compare.html" },
                { id: "language.word.const", title: "Const", path: "language/words/c/const.html" },
                { id: "language.word.control", title: "CONTROL", path: "language/words/c/control.html" },
                { id: "language.word.createsemaphore", title: "CreateSemaphore", path: "language/words/c/createsemaphore.html" },
                { id: "language.word.createthreadevent", title: "CreateThreadEvent", path: "language/words/c/createthreadevent.html" },
                { id: "language.word.currentthreadid", title: "CurrentThreadId", path: "language/words/c/currentthreadid.html" },
                { id: "language.word.currency", title: "Currency", path: "language/words/c/currency.html" }
              ]
            },
            {
              id: "language.words.d", title: "D", path: "language/words/d/index.html", children: [
                { id: "language.word.database", title: "Database", path: "language/words/d/database.html" },
                { id: "language.word.date", title: "Date", path: "language/words/d/date.html" },
                { id: "language.word.decimal", title: "Decimal", path: "language/words/d/decimal.html" },
                { id: "language.word.declare", title: "Declare", path: "language/words/d/declare.html" },
                { id: "language.word.default", title: "Default", path: "language/words/d/default.html" },
                { id: "language.word.defbool", title: "DefBool", path: "language/words/d/defbool.html" },
                { id: "language.word.defbyte", title: "DefByte", path: "language/words/d/defbyte.html" },
                { id: "language.word.defcur", title: "DefCur", path: "language/words/d/defcur.html" },
                { id: "language.word.defdate", title: "DefDate", path: "language/words/d/defdate.html" },
                { id: "language.word.defdbl", title: "DefDbl", path: "language/words/d/defdbl.html" },
                { id: "language.word.defint", title: "DefInt", path: "language/words/d/defint.html" },
                { id: "language.word.deflng", title: "DefLng", path: "language/words/d/deflng.html" },
                { id: "language.word.defobj", title: "DefObj", path: "language/words/d/defobj.html" },
                { id: "language.word.defsng", title: "DefSng", path: "language/words/d/defsng.html" },
                { id: "language.word.defstr", title: "DefStr", path: "language/words/d/defstr.html" },
                { id: "language.word.defvar", title: "DefVar", path: "language/words/d/defvar.html" },
                { id: "language.word.dim", title: "Dim", path: "language/words/d/dim.html" },
                { id: "language.word.do", title: "Do", path: "language/words/d/do.html" },
                { id: "language.word.double", title: "Double", path: "language/words/d/double.html" }
              ]
            },
            {
              id: "language.words.e", title: "E", path: "language/words/e/index.html", children: [
                { id: "language.word.each", title: "Each", path: "language/words/e/each.html" },
                { id: "language.word.else", title: "Else", path: "language/words/e/else.html" },
                { id: "language.word.elseif", title: "ElseIf", path: "language/words/e/elseif.html" },
                { id: "language.word.empty", title: "Empty", path: "language/words/e/empty.html" },
                { id: "language.word.end", title: "End", path: "language/words/e/end.html" },
                { id: "language.word.endproperty", title: "EndProperty", path: "language/words/e/endproperty.html" },
                { id: "language.word.enum", title: "Enum", path: "language/words/e/enum.html" },
                { id: "language.word.eqv", title: "Eqv", path: "language/words/e/eqv.html" },
                { id: "language.word.erase", title: "Erase", path: "language/words/e/erase.html" },
                { id: "language.word.error", title: "Error", path: "language/words/e/error.html" },
                { id: "language.word.event", title: "Event", path: "language/words/e/event.html" },
                { id: "language.word.exit", title: "Exit", path: "language/words/e/exit.html" },
                { id: "language.word.export", title: "Export", path: "language/words/e/export.html" },
                { id: "language.word.explicit", title: "Explicit", path: "language/words/e/explicit.html" }
              ]
            },
            { id: "language.words.f", title: "F" },
            { id: "language.words.g", title: "G" },
            { id: "language.words.h", title: "H" },
            { id: "language.words.i", title: "I" },
            { id: "language.words.j", title: "J" },
            { id: "language.words.k", title: "K" },
            { id: "language.words.l", title: "L" },
            { id: "language.words.m", title: "M" },
            { id: "language.words.n", title: "N" },
            { id: "language.words.o", title: "O" },
            { id: "language.words.p", title: "P" },
            { id: "language.words.q", title: "Q" },
            { id: "language.words.r", title: "R" },
            { id: "language.words.s", title: "S" },
            { id: "language.words.t", title: "T" },
            { id: "language.words.u", title: "U" },
            { id: "language.words.v", title: "V" },
            { id: "language.words.w", title: "W" },
            { id: "language.words.x", title: "X" },
            { id: "language.words.y", title: "Y" },
            { id: "language.words.z", title: "Z" }
          ]
        },
        { id: "language.symbols", title: "Symbols and operators", path: "language/symbols/index.html", aliases: ["punctuation", "type characters", "operator symbols"] },
        { id: "language.keywords", title: "Language words by category", path: "language/topics/keywords.html" },
        { id: "language.declarations", title: "Declarations", path: "language/topics/declarations.html" },
        { id: "language.properties-members", title: "Properties and members", path: "language/topics/properties-members.html" },
        { id: "language.types", title: "Types", path: "language/topics/types.html" },
        { id: "language.data-values", title: "Arrays, strings, and custom datatypes", path: "language/topics/data-values.html" },
        { id: "language.expressions", title: "Expressions and operators", path: "language/topics/expressions-operators.html" },
        { id: "language.scalar-operators", title: "Scalar values and operators", path: "language/topics/scalar-values-operators.html", aliases: ["numeric promotion", "Decimal", "Date", "Like"] },
        { id: "language.statements", title: "Statements", path: "language/topics/statements.html" },
        { id: "language.procedures-parameters", title: "Procedures and parameters", path: "language/topics/procedures-parameters.html" },
        { id: "language.conversions", title: "Conversions", path: "language/topics/conversions.html" },
        { id: "language.scope-modules", title: "Scope, modules, and visibility", path: "language/topics/scope-modules.html" },
        { id: "language.events-lifetime", title: "Events and program lifetime", path: "language/topics/events-program-lifetime.html" },
        { id: "language.event-binding", title: "WithEvents binding", path: "language/topics/event-binding.html", aliases: ["event handlers", "subscriptions"] },
        { id: "language.grammar", title: "Grammar", path: "language/topics/grammar.html" }
      ]
    },
    {
      id: "library.overview",
      title: "Core library",
      path: "library/index.html",
      children: [
        { id: "library.memory", title: "Managed memory and CollectGarbage", path: "library/memory.html", aliases: ["garbage collection", "class terminate"] },
        { id: "library.variant-inspection", title: "Variant inspection", path: "library/variant-inspection.html", aliases: ["isempty", "isnull", "empty", "null"] },
        { id: "library.threading", title: "Threading and synchronization", path: "library/threading.html", aliases: ["threadwait", "thread event", "semaphore", "message queue", "atomic"] }
      ]
    },
    {
      id: "tools.overview",
      title: "Compiler and tools",
      path: "tools/index.html",
      children: [
        { id: "tools.project-manifests", title: "Project manifests", path: "tools/project-manifests.html", aliases: [".UBE", "Reference", "StartupForm"] },
        { id: "diagnostic.ube1001", title: "UBE1001: source contains a NUL byte", path: "tools/ube1001.html" }
      ]
    },
    {
      id: "migration.overview",
      title: "VB6 migration",
      path: "migration/index.html"
    },
    {
      id: "platform.overview",
      title: "Platform guides",
      path: "platforms/index.html"
    },
    {
      id: "examples.overview",
      title: "Examples",
      path: "examples/index.html"
    },
    {
      id: "contribute.overview",
      title: "Contribute",
      path: "contribute/index.html"
    }
  ]
};

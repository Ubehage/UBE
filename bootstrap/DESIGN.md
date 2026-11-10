# Bootstrap source pipeline

The VB6 bootstrap consumes a `.UBE` project through `LoadProject`. The resulting
caller-owned `ProjectContext` retains source buffers in manifest order. The
lexer and parser operate on those buffers; they do not reopen sources or infer
additional modules from the working directory.

`--check` validates only the project and native source envelopes. `--parse`
requests a syntax tree for the admitted scalar profile. `--dump-ast` additionally
serializes that tree for inspection and structural assertions. `--analyze` and
`--dump-bound` additionally resolve declarations and check admitted scalar types
under [the semantic contract](SEMANTICS.md). No command executes error handling
or emits native code yet.
Success output is written only after every module completes the requested pass.

## Source and syntax ownership

Each parsed module retains its token buffer and root node. The project owns an
indexed node array with parent, first/last child and next-sibling links. Zero
means no node; real nodes use one-based indices. Module indices are zero-based
and preserve manifest order. The project root has module index -1.

Tokens preserve their original spelling and physical source coordinates.
Offsets, columns and lengths count UTF-16 code units in the decoded VB6 string;
offsets, lines and columns start at one. Source files remain UTF-8 on disk.
Comments and continuation syntax do not become expression nodes, but surviving
tokens retain their original physical positions. Node spans refer to those
tokens and the original source buffer, including intervening whitespace.

The tree represents syntax rather than resolved meaning. In particular,
`Err.Raise`, `Err.Clear` and `Err.Number` are ordinary member/call syntax here.
The binding pass connects resolved trusted declarations to the official
error-support contract in a separate caller-owned BoundProject. A parsed call
alone is not proof that its target exists or has a compatible
signature. Likewise, parsing a project does not prove a valid `Main` exists.

## Failure boundaries

The current command reports the first lexical or syntax error and fails the
whole parse. It never publishes a partial tree as a successful result. This is
bounded command-line failure handling, not IDE multi-error recovery. Later
editor synchronization must have its own tests before being claimed.

Input, token, node and nesting limits are checked before unbounded growth or
recursive descent. Diagnostic count is one per failed invocation. Host errors
return failure with a fresh diagnostic; they never infer success from the
contents of VB6's `Err` object. Compilation state belongs to the caller, with
no global mutable source, token or tree state.

The parser's bounds are 65,536 tokens per module, 262,144 tokens per
project, 65,536 tree nodes per project and 64 levels of recursive expression or
block parsing. The lexer caps a token's raw spelling at 4,096 UTF-16 code units
and an identifier at 128 decoded ASCII characters. The project token allowance
is passed to each module lexer before allocation. These admission limits do
not change the full language's grammar. The source-parsing gate exercises
successful inputs near limits and controlled rejection beyond the limits.

## Syntax dump

`--dump-ast` writes project/module summary lines, followed by records:

```text
NODE id|kind|text|module|line|column|firstChild|nextSibling|parent|type|modifiers|offset|length
```

Backslash, pipe, CR and LF in textual fields use `\\`, `\p`, `\r` and `\n`
respectively. Node identifiers and
links are local to one parse result. Tests must inspect tree relationships and
source spans, not treat incidental node numbers as language semantics. The dump
is a development inspection format, not a serialized library or stable ABI.

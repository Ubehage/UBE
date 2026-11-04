# Native absolute image pointer investigation

The next image-rebasing obligation now has an independent field census for all
16 retained images. This extends NATIVE-IMAGE-DIRECTORIES-INVESTIGATION.md without
claiming production relocation validation or CRT behavior qualification.

## Procedure and observed result - 2026-11-04

The available Node REPL imported
bootstrap/out/native-image-pointer-diagnostic.mjs and called its exported
inspectPointers with the repository root. The script reads the earlier passing
PE-directory diagnostic, verifies each original image hash, independently reads
PE section/symbol offsets and decodes every retained DIR64 field's eight-byte
preferred-base value. No image is executed and no production reader output is
used for the name/range classification. The output is
bootstrap/out/native-image-pointer-diagnostic.json: success true, 16 images and
18 input identities (script, preceding report and images).

Every image has 49 fields with the following same roles:

| Role | Fields per image |
| --- | ---: |
| Generated reference cells | 7 |
| CRT reference cells | 26 |
| Generated module-initializer entries | 3 |
| TLS directory pointers | 4 |
| TLS callback entries | 2 |
| Separate CRT dynamic-TLS-initializer pointer | 1 |
| CRT constructor entry | 1 |
| CRT destructor cursor | 1 |
| CRT local adapter pointers | 4 |

All 33 reference-cell values equal their named referents; the __ImageBase cell
is the intentional image-header/base case at RVA zero. All three generated
initializer entries point to the independently named module initializers in
source order. The earlier 36 unclassified fields are now accounted for by their
roles; classification is not proof of their complete runtime meaning.

The callback entries refer to __dyn_tls_init and __dyn_tls_dtor. The separate
__dyn_tls_init_callback cell also points at __dyn_tls_init. Four CRT local
adapter pointers are named __imp___p___initenv, __imp__amsg_exit,
__imp___getmainargs and __imp___initenv. These are local pointer cells rather than
ordinary loader-import thunks; their values require base relocation. The p.0
cursor points eight bytes beyond __DTOR_LIST__. The constructor-list entry has
no exact retained symbol at its target; its function entry/extent and CRT effects
still require qualification. Named addresses can have legitimate aliases,
including the empty runtime pseudo-relocation boundaries; do not infer unique
ownership merely from one chosen name.

## Required next production work

Validate the base-relocation directory with existing bounded readers, reject
unsupported/malformed/duplicate or overlapping relocation fields, and associate
the actual writes with expected pointer storage. Generated reference cells,
initializer entries and TLS directory/callback pointers must have the required
DIR64 entries. Preserve the explicit CRT and image-header cases, with their
separate trust and runtime-effect obligations. A preferred-base equality check
alone does not prove correct rebasing, and a role label does not prove that
arbitrary relocation writes are safe.

The TLS template/index and callback metadata work, subsequent register provenance,
global storage aliases, complete startup/callback/control-flow and stack/debug
closure, build ownership and final native acceptance remain part of the original
goal. This diagnostic does not reduce any of those requirements.

# Manifest Design, Implementation, and Implications

## 1. Purpose and Scope

### Explicit decisions

A manifest is a Bark-standard Pkl value used to track and reference a non-Pkl filesystem target inside the Bark system.

The manifest system exists to give non-Pkl resources a Pkl-visible handle.

A manifest is not a replacement for graph nodes, tables, indexes, collections, or containers.

A manifest file is discovered by filename pattern:

```txt
*.manifest.pkl
```

A manifest file is a special indexed file form, but the evaluated manifest value is still normal Pkl data.

### Implications

Pkl files can participate in the projection directly.

Non-Pkl files participate through adjacent manifest files.

Manifest files are both:

```txt
1. Pkl data that may be projected.
2. Bark-tracked resource declarations that are globally indexed and prechecked.
```

The tracking behavior and the projection behavior are separate concepts.

### Examples

```txt
receipt.pdf
receipt.pdf.manifest.pkl
```

The manifest file gives `receipt.pdf` a Pkl handle.

```pkl
amends "@bark/Manifest.pkl"

id = "..."
target = "receipt.pdf"
description = "Supplier receipt."
```

### Undecided details

The final import path for the Bark manifest type is not locked.

Example placeholders:

```pkl
amends "@bark/Manifest.pkl"
amends "@bark/std/Manifest.pkl"
amends "@bark/core/Manifest.pkl"
```

### Implementation directions

The manifest system should be implemented as a standard library type plus a pre-projection manifest discovery/indexing pass.

The projection compiler should treat manifest files as projectable Pkl files according to normal projection context, while the pre-projection manifest pass handles manifest-specific checks.

---

## 2. Manifest as Data vs Manifest as File

### Explicit decisions

A manifest value is normal Pkl data.

A manifest file is a Pkl file matching:

```txt
*.manifest.pkl
```

Only files matching `*.manifest.pkl` are globally discovered as manifest files.

A random Pkl file that evaluates to a manifest-shaped value is not automatically an indexed manifest file.

### Implications

This distinction is central:

```txt
Manifest value:
  the evaluated Pkl data

Manifest file:
  the Bark-indexed source file that gives the value location semantics
```

The system must not assume that any manifest-shaped value is backed by an indexed manifest file.

A manifest’s indexed identity comes from the pre-projection manifest index, not from shape alone.

### Examples

Indexed manifest:

```txt
receipt.pdf.manifest.pkl
```

Not an indexed manifest merely by filename:

```txt
receipt.pkl
```

Even if `receipt.pkl` contains fields similar to a manifest, it is not a tracked manifest file unless it matches the manifest file pattern.

### Undecided details

None for this distinction.

### Implementation directions

The global manifest discovery pass should scan for `*.manifest.pkl`.

It should not scan every Pkl file looking for manifest-shaped values.

---

## 3. Manifest File Naming and Sidecar Rule

### Explicit decisions

Manifest files use sidecar naming:

```txt
<target>.manifest.pkl
```

The manifest file describes the target named by `<target>`.

The manifest value must contain a `target` field.

The `target` field must match the sidecar target name exactly.

The target must exist beside the manifest file.

### Implications

This is valid:

```txt
receipt.pdf
receipt.pdf.manifest.pkl
```

with:

```pkl
target = "receipt.pdf"
```

This is invalid:

```txt
receipt.pdf
receipt.pdf.manifest.pkl
```

with:

```pkl
target = "invoice.pdf"
```

The sidecar filename is meaningful, not just a convention.

### Examples

File target:

```txt
lots/L1/receipt.pdf
lots/L1/receipt.pdf.manifest.pkl
```

Manifest:

```pkl
amends "@bark/Manifest.pkl"

id = "..."
target = "receipt.pdf"
description = "Receipt for lot L1."
```

Directory target:

```txt
lots/L1/photos/
lots/L1/photos.manifest.pkl
```

Manifest:

```pkl
amends "@bark/Manifest.pkl"

id = "..."
target = "photos"
isDir = true
description = "Photo set for lot L1."
```

### Undecided details

The final exact error wording for sidecar mismatch is undecided.

The sidecar naming rule itself is decided.

### Implementation directions

The manifest precheck should derive the expected target name from the manifest filename.

For:

```txt
receipt.pdf.manifest.pkl
```

the derived target is:

```txt
receipt.pdf
```

Then it should compare this to:

```pkl
target = "receipt.pdf"
```

Mismatch is a hard error.

---

## 4. Manifest Type Shape

### Explicit decisions

The v0 manifest type should remain minimal and concrete.

It should be a single non-generic Bark schema module.

Pkl 0.31 does not support user-defined generic classes, and Bark's generated registry currently imports schemas as concrete single-file modules.

The v0 registry should therefore refer to one concrete manifest schema module, not to a parameterized manifest type.

The authored manifest should not include hash or size.

The manifest should include:

```pkl
id: String
target: G.PosixFileName

description: String?
tags: Mapping<String, TagValue>
meta: Any?

isDir: Boolean = false
```

`TagValue` starts as:

```txt
String | Number | Boolean
```

`target` should be a narrow basename-only string type by default.

The final v0 name may be `G.PosixFileName` directly or a manifest-specific alias with equivalent basename-only behavior.

### Implications

The manifest is a stable reference and metadata handle.

It is not a file-integrity record.

Editing a target file should not require updating the manifest.

Hashes, file sizes, MIME types, physical paths, and other derived properties belong in generated metadata if needed.

### Examples

Minimal file manifest:

```pkl
amends "@bark/Manifest.pkl"

id = "018f4f55-..."
target = "receipt.pdf"
```

Manifest with UI-friendly metadata:

```pkl
amends "@bark/Manifest.pkl"

id = "018f4f55-..."
target = "receipt.pdf"

description = "Supplier receipt for lot L1."

tags {
  ["kind"] = "receipt"
  ["supplier"] = "Alibaba"
  ["paid"] = true
  ["amount"] = 64.30
}

meta {
  agentNotes = "Imported during lot reconciliation."
}
```

Directory manifest:

```pkl
amends "@bark/Manifest.pkl"

id = "7e821f4b-..."
target = "photos"
isDir = true
description = "Photo directory for this lot."
```

### Undecided details

The desired future generic shape remains undecided.

Possible conceptual direction:

```pkl
Manifest<TargetName, Tags>
```

This remains an aspirational type-system direction, not a v0 implementation shape.

It is not available as a user-defined generic class in current Pkl.

Until Pkl and/or Bark's registry can support a better abstraction, specialization should use concrete manifest schema files, subclasses, or wrappers.

The exact future Pkl syntax and type parameters are not locked.

The final type name for `TargetName` is not locked.

The final definition of `Number` in `TagValue` is not locked; it may map to Pkl numeric types explicitly.

### Implementation directions

`target` should reject paths.

Accepted:

```txt
receipt.pdf
source-image.png
photos
```

Rejected:

```txt
../receipt.pdf
folder/receipt.pdf
/absolute/path
```

`tags` should remain predictable for UI filtering and search.

`meta` should remain available for arbitrary tool, agent, or process data that should not pollute meaningful tag space.

---

## 5. Fields Excluded from Authored Manifest

### Explicit decisions

The authored manifest should not include:

```txt
hash
size
full manifest path
full target path
MIME type
```

The manifest should not dynamically include its own source path when evaluated.

### Implications

The manifest remains readable and stable.

The system does not force authors or tools to update the manifest when the target file changes.

Location-sensitive information is generated separately.

### Examples

Do not author:

```pkl
hash = "sha256-..."
sizeBytes = 123456
manifestPath = "lots/L1/receipt.pdf.manifest.pkl"
targetPath = "lots/L1/receipt.pdf"
```

Use:

```pkl
id = "018f4f55-..."
target = "receipt.pdf"
description = "Supplier receipt."
```

### Undecided details

MIME detection is deferred.

Generated metadata may later include MIME type, but this is not part of the authored manifest design.

### Implementation directions

A generated metadata file should carry physical information such as manifest path and target path.

The manifest itself should stay as authored domain metadata.

---

## 6. Manifest Identity

### Explicit decisions

Each manifest has an `id`.

Manifest ids must be globally unique within the governed repository.

Manifest ids are primarily generated.

Users are not prevented from setting ids manually, but duplicate ids are invalid.

The id is not the user-facing addressing mechanism.

Imports remain path-based.

### Implications

The id is used to connect an evaluated manifest value back to the generated manifest index.

This is necessary because once a manifest is imported, the evaluated value does not retain its source file path.

The id is internal identity, not an import address.

### Examples

Correct reference:

```pkl
receipt = import("receipt.pdf.manifest.pkl")
```

Not the intended user-facing addressing model:

```pkl
receipt = Bark.manifestById("018f4f55-...")
```

Duplicate id error example:

```txt
Duplicate manifest id.

id:
  "018f4f55-..."

Declared in:
  lots/L1/receipt.pdf.manifest.pkl
  archive/L1/receipt.pdf.manifest.pkl

Manifest ids must be globally unique because they are used to recover the source path of imported manifest values.
```

### Undecided details

The exact id generation strategy is not locked.

UUIDs are the current intended default.

### Implementation directions

The pre-projection manifest pass should build:

```txt
manifest id -> manifest file path -> target path
```

Duplicate ids should produce diagnostics that show every conflicting manifest file path.

---

## 7. Manifest Projection Behavior

### Explicit decisions

Manifests are projected like other loose Pkl files.

They obey the normal projection context.

Index boundaries still control projection.

Declared table types still enforce their declared type.

All `*.manifest.pkl` files are globally prechecked regardless of whether they are projected.

### Implications

Manifest tracking is global.

Manifest projection is contextual.

In an indexed directory, a manifest beside `index.pkl` is not automatically projected. The index boundary still projects only the index unless the index imports the manifest.

In a loose directory, manifests participate in loose projection.

In a declared table, manifests are projected according to table rules and fail if they do not satisfy the table type.

### Examples

Indexed directory:

```txt
lots/L1/
  index.pkl
  receipt.pdf
  receipt.pdf.manifest.pkl
```

If `lots/L1` is an index node, the projected value comes from:

```txt
lots/L1/index.pkl
```

The manifest is globally checked, but not projected unless `index.pkl` imports it.

Loose directory:

```txt
random/
  receipt.pdf
  receipt.pdf.manifest.pkl
```

The manifest participates in loose projection.

Declared product table:

```txt
products/
  P1.pkl
  random.pdf
  random.pdf.manifest.pkl
```

If `products` is declared as `Table(Product)`, then the manifest appears in the table projection attempt and fails type checking because it is not a `Product`.

This is intentional strictness for declared tables.

### Undecided details

None for the projection rule.

### Implementation directions

Projection generation should not globally hide manifest files.

Projection generation should apply the same projection-boundary logic already used for loose Pkl files, tables, and indexes.

Manifest-specific prechecks run separately from projection generation.

---

## 8. Projection Key for Manifests

### Explicit decisions

A projected manifest should use the target name as its projection key.

The key should not be the manifest filename stem.

### Implications

This:

```txt
receipt.pdf.manifest.pkl
```

projects under:

```txt
"receipt.pdf"
```

not:

```txt
"receipt.pdf.manifest"
```

The manifest represents the tracked target, not the sidecar file itself.

Full target names prevent collisions between files such as:

```txt
receipt.pdf
receipt.jpg
```

because their projected keys are:

```txt
"receipt.pdf"
"receipt.jpg"
```

### Examples

Input:

```txt
random/
  receipt.pdf
  receipt.pdf.manifest.pkl
  receipt.jpg
  receipt.jpg.manifest.pkl
```

Projected shape:

```pkl
random {
  ["receipt.pdf"] = import("receipt.pdf.manifest.pkl")
  ["receipt.jpg"] = import("receipt.jpg.manifest.pkl")
}
```

Conflict example:

```txt
random/
  receipt.pdf.pkl
  receipt.pdf
  receipt.pdf.manifest.pkl
```

If both entries project under:

```txt
"receipt.pdf"
```

this is a normal projection key conflict.

### Undecided details

Exact diagnostic wording for projection key conflicts is undecided.

### Implementation directions

When projecting a manifest file, derive the projection key from the sidecar target name.

For:

```txt
receipt.pdf.manifest.pkl
```

the projection key is:

```txt
receipt.pdf
```

---

## 9. Global Manifest Precheck

### Explicit decisions

All `*.manifest.pkl` files in the governed repository are globally prechecked before projection.

This applies even when a manifest is behind an index boundary and not projected.

Manifest precheck is strict.

`.bark` internal/generated areas are not part of this scan.

### Implications

A malformed manifest is a hard error even if it would not appear in the final projection.

This differs from ordinary unprojected Pkl files, which the current system does not necessarily validate.

The reason is that manifest files are Bark-tracked resource declarations.

### Examples

This is checked:

```txt
lots/L1/
  index.pkl
  unused.pdf
  unused.pdf.manifest.pkl
```

Even if `index.pkl` does not import `unused.pdf.manifest.pkl`, the manifest file is still checked.

If `unused.pdf` is missing, validation fails.

### Undecided details

The exact ignored path rules are not fully locked.

Known excluded areas:

```txt
.bark/internal
.bark/generated
```

Additional ignored areas may be implementation-defined.

### Implementation directions

The pre-projection manifest pass should run before projection generation.

It should catch errors that would otherwise produce confusing projection failures.

At minimum, it should check:

```txt
1. file matches *.manifest.pkl
2. file evaluates as Bark Manifest
3. manifest has the Bark manifest marker
4. id is present
5. id is globally unique
6. target is present
7. target is basename-only
8. sidecar target name matches target
9. target exists
10. target kind matches isDir
```

---

## 10. Target Files and Directories

### Explicit decisions

Manifests primarily track files.

Manifests may also target directories if the same sidecar rule applies.

Directory targets use:

```pkl
isDir = true
```

File targets omit `isDir` because it defaults to false.

### Implications

The manifest model stays the same for files and directories.

The field is called `target`, not `filename`, because the target may be a directory.

Directory targets give Bark a way to reference a non-indexed directory as a stable resource.

### Examples

File target:

```txt
receipt.pdf
receipt.pdf.manifest.pkl
```

```pkl
target = "receipt.pdf"
```

Directory target:

```txt
photos/
photos.manifest.pkl
```

```pkl
target = "photos"
isDir = true
```

### Undecided details

The amount of v0 tooling for directory manifests is undecided.

Directory manifests are allowed by the same rule, but the primary design target remains file resources.

### Implementation directions

Validation should check target kind:

```txt
isDir = false:
  target must exist and be a file

isDir = true:
  target must exist and be a directory
```

The generated metadata can include target kind.

MIME detection is not required.

---

## 11. Generated Projection Metadata

### Explicit decisions

A generated projection metadata file is necessary.

It should exist beside the generated projection.

It must include at least the manifest index.

The metadata file contains evaluated/generated system data, not authored manifest data.

### Implications

The projection contains domain data.

The projection metadata contains physical/resource resolution data.

This keeps the manifest value readable while still giving APIs enough information to resolve backing files.

The metadata is useful for API consumers, file-serving systems, mirrored storage buckets, and resource lookup.

### Examples

Generated files may conceptually include:

```txt
ProjectionSchema.pkl
projection.pkl
ProjectionMetaSchema.pkl
projection-meta.pkl
```

The exact filenames are not locked.

Metadata shape:

```pkl
manifestIndex {
  ["018f4f55-..."] {
    manifestPath = "lots/L1/receipt.pdf.manifest.pkl"
    targetPath = "lots/L1/receipt.pdf"
    target = "receipt.pdf"
    isDir = false
  }
}
```

### Undecided details

The final metadata filename is undecided.

The final metadata schema filename is undecided.

The final metadata validation strategy is undecided.

Known options:

```txt
1. projection-meta.pkl amends a generated ProjectionMetaSchema.pkl.
2. projection.pkl attaches metadata and validates projection + metadata together.
3. a separate validation command validates metadata.
```

No option is locked.

### Implementation directions

The manifest precheck should generate or provide the data needed to render the metadata file.

The metadata should include enough information to resolve:

```txt
manifest id -> manifest file path -> target path
```

Physical paths should live in metadata, not in the authored manifest.

---

## 12. Resource Resolution

### Explicit decisions

Resource resolution uses the manifest id and the generated manifest index.

A manifest value alone is not enough to resolve the physical target path.

The intended resource access shape is conceptually:

```pkl
Bark.resource(import("receipt.pdf.manifest.pkl"))
```

The result should be a resource object, not merely raw contents.

### Implications

The import gives good Pkl-level errors for missing or invalid manifest files.

The generated manifest index recovers source-location information that is lost after import.

The manifest and the resolved resource are separate concepts.

### Examples

Projected/indexed Pkl:

```pkl
receipt = import("receipt.pdf.manifest.pkl")
receiptResource = Bark.resource(receipt)
```

Conceptual resolution:

```txt
1. read receipt.id
2. look up receipt.id in manifestIndex
3. find manifestPath
4. find targetPath
5. return Resource for targetPath
```

### Undecided details

The final function name is undecided.

Candidate names:

```pkl
Bark.resource(...)
Bark.readResource(...)
Bark.file(...)
```

The internal shape of `Resource` is undecided.

### Implementation directions

Resource resolution should not trust `target` alone.

It should use:

```txt
manifest.id
manifestIndex
targetPath
```

If a manifest id is not present in the generated manifest index, resource resolution fails.

---

## 13. Special Bark Marker

### Explicit decisions

The manifest type should contain a special Bark marker.

The marker identifies the value as a Bark manifest.

The exact marker field name and value are not locked.

There will not be a global scan of every Pkl file to search for this marker.

Only `*.manifest.pkl` files are globally scanned as manifest files.

### Implications

The marker helps accurately recognize and dedupe manifests during manifest processing.

The marker is part of manifest type identity.

The marker does not create a repository-wide policing pass.

A random projected value with similar fields is not automatically treated as a manifest unless it is backed by a manifest file and index entry.

### Examples

Possible marker shape:

```pkl
__bark = "manifest"
```

Alternative spelling is undecided.

The important concept is:

```txt
special marker = expressive type identifier
```

not a bulky metadata object.

### Undecided details

The final marker field name is undecided.

The final marker value is undecided.

Whether future Bark-special file types reuse the same marker field is undecided.

### Implementation directions

The precheck for `*.manifest.pkl` should require the marker.

No global marker scan should be implemented for v0.

---

## 14. Strictness, Coherence, and Error Hoisting

### Explicit decisions

Known Bark validation errors are collected during preprocessing rather than thrown.

Detailed findings live in `metadata.preprocessErrors`. Postprocess converts any non-empty preprocessing error list into one aggregate `PREPROCESS_FAILED` result error, while its own coherence checks add their errors directly to `result.errors`. The aggregate error lists the named preprocessing errors and repeats their human-readable messages for result-only terminal output, without copying the structured error entries into the result list.

Natural Pkl syntax, import, type, schema, and internal-invariant failures continue to fail at their normal evaluation point with full Pkl diagnostics.

### Implications

The final postprocess envelope contains `projection`, `metadata`, and `result`. `result.errors.isEmpty` is the validity decision.

The semantic rule remains simple:

```txt
A manifest is coherent if:
  its id is unique
  its sidecar name matches target
  its target exists
  its target kind matches isDir
```

Without force, postprocess does not publish the full envelope when result errors are present. Force permits publication but does not remove or downgrade any errors.

### Examples

Detailed preprocessing metadata:

```pkl
preprocessErrors = List(
  new Errors.Error {
    code = "MANIFEST_TARGET_MISSING"
    message = "..."
  }
)
```

Final postprocess result:

```pkl
result {
  errors = List(
    new {
      code = "PREPROCESS_FAILED"
      message = "Preprocess failed with 1 error:\n\n1. MANIFEST_TARGET_MISSING\n   Manifest target missing.\n..."
    }
  )
}
```

### Undecided details

How a future procedure composer presents structured errors to CLI users is outside the Pkl system contract.

### Implementation directions

Keep detailed preprocessing findings only in metadata and avoid copying them into the final result.

Use a single aggregate `PREPROCESS_FAILED` result error as the postprocess gate.

Reserve throws for natural Pkl failures rather than Bark validation findings.

---

## 15. Tables, Loose Directories, and Index Boundaries

### Explicit decisions

Manifests obey the same projection context as other projectable Pkl files.

Index boundaries curate projection.

Declared tables enforce declared type.

Loose directories project manifests normally.

### Implications

No special `ManifestTable` node is required for correctness.

A table of manifests can be a table whose entry type is Manifest.

A manifest accidentally placed in a non-manifest table should fail through normal table type validation.

### Examples

Table of manifests:

```pkl
["files"] = Table(Bark.Manifest)
```

Non-manifest table with accidental manifest:

```txt
products/
  P1.pkl
  random.pdf
  random.pdf.manifest.pkl
```

If `products` is:

```pkl
Table(Product)
```

then `random.pdf.manifest.pkl` is not silently ignored. It is projected as a table entry and fails type validation.

Index boundary:

```txt
order/
  index.pkl
  receipt.pdf
  receipt.pdf.manifest.pkl
```

If `order` is indexed, only `index.pkl` determines the projected interface unless it imports the manifest.

### Undecided details

The final user-facing shorthand for manifest tables is undecided.

A dedicated `ManifestTable` is not currently required.

### Implementation directions

Do not add `ManifestTable` as a core graph node for v0.

Rely on normal table typing and manifest prechecks.

---

## 16. Generic Inclusion Shorthands

### Explicit decisions

A special `Manifests()` shorthand is not required for the current design.

The more general future direction is a shorthand for projecting Pkl imports/globs as tables.

This is deferred.

### Implications

Manifest inclusion can be expressed through normal projection rules and table declarations.

A future generic shorthand could cover manifests and other Pkl file groups.

### Examples

Possible future direction:

```pkl
asTable(import*("*.pkl"))
```

This could later cover:

```txt
all manifest files
all loose Pkl files
all Pkl files matching a pattern
```

### Undecided details

The shorthand syntax is undecided.

Whether this becomes `asTable`, `Table(import*)`, `Manifests()`, or something else is undecided.

### Implementation directions

Do not add a manifest-specific shorthand before the general glob/import table design is revisited.

Make a note in the document that manifest inclusion may later be covered by generalized Pkl import-table shorthand.

---

## 17. Error Cases to Document

### Explicit decisions

The following make the Bark result invalid; representable findings are structured validation errors rather than Pkl exceptions:

```txt
1. target file or directory missing
2. sidecar target name does not match manifest.target
3. manifest id missing
4. duplicate manifest id
5. target contains path traversal or slash
6. isDir does not match actual target kind
7. *.manifest.pkl does not evaluate as a valid Manifest
8. *.manifest.pkl lacks the Bark manifest marker
9. projected table entry fails the declared table type
```

### Implications

Manifest diagnostics should be explicit and path-oriented.

Manifest errors should explain both the manifest file path and the target path when applicable.

### Examples

Missing target:

```txt
Manifest target missing.

Manifest:
  lots/L1/receipt.pdf.manifest.pkl

Expected target:
  lots/L1/receipt.pdf
```

Sidecar mismatch:

```txt
Manifest sidecar mismatch.

Manifest file:
  lots/L1/receipt.pdf.manifest.pkl

Expected target from sidecar:
  receipt.pdf

Manifest target:
  invoice.pdf
```

Duplicate id:

```txt
Duplicate manifest id.

id:
  "018f4f55-..."

Declared in:
  lots/L1/receipt.pdf.manifest.pkl
  archive/L1/receipt.pdf.manifest.pkl
```

Wrong table type:

```txt
products/random.pdf.manifest.pkl was projected as an entry of products,
but products is declared as Table(Product).
```

### Undecided details

Exact diagnostic formatting is undecided.

### Implementation directions

Diagnostics should prefer Bark-specific errors before generic Pkl type errors when the Bark-specific cause is known before projection.

---

## 18. Final Conceptual Summary

### Explicit decisions

A manifest is a projected Pkl handle for a non-Pkl target.

The manifest file form, `*.manifest.pkl`, gives the target a stable identity and a discoverable source location.

The generated projection metadata preserves the physical relationship between:

```txt
manifest id
manifest file path
target path
```

### Implications

Manifests are part of the normal projection system.

Manifest indexing is stricter than ordinary loose-file validation.

Projection consumers can read manifest values as normal data.

Resource consumers can use projection metadata to resolve backing files.

### Examples

Tree:

```txt
lots/
  L1/
    index.pkl
    receipt.pdf
    receipt.pdf.manifest.pkl
```

Manifest:

```pkl
amends "@bark/Manifest.pkl"

id = "018f4f55-..."
target = "receipt.pdf"
description = "Supplier receipt."

tags {
  ["kind"] = "receipt"
}
```

Index:

```pkl
receipt = import("receipt.pdf.manifest.pkl")
```

Generated metadata:

```pkl
manifestIndex {
  ["018f4f55-..."] {
    manifestPath = "lots/L1/receipt.pdf.manifest.pkl"
    targetPath = "lots/L1/receipt.pdf"
    target = "receipt.pdf"
    isDir = false
  }
}
```

### Undecided details

The remaining undecided details are:

```txt
1. final Bark manifest marker field name and value
2. future Manifest generic/type-argument direction after v0 concrete schema
3. final projection metadata file names
4. final Resource object shape
5. final generic glob/import table shorthand
6. exact diagnostics formatting
```

### Implementation directions

Implement the manifest design in this order:

```txt
1. Define minimal Bark Manifest type.
2. Add global *.manifest.pkl discovery.
3. Validate manifest sidecar, id, target, marker, uniqueness, and target kind.
4. Generate manifestIndex metadata.
5. Project manifests according to normal projection context.
6. Resolve resources through manifest.id and manifestIndex.
7. Carry preprocessing findings through metadata and enforce them through the postprocess result.
```

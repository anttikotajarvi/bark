# Bark implementation notes (temporary)

This is a working decision log, not polished user documentation. It records the small semantic choices and emergent behavior discovered while building the current projection pipeline.

## Current pipeline

1. Read the graph from `repo/.bark/registry.pkl`.
2. Render `ProjectionSchema.pkl` from the graph.
3. Collect static graph paths and expand observed collection children.
4. Check that those directories exist in the filesystem.
5. Seed an entry tree with the declared directories, including empty ones.
6. Add imported user entries and collapse directories containing `index.pkl`.
7. Render `projection.pkl`, using the graph to distinguish properties from mapping elements.
8. Evaluate `projection.pkl` against `ProjectionSchema.pkl`.

From `repo/`, the whole flow is:

```sh
./.dev/full-project
```

For development throughput tests, run:

```sh
./.dev/test
./.dev/test basic
```

Each fixture is a small dev-only package under `.test-fixtures/<name>/`:

```text
.test-fixtures/<name>/repo/        # data repo subtree passed as include prefix
.test-fixtures/<name>/.bark-test/  # fixture registry and pkl:test assertions
```

The root `.bark/registry.pkl` reads `BARK_TEST_REGISTRY` for this development
repo's tests and delegates to a fixture registry when the test runner sets it.
This is project-local test wiring, not Bark core behavior.

To scope generation to a physical subtree while keeping projected paths relative
to that subtree, pass an include prefix:

```sh
./.dev/full-project --include-prefix .test-fixtures/basic/repo/
```

The script interface is rooted at the data repository directory. Run it from
`repo/`, and run Pkl with `--module-path .`; under this contract,
`modulepath:/` resolves to the data repo root. The `.bark/` directory is
Bark-managed content inside that root. It may be managed separately, such as as
a submodule, but the containing data repo root remains the command boundary.

## Failure policy

The guiding rule is: generate Pkl whenever the observed state can be represented, then let Pkl validate its meaning. Generated source may therefore be syntactically valid while deliberately failing the generated schema.

Failures fall into three categories:

- **Deferred Pkl validation.** Missing indexes, wrong collection entry types, invalid imported values, and schema mismatches are represented in `projection.pkl` and rejected when it is evaluated against `ProjectionSchema.pkl`.
- **Pre-generation directory-shape errors.** A graph-required filesystem directory that does not exist fails before seeding or rendering. This is the expected user-facing Bark error during generation.
- **Internal invariant and dependency errors.** Unknown graph/tree node types and missing Bark renderer dependencies indicate implementation or installation failures, not invalid user data.

An unresolved `IndexNode` demonstrates the deferred approach. Its seeded mapping is rendered as:

```pkl
new Dynamic {}
```

This is an intentional placeholder: it keeps the generated Pkl valid as source while guaranteeing that evaluation fails against the indexed schema type.

Directory-shape validation is the deliberate exception to deferring errors. Seeding alone cannot preserve whether a path existed: a missing `products/` and an existing empty `products/` would both become `{}`. Mapping defaults can then make both appear valid. Static children below an index boundary also disappear from projection and cannot be checked by the generated schema. Filesystem existence must therefore be checked before those paths are seeded.

In this context, an **invalid directory shape** means a missing graph-required filesystem path, including static descendants beneath observed collection entries. It does not mean an empty index, a wrong entry type, or another state that can be represented and deferred to Pkl validation.

## Graph semantics

- The graph is additive. It declares the minimum structure known to exist in the projection; it does not describe everything that is allowed to exist.
- Statically declared paths must exist as directories in the filesystem.
- A declared directory may be empty and must still appear in the projection.
- A missing declared directory is an error before projection code is generated.
- Schema stubs such as `schema.pkl` are not used as evidence that a directory exists. Directory checks operate on the directory path itself.
- `DirNode` declares named child properties.
- `TableNode` projects ordinary files as mapping elements keyed by filename stem.
- `CollectionNode` projects child directories as mapping elements keyed by directory name.
- `IndexNode` projects the directory's `index.pkl`; its declared children are still required filesystem paths, but are not projected automatically.
- Collection entry names are dynamic, but every observed collection child is seeded and checked against the collection's entry-node shape.

Example: if `products/` exists but has no product entries, the generated projection still contains:

```pkl
`products` {}
```

If `products/` itself is missing, generation fails with the shared missing-directory error.

## Loose structure

- The generated schema is an `open module`, allowing undeclared top-level projection properties.
- Classes generated for nested `DirNode` values are `open class` declarations.
- Declared members remain typed while the design leaves room for additional structure.
- The generated projection uses `extends "ProjectionSchema.pkl"`, not `amends`, so it can introduce loose top-level properties.
- Undeclared structural directories are rendered as `Dynamic` objects.
- Undeclared empty directories outside graph collection boundaries cannot currently be discovered or projected; static paths and observed collection children are seeded.

## Entry-tree behavior

- The raw entry tree is built separately from schema rendering.
- Directory seeding is a distinct preprocessing step rather than part of file insertion.
- Statically declared paths and observed collection children are both seeded, including empty directories.
- `index.pkl` is a filesystem-level projection boundary, independent of whether the graph declares an `IndexNode`.
- Index collapse is insertion-order independent:
  - If other entries arrive first, `index.pkl` replaces their directory mapping.
  - If `index.pkl` arrives first, later descendants are ignored.
- Duplicate leaves and file/directory collisions reject the incoming entry and preserve the original tree.
- Schema files and index-schema files are excluded from projected entries.
- Files under `.bark/` are excluded from the user entry tree.
- Files under `.test-fixtures/` are excluded by default unless an include prefix
  explicitly points inside that tree.
- Pkl forbids recursive type aliases, so `ENode` uses `Mapping<String, Any>` and the entry-tree functions maintain the recursive invariant.

## Directory validation

- `DirectoryShape.pkl` contains reusable graph traversal and validation logic.
- It has no knowledge of `pwd`, `read?`, import globs, or the repository layout.
- Callers provide a `(Path) -> Boolean` existence predicate.
- The Pkl command adapts this API with a filesystem `read?` check.
- Collection expansion uses a caller-provided directory-children function, keeping filesystem enumeration outside the reusable validator.
- The Pkl-only adapter reads names from directory resources and is less strict about distinguishing files from directories; a native CLI can provide true directory-only children through the same API.
- A future custom CLI can provide a stricter native filesystem implementation without changing graph traversal.
- User-facing missing-directory failures are created through `Errors.missingRequiredDirectories`, with optional contextual information.

## Projection code generation

- The graph does not control entry-tree insertion or index collapse.
- During rendering, it is consulted to choose syntax:
  - `DirNode` and loose directory children become properties.
  - `TableNode` and `CollectionNode` children become mapping elements.
- Indexed entries render as direct imports.
- A seeded `IndexNode` without `index.pkl` renders as `new Dynamic {}` so normal Pkl type validation rejects it.
- Declared object properties are amended with readable nested blocks.
- Generated source intentionally favors readable Pkl over compact output.

## Paths and command interfaces

- Both generators are Pkl commands with `--output` and `--path-prefix` options.
- Projection imports are rendered as `PATH_PREFIX + entry.importPath`; normally
  this equals the logical local path, but include-prefix runs keep imports
  physical while stripping the prefix from projected keys.
- Schema import prefixes apply to graph-declared user schemas; Bark's internal `Generic.pkl` import remains relative.
- Generated files include a do-not-edit comment and the effective generator arguments.
- Commands are designed to run from the data repo root, `repo/`, with `--module-path .`.
- Under that contract, `modulepath:/` resolves to the data repo root, so Bark imports keep the form `modulepath:/.bark/core/...` and `modulepath:/.bark/schemas/...`.
- `.bark/` is Bark-managed content inside the data repo root. It may be a submodule or separately managed directory, but the script interface is anchored at the containing data repo root.
- `ROOT_PATH = "../../../"` is the path from `.bark/core/scripts` back to the data repo root.
- The static `import*("../../../**.pkl")` glob scans the data repo root; shared
  path filtering excludes `.bark/`, excludes `.test-fixtures/` by default, and
  applies `bark.includePrefix` when present.
- `bark.includePrefix` is an external Pkl property passed by the shell wrapper
  with `-p`. It scopes Pkl file discovery, manifest discovery, and directory
  shape filesystem reads. It does not change registry loading.
- The shell wrapper supports overriding the Pkl executable through `PKL`.

## Pkl behavior that affected the design

- Mapping-typed properties can default to empty mappings. Schema evaluation alone therefore cannot distinguish an omitted directory from an existing empty directory.
- That is why filesystem shape validation and tree seeding happen before rendering.
- Empty collection entries are interpreted by their entry-node type: an empty table may be valid, while an empty index fails validation.
- `open class` permits extension through subclasses; it does not make arbitrary properties valid on a base-class object literal by itself.
- Pkl commands cannot orchestrate other processes, so the multi-step generate-and-evaluate workflow uses a small POSIX shell script.

## Current generated artifacts

The wrapper writes:

```text
repo/.bark/core/generated/ProjectionSchema.pkl
repo/.bark/core/generated/projection.pkl
```

These are generated artifacts. The source of truth is the graph, the user files, and the generator implementation.

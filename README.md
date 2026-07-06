# Bark implementation notes (temporary)

This is a working decision log, not polished user documentation. It records the small semantic choices and emergent behavior discovered while building the current projection pipeline.

## Current pipeline

1. Read the graph from `repo/.bark/registry.pkl`.
2. Render `ProjectionSchema.pkl` from the graph.
3. Collect every statically declared graph path.
4. Check that those directories exist in the filesystem.
5. Seed an entry tree with the declared directories, including empty ones.
6. Add imported user entries and collapse directories containing `index.pkl`.
7. Render `projection.pkl`, using the graph to distinguish properties from mapping elements.
8. Evaluate `projection.pkl` against `ProjectionSchema.pkl`.

From `repo/`, the whole flow is:

```sh
./.bark/core/scripts/generate-and-check.sh
```

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
- Validation stops at a collection's dynamic entry boundary. The collection directory is static and required, but particular entry names are not.

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
- Undeclared empty directories cannot currently be discovered or projected; only graph-declared empty paths are seeded.

## Entry-tree behavior

- The raw entry tree is built separately from schema rendering.
- Static directory seeding is a distinct preprocessing step rather than part of file insertion.
- `index.pkl` is a filesystem-level projection boundary, independent of whether the graph declares an `IndexNode`.
- Index collapse is insertion-order independent:
  - If other entries arrive first, `index.pkl` replaces their directory mapping.
  - If `index.pkl` arrives first, later descendants are ignored.
- Duplicate leaves and file/directory collisions reject the incoming entry and preserve the original tree.
- Schema files and index-schema files are excluded from projected entries.
- Files under `.bark/` are excluded from the user entry tree.
- Pkl forbids recursive type aliases, so `ENode` uses `Mapping<String, Any>` and the entry-tree functions maintain the recursive invariant.

## Directory validation

- `DirectoryShape.pkl` contains reusable graph traversal and validation logic.
- It has no knowledge of `pwd`, `read?`, import globs, or the repository layout.
- Callers provide a `(Path) -> Boolean` existence predicate.
- The Pkl command adapts this API with a filesystem `read?` check.
- A future custom CLI can provide a stricter native filesystem implementation without changing graph traversal.
- User-facing missing-directory failures are created through `Errors.missingRequiredDirectories`, with optional contextual information.

## Projection code generation

- The graph does not control entry-tree insertion or index collapse.
- During rendering, it is consulted to choose syntax:
  - `DirNode` and loose directory children become properties.
  - `TableNode` and `CollectionNode` children become mapping elements.
- Indexed entries render as direct imports.
- Declared object properties are amended with readable nested blocks.
- Generated source intentionally favors readable Pkl over compact output.

## Paths and command interfaces

- Both generators are Pkl commands with `--output` and `--path-prefix` options.
- Projection imports are rendered as `PATH_PREFIX + entry.localPath`.
- Schema import prefixes apply to graph-declared user schemas; Bark's internal `Generic.pkl` import remains relative.
- Generated files include a do-not-edit comment and the effective generator arguments.
- Commands are currently designed to run from `repo/` with `--module-path .`.
- `ROOT_PATH` and the static `import*` glob in `scripts/project.pkl` describe the same boundary and must remain coupled.
- The shell wrapper supports overriding the Pkl executable through `PKL`.

## Pkl behavior that affected the design

- Mapping-typed properties can default to empty mappings. Schema evaluation alone therefore cannot distinguish an omitted directory from an existing empty directory.
- That is why filesystem shape validation and tree seeding happen before rendering.
- `open class` permits extension through subclasses; it does not make arbitrary properties valid on a base-class object literal by itself.
- Pkl commands cannot orchestrate other processes, so the multi-step generate-and-evaluate workflow uses a small POSIX shell script.

## Current generated artifacts

The wrapper writes:

```text
repo/.bark/core/generated/ProjectionSchema.pkl
repo/.bark/core/generated/projection.pkl
```

These are generated artifacts. The source of truth is the graph, the user files, and the generator implementation.

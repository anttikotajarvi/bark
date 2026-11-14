# Bark implementation notes (temporary)

This is a working decision log, not polished user documentation. It records the small semantic choices and emergent behavior discovered while building the current projection pipeline.

## Repository layout

```text
core/        the bark package, consumed as `@bark/...`; its own PklProject
core/template/   the default layout of a data repo, written by init
core/init.pkl    initializer (see Initialization)
example/     a data repo that depends on ../core; the playground
tests/       one self-contained project per case, see Tests
.dev/        shell wrappers: full-project, test
.github/     release workflow
```

The core is a Pkl package, and its source lives here as a local project dependency (`["bark"] = import("../core/PklProject")`). Everything inside the core refers to its own files with relative imports, which resolve inside the package.

## Current pipeline

1. Read the graph from `.bark/registry.pkl`, through the context.
2. Render `ProjectionSchema.pkl` from the graph.
3. Collect static graph paths and expand observed collection children.
4. Check which required directories are missing and record those findings in projection metadata.
5. Seed an entry tree with the declared directories, including empty ones.
6. Add imported user entries and collapse directories containing `index.pkl`.
7. Render `projection.pkl`, using the graph to distinguish properties from mapping elements.
8. Evaluate `projection.pkl` against `ProjectionSchema.pkl`.
9. Run postprocess coherence checks and produce the final projection, metadata, and result envelope.

From the repository root, the whole flow on the example data repo is:

```sh
./.dev/full-project            # runs on example/
./.dev/full-project path/to/repo
```

The wrapper runs the four stubs in `.bark/scripts/` in order (`render-schema`, `preprocess`, `project`, `postprocess`), evaluating the generated metadata and projection in between. Artifacts land in `.bark/output/`. The wrapper exits 0 even when postprocess withholds its artifact because of validation errors, in which case it prints the result and writes no `postprocess-output.pcf`.

## Tests

```sh
./.dev/test            # all cases
./.dev/test basic
```

Each case under `tests/<case>/` is its own bark project:

```text
tests/<case>/repo/      the case's registry, schemas and data files
tests/<case>/test.pkl   pkl:test assertions, outside repo/ so the import glob never sees it
tests/_template/PklProject   dependency on the local core, used instead of the default PklProject
```

The runner builds `tests/.work/<case>/repo` (gitignored) from `core/template`, the template `PklProject` and the case's `repo/`, runs the full pipeline there, and runs `test.pkl` with the exit code and the captured output as `-p bark.test*` properties. The cases therefore exercise the shipped stubs, not copies.

## Data repo layout

```text
PklProject                 depends on bark, sets the module path to "."
.bark/context.pkl          glob, graph, readFile and config for this repo
.bark/registry.pkl         the graph
.bark/schemas/             schemas the graph refers to (paths are relative to .bark/)
.bark/scripts/*.pkl        entry stubs: preprocess, render-schema, project, postprocess
.bark/output/              generated artifacts (gitignored)
```

`registry.pkl` sits at the root of `.bark/`; schema paths in the graph are relative to it. `.bark/` is bark-managed content inside the data repo root and is never projected.

## Context and config

`Context` is what the entry points need from a data repo: `graph`, `imports`, `readFile` and a nested `config`. Any module that amends `Context` can be passed to an entry point; `.bark/context.pkl` is just the usual place to define one.

- `imports` holds the Pkl files bark may see, with keys relative to the data repo root. The glob lives in `.bark/context.pkl` because globs and `read` resolve relative to the file that contains them. Build it with `rooted(import*("../**.pkl"), "../")`, which strips the glob's prefix; `without(imports, dirs)` drops directories. Values stay lazy.
- `readFile` reads a path relative to the data repo root and returns null if it does not exist.
- `config` (`Config.pkl`) holds settings with defaults, overridden in a `config { ... }` block:
  - `assumedOutputDir` (default `.bark/output`) is where generated files are assumed to be. Bark does not write them there itself; the invoker places them. The setting exists so the imports written into generated files line up.
  - `coreRoot` is the prefix generated source uses for core modules. It defaults to where the core was loaded from (pinning the exact version); this repo sets `@bark/`. An override that does not resolve only fails when a generated file is evaluated.
  - `omittedFilenames` lists file names left out of the projection.
  - `importPathFromOutput(target)` turns a repo-relative path into the import string a file in `assumedOutputDir` needs; shared leading directories cancel out (`.bark/schemas/A.pkl` from `.bark/output` is `../schemas/A.pkl`).

## Entry points

Each stub in `.bark/scripts/` extends a core script and supplies its inputs:

- `preprocess`, `render-schema` and `project` take `ctx` (a `Context`).
- `project` also takes `metadata`, the evaluated `projection-meta.pkl` that preprocess wrote, as an `import()` of `../output/projection-meta.pkl`.
- `postprocess` takes no `ctx`. It takes `metadata` and `projection`, imported from `../output/`.

The import paths in the stubs must agree with `config.assumedOutputDir`; `import()` needs a literal, so they cannot be derived. The stubs are plumbing and not meant to be edited. How the data reaches a stage is the caller's choice; the core only declares the slots.

Preprocess writes its findings as generated Pkl (`projection-meta.pkl`) rather than computing them again later. The findings, including the filesystem reads behind them, are frozen as data, and errors travel as values and not as Pkl failures.

## Initialization

`core/init.pkl` writes the default layout into the working directory: every file under `core/template/` plus a generated `PklProject`. A file that already exists is skipped and reported; to reset a file, delete it and run init again. There is no force flag.

```sh
pkl run package://github.com/anttikotajarvi/bark/releases/download/v0.1.0/bark-core@0.1.0#/init.pkl
pkl project resolve
```

- `PklProject` is generated in code, not templated: init imports the core's own `PklProject` and reads `package.uri`, so the dependency always names the version init came from. The dependency alias is `bark`, which the template stubs assume.
- The template is static and versioned with the package. Init globs `template/**`, drops directory entries, and maps each path to its target.
- Existence checks read `file://$PWD/...` while Pkl writes relative to the real working directory. Callers must keep `PWD` correct; a spawned process that sets only its working directory can make init skip a file that is missing.
- An existing `PklProject` is skipped without telling the user what dependency to add.

## Packaging and release

`core/PklProject` is the package definition. A `v*` tag runs `.github/workflows/release.yml`, which checks that the tag matches `package.version`, runs `pkl project package core`, and publishes the zip and metadata as release assets. `baseUri` is built so that `package://github.com/...` resolves to those asset URLs.

## Failure policy

The guiding rule is: generate Pkl whenever the observed state can be represented, then let Pkl validate its meaning. Generated source may therefore be syntactically valid while deliberately failing the generated schema.

Failures fall into three categories:

- **Deferred Pkl validation.** Missing indexes, wrong collection entry types, invalid imported values, and schema mismatches are represented in `projection.pkl` and rejected when it is evaluated against `ProjectionSchema.pkl`.
- **Bark validation errors.** Missing required directories, manifest sidecar mismatches, missing manifest targets, and duplicate manifest ids are collected under `metadata.preprocessErrors`. Postprocess coherence checks summarize them and add their own findings to `result.errors` without throwing a Pkl error. The aggregate preprocessing error repeats the human-readable detail messages so result-only terminal output remains useful.
- **Natural Pkl failures.** Malformed Pkl, invalid imports or amendments, registry/schema evaluation failures, unknown graph/tree nodes, and missing Bark renderer dependencies fail at their normal evaluation point with the complete Pkl diagnostic.

The postprocess artifact has three top-level values: `projection`, `metadata`, and `result`. An empty `result.errors` is the canonical successful result. When errors are present, postprocess returns the structured result but does not write the requested artifact unless `--force` is set. Forced output retains every error; force changes publication policy, not validity. Suppressing a write does not delete an artifact already present at the requested path, so procedure composition must use a fresh or staged destination.

An unresolved `IndexNode` demonstrates the deferred approach. Its seeded mapping is rendered as:

```pkl
new Dynamic {}
```

This is an intentional placeholder: it keeps the generated Pkl valid as source while guaranteeing that evaluation fails against the indexed schema type.

Directory-shape detection is deliberately hoisted. Seeding alone cannot preserve whether a path existed: a missing `products/` and an existing empty `products/` would both become `{}`. Mapping defaults can then make both appear valid. Static children below an index boundary also disappear from projection and cannot be checked by the generated schema. Filesystem existence is therefore checked before those paths are seeded, while the resulting validation errors are carried in metadata for postprocess.

In this context, an **invalid directory shape** means a missing graph-required filesystem path, including static descendants beneath observed collection entries. It does not mean an empty index, a wrong entry type, or another state that can be represented and deferred to Pkl validation.

## Graph semantics

- The graph is additive. It declares the minimum structure known to exist in the projection; it does not describe everything that is allowed to exist.
- Statically declared paths must exist as directories in the filesystem.
- A declared directory may be empty and must still appear in the projection.
- A missing declared directory is recorded as a preprocessing error before projection code is generated.
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

If `products/` itself is missing, metadata contains the shared missing-directory error and the final result contains one aggregate `PREPROCESS_FAILED` error.

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
- Files under `.bark/` are never projected or scanned for manifests.
- Files named in `config.omittedFilenames` (by default `schema.pkl` and `index-schema.pkl`) are left out of projected entries, in any directory.
- Which files bark can see at all is decided in `.bark/context.pkl` (see Context and config).
- Pkl forbids recursive type aliases, so `ENode` uses `Mapping<String, Any>` and the entry-tree functions maintain the recursive invariant.

## Directory validation

- `DirectoryShape.pkl` contains reusable graph traversal and validation logic.
- It has no knowledge of `pwd`, `read?`, import globs, or the repository layout.
- Callers provide a `(Path) -> Boolean` existence predicate.
- The Pkl command adapts this API with a filesystem `read?` check.
- Collection expansion uses a caller-provided directory-children function, keeping filesystem enumeration outside the reusable validator.
- The Pkl-only adapter reads names from directory resources and is less strict about distinguishing files from directories; a native CLI can provide true directory-only children through the same API.
- A future custom CLI can provide a stricter native filesystem implementation without changing graph traversal.
- User-facing missing-directory errors are created through `Errors.missingRequiredDirectories`, with optional contextual information, and carried as data rather than thrown.

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

- The four generators are Pkl commands with an `--output` option; the entry stubs supply their inputs.
- Generated files include a do-not-edit comment, the effective arguments, and a note that their imports are relative to the assumed output directory and not portable.
- Imports of user files in `projection.pkl` and of schemas in `ProjectionSchema.pkl` are computed with `config.importPathFromOutput`, so they resolve from `assumedOutputDir`. `projection.pkl` extends the sibling `ProjectionSchema.pkl`, so both must be written to the same directory under those names.
- Generated references to the core (`Generic.pkl`, `PreprocessData.pkl`, `Errors.pkl`) use `config.coreImport`, i.e. `coreRoot` plus a path inside the package.
- Commands run from the data repo root, where the `PklProject` is. They need the project for `@bark` to resolve; there is no `--module-path` requirement beyond the project's `modulePath = "."`, which data files use for `modulepath:/.bark/schemas/...` amends.
- Schemas are deduplicated by the resource they resolve to, read through `ctx.readFile` at `.bark/<schema path>`. A missing schema file therefore fails when the schema is rendered, not when the generated file is evaluated.
- Pkl commands cannot orchestrate other processes, so the multi-step generate-and-evaluate workflow uses a small POSIX shell script. It accepts a different Pkl executable through `PKL`.

## Pkl behavior that affected the design

- Mapping-typed properties can default to empty mappings. Schema evaluation alone therefore cannot distinguish an omitted directory from an existing empty directory.
- That is why filesystem shape validation and tree seeding happen before rendering.
- Empty collection entries are interpreted by their entry-node type: an empty table may be valid, while an empty index fails validation.
- `open class` permits extension through subclasses; it does not make arbitrary properties valid on a base-class object literal by itself.
- Pkl commands cannot orchestrate other processes, so the multi-step generate-and-evaluate workflow uses a small POSIX shell script.
- `import*` loads every matched module. A module whose type annotations import something unresolvable fails to load, and that fails the whole glob; an ordinary failing value (`x = throw(...)`) stays lazy. A stray unloadable Pkl file in a data repo therefore breaks every stage.
- A module that amends another cannot declare a typed property. Input slots (`ctx`, the postprocess slots) are therefore declared in the template module (`PreprocessData`, `PostprocessData`) and marked `hidden`, so they never render.
- A property holding a function has to be called with `.apply(...)`; `readFile(x)` does not resolve.
- An `import()` expression is lazy. Postprocess relies on this to avoid reading the projection when preprocessing already failed, and keeps its `projection` slot typed `Any` so assigning it does not load the module.
- By default `pkl project package` excludes every dotfile and every file named `PklProject`, at any depth. `core/PklProject` overrides `exclude` so `template/.bark/.gitignore` ships. An `exclude { ... }` block would add to the defaults; the override uses `exclude = new Listing { ... }`.
- Pkl caches packages by URI. Changing a published version's contents without bumping the version leaves consumers with the cached copy.

## Current generated artifacts

The wrapper writes, under `.bark/output/`:

```text
ProjectionSchema.pkl
projection.pkl
projection-meta.pkl
postprocess-output.pcf     only when postprocess reports no errors (or with --force)
```

These are generated artifacts. The source of truth is the graph, the user files, and the generator implementation.

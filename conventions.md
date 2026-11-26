# Module conventions

Every Pkl module in core is exactly one of three kinds.

**Template**: a module that is meant to be amended, where the amending file's layout *is* the value (Context, Config, RegistryDeclaration, Manifest, PreprocessData).
- It declares properties, plus functions over them that the amender uses (`Context.rooted`, `Config.coreImport`).
- It declares no class or typealias. The types it needs come from a library.
- Use one when a whole file is the value a user (or a generator) writes. Large state such as Config fits here; otherwise prefer a class.

**Library**: a module that is never amended (GraphModel, Errors, `sys/extensions/Initializers`, `sys/io/*`).
- It declares classes, typealiases, functions and constant values.
- Other modules import it. Users reach the parts meant for them through `Meta`.

**Command**: an entry point in `scripts/` that `extends "pkl:Command"`. It may declare its own `Options` and output classes.

## Naming
- The module clause follows the path: `module bark.<dirs>.<Stem>`, e.g. `core/sys/io/Writer.pkl` → `bark.sys.io.Writer`.
- Templates and libraries use PascalCase file names. Commands, and files that amend a template (instances such as `preprocess-data.pkl`), use kebab-case.
- Import as the file stem, always explicit: `import "../GraphModel.pkl" as GraphModel`. No short aliases (`Sys`, `GM`, `G`, `Init`).

## Status
So far applied to `sys/extensions` and `sys/io`. The rest of core is migrated when it is next touched.

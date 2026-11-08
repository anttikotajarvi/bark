```typescript
type AnyNode =
  | ContainerNode
  | FileEntriesNode
  | DirEntriesNode
  | IndexNode

// Required directory.
// Projects declared child nodes structurally.
type ContainerNode = {
  type: "container"
  nodes: Mapping<String, AnyNode>
}

// Owns ordinary *.pkl entries in this directory.
// Projects mapping: file stem -> file value.
type FileEntriesNode = {
  type: "file-entries"
  schema: Schema
}

// Owns child directories in this directory.
// Projects mapping: directory name -> entry node value.
type DirEntriesNode = {
  type: "dir-entries"
  entryNode: AnyNode
}

// Owns index.pkl in this directory.
// Projects only index.pkl.
// Child nodes are validation/storage-only unless imported/referenced by index.pkl.
type IndexNode = {
  type: "index"
  schema: Schema
  nodes: Mapping<String, AnyNode>
}
```

#### File tree
```
company/
  index-schema.pkl
  index.pkl:
    company-name = "Bark LLC"
  logs/
    schema.pkl
    log1.pkl
    log.pkl
products/
  schema.pkl
  P1.pkl
  P2.pkl
lots/
  L1/
    index-schema.pkl
    index.pkl
  L2/
    index-schema.pkl
    index.pkl
archive/
  old-products/
    schema.pkl
  test-products/
    schema.pkl

random-dir/
  index.pkl: 
    import "random-note.pkl"
  random-note.pkl:
    greeting = "Hello"
  unindexed-note.pkl:
    greeting = "Goodbye!"
random-dir2/
  note.pkl:
    todo = "Send email!"
```
#### Graph declaration
```pkl
amends "@bark/meta/RegistryDeclaration.pkl"

schemas {
  Company = schema("schemas/Company.pkl")
  Product = schema("schemas/Product.pkl")
  Lot = schema("schemas/Lot.pkl")
  Log = schema("schemas/Log.pkl")
}

graph = Graph {
  ["company"] = Index(schemas.Company, new Children {
    ["logs"] = Table(schemas.Log)
  })

  ["products"] = Table(schemas.Product)

  ["lots"] = Collection(
    IndexNode(schemas.Lot)
  )
  ["archive"] = Dir(new Children {
    ["old-products] = Table(schemas.Product)
    ["test-products] = Table(schemas.Product)
  })
}
```
#### Graph in program memory 
```pkl
{
  company: {
    type: "index"
    schema: "Company"
    nodes: {
      logs: {
        type: "file-entries",
        schema: "Log"
      } 
    }
  },
  products: {
    type: "file-entries"
    schema: "Product"
  }
  lots: {
    type: "dir-entries",
    entryNode: {
      type: "index",
      schema: "Lot"
    }  
  }
}
```

#### Type render output
```pkl
open module ProjectionSchema

import ".bark/bundle/schemas/Company.pkl" as Company
import ".bark/bundle/schemas/Product.pkl" as Product
import ".bark/bundle/schemas/Lot.pkl" as Lot

// These would be imported from somewhere
typealias PosixFileName = String 
typealias PosixDirName = String

company: Company
products: Mapping<PosixFileName, Product>
lots: Mapping<PosixDirName, Lot>

```
#### Projection output
```pkl
{
  company {
    ["company-name"] = "Bark LLC"
    // Here the logs wouldnt automatically be included as an array but the index actually works as a "filter".
  }

  products {
    P1 = import("products/P1.pkl")
    P2 = import("products/P2.pkl")
  }

  lots {
    L1 = import("lots/L1/index.pkl")
    L2 = import("lots/L2/index.pkl")
  }

  random-dir {
    greeting = "Hello"
  }

  random-dir2 {
    note {
      todo = "Send email!"
    }
  }
}
```
/*
Declared nodes create strict validated regions; 
 index.pkl creates projection boundaries; 
 undeclared loose .pkl files are still projected structurally unless an index.pkl appears above them.
*/
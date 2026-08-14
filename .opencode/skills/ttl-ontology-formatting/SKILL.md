---
name: ttl-ontology-formatting
description: Use when editing or creating semantic ontology Turtle files under semantic/ontology, especially *.ttl files, to preserve readable prefixes, shorthand, declaration grouping, and validation.
---

# Turtle Ontology Formatting

Use this style for every edit to `semantic/ontology/**/*.ttl`.

## Syntax

- Keep the file as Turtle, not TriG. Do not add graph-wrapper braces around the document.
- Keep the existing `@prefix` declarations at the top of the file.
- Use the Turtle `a` shorthand for `rdf:type`; do not expand it to the full RDF type IRI.
- Use prefixed names such as `sf:Operation`, `sfcore:mass_spec`, and `skos:prefLabel` instead of full IRIs when a prefix exists.
- End declarations with `.` and use `;` for continued predicates.
- Use commas only for compact lists of objects with the same predicate.

## Layout

- Put one named resource per block.
- Indent predicates four spaces from the subject and continued objects eight spaces.
- Put long predicate lists on separate lines.
- Keep labels and definitions adjacent to the resource type.
- Keep `skos:inScheme sfcore:scheme` on catalogue concepts that belong to the shared scheme.
- Keep domain declarations in `semantic/ontology/domains/<domain>/` and generic declarations in `semantic/ontology/core/`.
- Keep table columns and result properties explicit; do not hide schemas in comments or implementation code.

Example:

```turtle
sfcore:example
    a sf:Operation ;
    skos:inScheme sfcore:scheme ;
    sf:operationId "example" ;
    skos:prefLabel "Example operation" ;
    skos:definition "A concise description of the operation." ;
    sf:returns sfcore:exampleResult ;
    sf:mutatesProject false .
```

## Validation

After ontology edits, run from the repository root:

```powershell
& ".venv\Scripts\python.exe" semantic\validate_semantic.py
& ".venv\Scripts\python.exe" semantic\generate_projection.py --check
```

If the projection is intentionally changed, regenerate it first:

```powershell
& ".venv\Scripts\python.exe" semantic\generate_projection.py
```

Do not use a formatter that expands `a` or prefixes into full IRIs. If a formatter rewrites those forms, restore the compact Turtle spelling and rely on semantic validation for correctness.

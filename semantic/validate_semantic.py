from pathlib import Path

from pyshacl import validate
import json

from rdflib import Dataset, Graph, Namespace, RDF


ROOT = Path(__file__).parent
SF = Namespace("https://streamfind.dev/vocabulary#")

vocabulary = Graph()
vocabulary.parse(ROOT / "ontology" / "vocabulary.ttl", format="turtle")

catalogue = Dataset()
for core_path in sorted((ROOT / "ontology" / "core").glob("*.ttl")):
    catalogue.parse(core_path, format="turtle")
for domain_path in sorted((ROOT / "ontology" / "domains").rglob("*.ttl")):
    catalogue.parse(domain_path, format="turtle")

shapes = Dataset()
shapes.parse(ROOT / "ontology" / "shapes.ttl", format="turtle")

conforms, _, report = validate(
    catalogue,
    shacl_graph=shapes,
    ont_graph=vocabulary,
    inference="rdfs",
    advanced=True,
)
if not conforms:
    raise SystemExit(report)

fixtures = ROOT.parent / "tests" / "fixtures"
expected = json.loads((fixtures / "semantic" / "operations.json").read_text())["canonical_ids"]
declared = sorted(
    str(value)
    for graph in catalogue.graphs()
    for subject, value in graph.subject_objects(SF.operationId)
    if str(value) != "connect"
)
if declared != sorted(expected):
    raise SystemExit(f"catalogue operation IDs do not match fixture: {declared}")

projection = json.loads((ROOT / "generated" / "catalogue.json").read_text())
ids = [entry["canonical_id"] for entry in projection["entries"]]
if len(ids) != len(set(ids)):
    raise SystemExit("duplicate canonical IDs in semantic projection")
for entry in projection["entries"]:
    if entry["kind"] == "method" and (
        "." not in entry["canonical_id"] or not entry["canonical_id"].startswith(entry["domain"] + ".")
    ):
        raise SystemExit(f"unqualified domain method ID: {entry['canonical_id']}")


manifest_path = fixtures / "semantic" / "manifest.json"
manifest = json.loads(manifest_path.read_text())
for fixture in manifest["fixtures"]:
    path = (manifest_path.parent / fixture["path"]).resolve()
    if not path.exists():
        raise SystemExit(f"missing fixture reference: {fixture['path']}")

cpp_source = "\n".join(path.read_text() for path in [ROOT.parent / "core" / "src" / "api.cpp", ROOT.parent / "core" / "domains" / "mass_spec" / "src" / "register.cpp"])
rust_source = "\n".join(path.read_text() for path in [ROOT.parent / "rust" / "crates" / "core" / "src" / "api.rs", ROOT.parent / "rust" / "crates" / "mass-spec" / "src" / "lib.rs"])
for source_name, source in (("C++", cpp_source), ("Rust", rust_source)):
    missing = [identifier for identifier in expected if identifier not in source]
    if missing:
        raise SystemExit(f"{source_name} backend is missing catalogue operation IDs: {missing}")

print("RDF/TriG and SHACL validation passed")

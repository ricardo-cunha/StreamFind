from pathlib import Path

from pyshacl import validate
import json

from rdflib import Dataset, Graph, Namespace, RDF


ROOT = Path(__file__).parent
SF = Namespace("https://streamfind.dev/vocabulary#")

vocabulary = Graph()
vocabulary.parse(ROOT / "vocabulary.ttl", format="turtle")

catalogue = Dataset()
catalogue.parse(ROOT / "streamfind.trig", format="trig")
for domain_path in sorted((ROOT / "domains").glob("*.trig")):
    catalogue.parse(domain_path, format="trig")

shapes = Dataset()
shapes.parse(ROOT / "shapes.trig", format="trig")

conforms, _, report = validate(
    catalogue,
    shacl_graph=shapes,
    ont_graph=vocabulary,
    inference="rdfs",
    advanced=True,
)
if not conforms:
    raise SystemExit(report)

expected = json.loads((ROOT / "fixtures" / "operations.json").read_text())["canonical_ids"]
declared = sorted(
    str(value)
    for subject, value in catalogue.subject_objects(SF.operationId)
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


manifest = json.loads((ROOT / "fixtures" / "manifest.json").read_text())
for fixture in manifest["fixtures"]:
    path = ROOT / "fixtures" / fixture["path"] if not fixture["path"].startswith("../") else ROOT / "fixtures" / fixture["path"]
    if not path.resolve().exists():
        raise SystemExit(f"missing fixture reference: {fixture['path']}")

cpp_source = (ROOT.parent / "core" / "src" / "api.cpp").read_text()
rust_source = (ROOT.parent / "rust" / "crates" / "core" / "src" / "api.rs").read_text()
for source_name, source in (("C++", cpp_source), ("Rust", rust_source)):
    missing = [identifier for identifier in expected if identifier not in source]
    if missing:
        raise SystemExit(f"{source_name} backend is missing catalogue operation IDs: {missing}")

print("RDF/TriG and SHACL validation passed")

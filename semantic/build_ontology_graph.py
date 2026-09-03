from collections import defaultdict
from pathlib import Path
import json

from rdflib import Graph, URIRef, BNode, Namespace

ROOT = Path(__file__).parent / "ontology"
OUTPUT = Path(__file__).parents[1] / "slides" / "iuta_seminar_assets" / "iuta_seminar_ontology_graph.json"
OUTPUT_JS = Path(__file__).parents[1] / "slides" / "iuta_seminar_assets" / "iuta_seminar_ontology_graph.js"
SKOS = Namespace("http://www.w3.org/2004/02/skos/core#")


def group_for(path: Path) -> str:
    rel = path.relative_to(ROOT).as_posix()
    if rel.startswith("core/"):
        return "core"
    if rel.startswith("domains/mass_spec/"):
        return "mass_spec"
    if rel.startswith("domains/raman/"):
        return "raman"
    if rel.startswith("domains/sensors/"):
        return "sensors"
    if rel == "shapes.ttl":
        return "shapes"
    return "vocabulary"


def label_for(term: URIRef | BNode) -> str:
    value = str(term)
    if isinstance(term, BNode):
        return f"_: {value}".replace(" ", "")
    return value.rstrip("#/").rsplit("#", 1)[-1].rsplit("/", 1)[-1]


def main() -> None:
    graph = Graph()
    files = sorted(ROOT.rglob("*.ttl"))
    groups = {}
    for path in files:
        source_graph = Graph()
        source_graph.parse(path, format="turtle")
        graph += source_graph
        group = group_for(path)
        for subject, _, obj in source_graph:
            for term in (subject, obj):
                if isinstance(term, URIRef) and str(term).startswith("https://streamfind.dev/"):
                    groups.setdefault(str(term), group)

    node_edges = defaultdict(int)
    edges = {}
    for subject, predicate, obj in graph:
        if not isinstance(subject, URIRef) or not isinstance(obj, URIRef):
            continue
        source = str(subject)
        target = str(obj)
        groups.setdefault(source, "vocabulary")
        groups.setdefault(target, "vocabulary")
        key = (source, target, str(predicate))
        edges[key] = {
            "source": source,
            "target": target,
            "label": label_for(predicate),
        }
        node_edges[source] += 1
        node_edges[target] += 1

    nodes = [
        {
            "id": node_id,
            "label": label_for(URIRef(node_id)) if not node_id.startswith("N") else node_id,
            "group": groups.get(node_id, "vocabulary"),
            "degree": node_edges.get(node_id, 0),
            "prefLabel": str(graph.value(URIRef(node_id), SKOS.prefLabel) or ""),
            "definition": str(graph.value(URIRef(node_id), SKOS.definition) or ""),
        }
        for node_id in sorted(groups)
    ]
    payload = {
        "source_files": [p.relative_to(ROOT).as_posix() for p in files],
        "nodes": nodes,
        "links": sorted(edges.values(), key=lambda item: (item["source"], item["target"], item["label"])),
    }
    OUTPUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    OUTPUT_JS.write_text("window.streamfindOntologyGraph = " + json.dumps(payload, separators=(",", ":")) + ";\n", encoding="utf-8")
    print(f"files={len(files)} nodes={len(nodes)} links={len(payload['links'])} output={OUTPUT}")


if __name__ == "__main__":
    main()

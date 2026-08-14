import argparse
import json
import re
from pathlib import Path

from rdflib import Dataset, Namespace, RDF


ROOT = Path(__file__).parent
SF = Namespace("https://streamfind.dev/vocabulary#")
SKOS = Namespace("http://www.w3.org/2004/02/skos/core#")


def wire_name(value):
    return re.sub(r"(?<!^)([A-Z])", r"_\1", value).lower()


def projection():
    graph = Dataset()
    for path in sorted((ROOT / "ontology" / "core").glob("*.ttl")):
        graph.parse(path, format="turtle")
    for path in sorted((ROOT / "ontology" / "domains").rglob("*.ttl")):
        graph.parse(path, format="turtle")
    parameters = {
        parameter: {
            "name": wire_name(str(parameter).rsplit("#", 1)[-1]),
            "type": str(graph.value(parameter, SF.type)),
            "required": graph.value(parameter, SF.required).toPython(),
            "constraints": graph.value(parameter, SF.constraints).toPython() if graph.value(parameter, SF.constraints) else {},
            "items": str(graph.value(parameter, SF.items)).rsplit("#", 1)[-1] if graph.value(parameter, SF.items) else None,
            "extensions": str(graph.value(parameter, SF.extensions)).split(",") if graph.value(parameter, SF.extensions) else [],
        }
        for parameter in graph.subjects(RDF.type, SF.Parameter)
    }
    def result_schema(result):
        if result is None:
            return {"type": "object"}
        schema = {"type": str(graph.value(result, SF.resultType))}
        item = graph.value(result, SF.items)
        if item:
            schema["items"] = result_schema(item)
        properties = {}
        for prop in graph.objects(result, SF.hasResultProperty):
            properties[str(graph.value(prop, SF.columnName))] = {"type": str(graph.value(prop, SF.type))}
        if properties:
            schema["properties"] = properties
        return schema
    entries = []
    subjects = set(graph.subjects(SF.operationId, None)) | set(graph.subjects(SF.methodId, None))
    for operation in subjects:
        kind = "operation"
        canonical_id = str(graph.value(operation, SF.operationId))
        domain = str(graph.value(operation, SF.availableInDomain)).rsplit("#", 1)[-1] if graph.value(operation, SF.availableInDomain) else "streamfind"
        if (method_id := graph.value(operation, SF.methodId)) is not None:
            kind = "method"
            canonical_id = str(method_id)
            domain = str(graph.value(operation, SF.availableInDomain)).rsplit("#", 1)[-1]
        values = [parameters[parameter] for parameter in graph.objects(operation, SF.hasParameter)]
        result_node = graph.value(operation, SF.returns)
        mutates = graph.value(operation, SF.mutatesProject)
        effects = {
            "mutates_project": mutates.toPython() if mutates else False,
            "reads": [str(graph.value(table, SF.tableName)) for table in graph.objects(operation, SF.reads)],
            "writes": [str(graph.value(table, SF.tableName)) for table in graph.objects(operation, SF.writes)],
        }
        entries.append({
            "kind": kind,
            "canonical_id": canonical_id,
            "domain": domain,
            "label": str(graph.value(operation, SKOS.prefLabel)),
            "definition": str(graph.value(operation, SKOS.definition)),
            "executable": True,
            "exposed": True,
            "mcp": {
                "name": str(graph.value(operation, SF.toolName)),
                "input_schema": {
                    "type": "object",
                    "properties": {value["name"]: {
                        "type": value["type"],
                        **({"items": {"type": "object", "properties": {"path": {"type": "string"}, "replicate_name": {"type": "string"}, "blank_name": {"type": "string"}}, "required": ["path"]}} if value.get("items") else {})
                    } for value in values},
                    "required": [value["name"] for value in values if value["required"]],
                },
            },
            "parameters": values,
            "result": {"id": str(result_node), "schema": result_schema(result_node)},
            "effects": effects,
        })
    entries.sort(key=lambda value: value["canonical_id"])
    return {"version": 1, "entries": entries}


def outputs(value):
    payload = json.dumps(value, indent=2) + "\n"
    tools = json.dumps([
        {
            "name": entry["mcp"]["name"],
            "description": entry["label"],
            "inputSchema": entry["mcp"]["input_schema"],
            "outputSchema": entry["result"]["schema"],
            "effects": entry["effects"],
        }
        for entry in value["entries"] if entry["kind"] == "operation" and entry["domain"] == "streamfind"
    ], indent=2) + "\n"
    return {
        ROOT / "generated" / "catalogue.json": payload,
        ROOT.parent / "core" / "include" / "streamfind" / "generated_metadata.hpp":
            "#pragma once\n\nnamespace streamfind::mcp::generated {\ninline constexpr char tools[] = R\"JSON(\n"
            + tools + ")JSON\";\n}\n",
        ROOT.parent / "rust" / "crates" / "mcp" / "src" / "generated_metadata.rs":
            "pub const TOOLS: &str = r###\"\n" + tools + "\"###;\n",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated = outputs(projection())
    stale = []
    for path, content in generated.items():
        if args.check:
            if not path.exists() or path.read_text() != content:
                stale.append(str(path.relative_to(ROOT.parent)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    if stale:
        raise SystemExit("stale generated semantic files: " + ", ".join(stale))
    print("semantic projection is up to date" if args.check else f"generated {len(projection()['entries'])} semantic entries")


if __name__ == "__main__":
    main()

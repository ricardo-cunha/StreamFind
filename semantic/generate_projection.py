import argparse
import json
import re
from decimal import Decimal
from pathlib import Path

from rdflib import Dataset, Namespace, RDF


ROOT = Path(__file__).parent
SF = Namespace("https://streamfind.dev/vocabulary#")
SKOS = Namespace("http://www.w3.org/2004/02/skos/core#")


def wire_name(value):
    return re.sub(r"(?<!^)([A-Z])", r"_\1", value).lower()


def resource_name(value):
    value = value.rsplit("#", 1)[-1]
    return value.removesuffix("Parameter")


def json_value(value):
    return float(value) if isinstance(value, Decimal) else value


def projection():
    graph = Dataset()
    for path in sorted((ROOT / "ontology" / "core").glob("*.ttl")):
        graph.parse(path, format="turtle")
    for path in sorted((ROOT / "ontology" / "domains").rglob("*.ttl")):
        graph.parse(path, format="turtle")
    def parameter_schema(parameter):
        schema = {"type": str(graph.value(parameter, SF.type))}
        example = graph.value(parameter, SF.example)
        if example:
            value = json_value(example.toPython())
            if isinstance(value, str):
                try:
                    value = json.loads(value)
                except json.JSONDecodeError:
                    pass
            schema["examples"] = [value]
        item = graph.value(parameter, SF.items)
        if item:
            schema["items"] = parameter_schema(item)
        properties = {}
        required = []
        for prop in graph.objects(parameter, SF.hasProperty):
            name = str(graph.value(prop, SF.propertyName) or graph.value(prop, SF.columnName) or wire_name(str(prop).rsplit("#", 1)[-1]))
            properties[name] = parameter_schema(prop)
            required_value = graph.value(prop, SF.required)
            if required_value and required_value.toPython():
                required.append(name)
        if properties:
            schema["properties"] = properties
            if required:
                schema["required"] = required
        return schema

    parameters = {
        parameter: {
            "name": wire_name(resource_name(str(parameter))),
            "type": str(graph.value(parameter, SF.type)),
            "required": graph.value(parameter, SF.required).toPython(),
            "constraints": graph.value(parameter, SF.constraints).toPython() if graph.value(parameter, SF.constraints) else {},
            "items": resource_name(str(graph.value(parameter, SF.items))) if graph.value(parameter, SF.items) else None,
            "extensions": str(graph.value(parameter, SF.extensions)).split(",") if graph.value(parameter, SF.extensions) else [],
            "schema": parameter_schema(parameter),
            "example": parameter_schema(parameter).get("examples", [None])[0],
        }
        for parameter in graph.subjects(RDF.type, SF.Parameter)
    }
    def result_type(result):
        return str(graph.value(result, SF.type))

    def method_metadata(method):
            required = graph.value(method, SF.requiredMethods)
            required_methods = []
            if required:
                for value in graph.items(required):
                    canonical = graph.value(value, SF.methodId) or graph.value(value, SF.operationId)
                    required_methods.append(str(canonical) if canonical else str(value))
            return {
                "cacheable": bool(graph.value(method, SF.cacheable).toPython()),
                "required_methods": required_methods,
                "single_occurrence": bool(graph.value(method, SF.singleOccurrence).toPython()),
            }

    def result_schema(result):
        if result is None:
            return {"type": "object"}
        schema = {"type": result_type(result)}
        item = graph.value(result, SF.items)
        if item:
            schema["items"] = result_schema(item)
        properties = {}
        for prop in graph.objects(result, SF.hasProperty):
            column = column_schema(prop)
            properties[str(graph.value(prop, SF.propertyName) or graph.value(prop, SF.columnName))] = (
                {"type": "array", "items": column}
                if schema["type"] == "table" else column
            )
        if properties:
            schema["properties"] = properties
        return schema

    def column_schema(column):
        schema = {"type": result_type(column)}
        item = graph.value(column, SF.items)
        if item:
            schema["items"] = column_schema(item)
        properties = {}
        for prop in graph.objects(column, SF.hasProperty):
            properties[str(graph.value(prop, SF.propertyName) or graph.value(prop, SF.columnName))] = column_schema(prop)
        if properties:
            schema["properties"] = properties
        constraint = graph.value(column, SF.constraints)
        if constraint:
            schema["enum"] = str(constraint).split("|")
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
        defaults_node = graph.value(operation, SF.defaults)
        defaults = json.loads(str(defaults_node)) if defaults_node else {}
        values = []
        for parameter in graph.objects(operation, SF.hasParameter):
            value = dict(parameters[parameter])
            value["default"] = defaults.get(value["name"])
            value["schema"] = dict(value["schema"])
            if value["default"] is not None:
                value["schema"]["default"] = value["default"]
            values.append(value)
        result_node = graph.value(operation, SF.returns)
        mutates = graph.value(operation, SF.mutatesProject)
        effects = {
            "mutates_project": mutates.toPython() if mutates else False,
            "reads": [str(graph.value(table, SF.tableName)) for table in graph.objects(operation, SF.reads)],
            "writes": [str(graph.value(table, SF.tableName)) for table in graph.objects(operation, SF.writes)],
        }
        entry = {
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
                    "properties": {value["name"]: value["schema"] for value in values},
                    "required": [value["name"] for value in values if value["required"]],
                },
            },
            "parameters": values,
            "result": {"id": str(result_node), "schema": result_schema(result_node)},
            "effects": effects,
        }
        if kind == "method":
            entry.update(method_metadata(operation))
        entries.append(entry)
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
            + tools + ")JSON\";\ninline constexpr char catalogue[] = R\"JSON(\n"
            + payload + ")JSON\";\n}\n",
        ROOT.parent / "rust" / "crates" / "mcp" / "src" / "generated_metadata.rs":
            "pub const TOOLS: &str = r###\"\n" + tools + "\"###;\npub const CATALOGUE: &str = r###\"\n" + payload + "\"###;\n",
        ROOT.parent / "rust" / "crates" / "mass-spec" / "src" / "generated_metadata.rs":
            "pub const CATALOGUE: &str = r###\"\n" + payload + "\"###;\n",
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

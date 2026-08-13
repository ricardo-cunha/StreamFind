import json
from pathlib import Path

from rdflib import Dataset, Namespace
import re


ROOT = Path(__file__).parent
SF = Namespace("https://streamfind.dev/vocabulary#")
CATALOGUE = Namespace("https://streamfind.dev/catalogue/core#")
SKOS = Namespace("http://www.w3.org/2004/02/skos/core#")

graph = Dataset()
graph.parse(ROOT / "streamfind.trig", format="trig")

parameters = {
    parameter: {
        "type": str(graph.value(parameter, SF.type)),
        "required": graph.value(parameter, SF.required).toPython(),
    }
    for parameter in graph.subjects(SF.type, None)
}

tools = []


def wire_name(value):
    return re.sub(r"(?<!^)([A-Z])", r"_\1", value).lower()


for operation in graph.subjects(SF.operationId, None):
    properties = {}
    required = []
    for parameter in graph.objects(operation, SF.hasParameter):
        metadata = parameters[parameter]
        properties[wire_name(str(parameter).rsplit("#", 1)[-1])] = {"type": metadata["type"]}
        if metadata["required"]:
            required.append(wire_name(str(parameter).rsplit("#", 1)[-1]))
    tools.append(
        {
            "name": str(graph.value(operation, SF.toolName)),
            "description": str(graph.value(operation, SKOS.prefLabel)),
            "inputSchema": {
                "type": "object",
                "properties": properties,
                "required": required,
            },
        }
    )

tools.sort(key=lambda tool: tool["name"])
payload = json.dumps(tools, indent=2) + "\n"

(ROOT.parent / "core" / "include" / "streamfind" / "mcp_metadata.hpp").write_text(
    "#pragma once\n\n"
    "namespace streamfind::mcp::generated {\n"
    "inline constexpr char tools[] = R\"JSON(\n"
    + payload
    + ")JSON\";\n}\n"
)
(ROOT.parent / "rust" / "crates" / "mcp" / "src" / "generated_metadata.rs").write_text(
    "pub const TOOLS: &str = r###\"\n" + payload + "\"###;\n"
)
print(f"generated {len(tools)} MCP tools")

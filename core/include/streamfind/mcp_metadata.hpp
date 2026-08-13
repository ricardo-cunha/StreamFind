#pragma once

namespace streamfind::mcp::generated {
inline constexpr char tools[] = R"JSON(
[
  {
    "name": "close",
    "description": "Close a project handle",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "connect",
    "description": "Connect an MCP session to a project",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "copy",
    "description": "Copy a project",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        },
        "destination_database_path": {
          "type": "string"
        },
        "destination_project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id",
        "destination_database_path",
        "destination_project_id"
      ]
    }
  },
  {
    "name": "create",
    "description": "Create a project",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        },
        "domain": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id",
        "domain"
      ]
    }
  },
  {
    "name": "delete_cache",
    "description": "Delete project cache",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "describe",
    "description": "Describe a project",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "get_audit_trail",
    "description": "Read project audit events",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "get_available_methods",
    "description": "List methods registered for a domain",
    "inputSchema": {
      "type": "object",
      "properties": {
        "domain": {
          "type": "string"
        }
      },
      "required": [
        "domain"
      ]
    }
  },
  {
    "name": "get_cache",
    "description": "Read project cache",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "get_cache_size",
    "description": "Read project cache size",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "get_domain",
    "description": "Read the project domain",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "get_metadata",
    "description": "Read project metadata",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "get_workflow",
    "description": "Read the project workflow",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "run_method",
    "description": "Append and run a workflow method",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        },
        "method": {
          "type": "string"
        },
        "parameters": {
          "type": "object"
        }
      },
      "required": [
        "database_path",
        "project_id",
        "method"
      ]
    }
  },
  {
    "name": "run_workflow",
    "description": "Run the project workflow",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "set_metadata",
    "description": "Set project metadata",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        },
        "metadata": {
          "type": "object"
        }
      },
      "required": [
        "database_path",
        "project_id",
        "metadata"
      ]
    }
  },
  {
    "name": "set_workflow",
    "description": "Set the project workflow",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        },
        "workflow": {
          "type": "object"
        }
      },
      "required": [
        "database_path",
        "project_id",
        "workflow"
      ]
    }
  },
  {
    "name": "validate",
    "description": "Validate a project",
    "inputSchema": {
      "type": "object",
      "properties": {
        "database_path": {
          "type": "string"
        },
        "project_id": {
          "type": "string"
        }
      },
      "required": [
        "database_path",
        "project_id"
      ]
    }
  },
  {
    "name": "validate_workflow",
    "description": "Validate a workflow",
    "inputSchema": {
      "type": "object",
      "properties": {
        "workflow": {
          "type": "object"
        }
      },
      "required": [
        "workflow"
      ]
    }
  }
]
)JSON";
}

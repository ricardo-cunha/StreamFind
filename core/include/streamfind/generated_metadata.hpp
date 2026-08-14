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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": true,
      "reads": [],
      "writes": []
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": false,
      "reads": [],
      "writes": []
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
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string"
        },
        "database_path": {
          "type": "string"
        },
        "domain": {
          "type": "string"
        },
        "metadata": {
          "type": "object"
        },
        "schema_version": {
          "type": "integer"
        },
        "framework_version": {
          "type": "string"
        },
        "created_at": {
          "type": "string"
        },
        "workflow": {
          "type": "object"
        },
        "tables": {
          "type": "array"
        },
        "cache_size": {
          "type": "integer"
        }
      }
    },
    "effects": {
      "mutates_project": true,
      "reads": [],
      "writes": [
        "PROJECT",
        "CACHE",
        "AUDIT_TRAIL"
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
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string"
        },
        "database_path": {
          "type": "string"
        },
        "domain": {
          "type": "string"
        },
        "metadata": {
          "type": "object"
        },
        "schema_version": {
          "type": "integer"
        },
        "framework_version": {
          "type": "string"
        },
        "created_at": {
          "type": "string"
        },
        "workflow": {
          "type": "object"
        },
        "tables": {
          "type": "array"
        },
        "cache_size": {
          "type": "integer"
        }
      }
    },
    "effects": {
      "mutates_project": true,
      "reads": [],
      "writes": [
        "PROJECT",
        "CACHE",
        "AUDIT_TRAIL"
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": true,
      "reads": [],
      "writes": [
        "CACHE",
        "AUDIT_TRAIL"
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
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string"
        },
        "database_path": {
          "type": "string"
        },
        "domain": {
          "type": "string"
        },
        "metadata": {
          "type": "object"
        },
        "schema_version": {
          "type": "integer"
        },
        "framework_version": {
          "type": "string"
        },
        "created_at": {
          "type": "string"
        },
        "workflow": {
          "type": "object"
        },
        "tables": {
          "type": "array"
        },
        "cache_size": {
          "type": "integer"
        }
      }
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "PROJECT",
        "CACHE"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "operation_type": {
            "type": "string"
          },
          "object_type": {
            "type": "string"
          },
          "details": {
            "type": "object"
          },
          "created_at": {
            "type": "string"
          }
        }
      }
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "AUDIT_TRAIL"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "array",
      "items": {
        "type": "object"
      }
    },
    "effects": {
      "mutates_project": false,
      "reads": [],
      "writes": []
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
    },
    "outputSchema": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "hash": {
            "type": "string"
          },
          "created_at": {
            "type": "string"
          },
          "size": {
            "type": "integer"
          }
        }
      }
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "CACHE"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "integer"
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "CACHE"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "string"
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "PROJECT"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "PROJECT"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "PROJECT"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": true,
      "reads": [
        "PROJECT"
      ],
      "writes": [
        "PROJECT",
        "AUDIT_TRAIL"
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": true,
      "reads": [
        "PROJECT",
        "CACHE"
      ],
      "writes": [
        "PROJECT",
        "CACHE",
        "AUDIT_TRAIL"
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": true,
      "reads": [],
      "writes": [
        "PROJECT",
        "AUDIT_TRAIL"
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
    },
    "outputSchema": {
      "type": "object"
    },
    "effects": {
      "mutates_project": true,
      "reads": [],
      "writes": [
        "PROJECT",
        "AUDIT_TRAIL"
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
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "valid": {
          "type": "boolean"
        }
      }
    },
    "effects": {
      "mutates_project": false,
      "reads": [
        "PROJECT",
        "CACHE",
        "AUDIT_TRAIL"
      ],
      "writes": []
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
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "valid": {
          "type": "boolean"
        },
        "workflow": {
          "type": "object"
        }
      }
    },
    "effects": {
      "mutates_project": false,
      "reads": [],
      "writes": []
    }
  }
]
)JSON";
}

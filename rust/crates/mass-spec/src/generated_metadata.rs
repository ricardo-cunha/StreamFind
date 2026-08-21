pub const CATALOGUE: &str = r###"
{
  "version": 1,
  "entries": [
    {
      "kind": "operation",
      "canonical_id": "add_method",
      "domain": "streamfind",
      "label": "Add a method to the project workflow",
      "definition": "Append a validated method object to the ordered project workflow.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "add_method",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "method": {
              "type": "string",
              "examples": [
                "mass_spec.get_raw_spectra"
              ]
            },
            "parameters": {
              "type": "object",
              "examples": [
                {}
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "method"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "method",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "mass_spec.get_raw_spectra"
            ]
          },
          "example": "mass_spec.get_raw_spectra",
          "default": null
        },
        {
          "name": "parameters",
          "type": "object",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "object",
            "examples": [
              {}
            ]
          },
          "example": {},
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#workflowResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "id": {
                "type": "string"
              },
              "name": {
                "type": "string"
              },
              "description": {
                "type": "string"
              },
              "domain": {
                "type": "string"
              },
              "parameters": {
                "type": "object"
              },
              "cacheable": {
                "type": "boolean"
              },
              "required_methods": {
                "type": "array",
                "items": {
                  "type": "string"
                }
              }
            }
          }
        }
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
      "kind": "operation",
      "canonical_id": "close",
      "domain": "streamfind",
      "label": "Close a project handle",
      "definition": "Close the project handle used by an operation.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "close",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "connect",
      "domain": "streamfind",
      "label": "Connect an MCP session to a project",
      "definition": "Open a project and bind its immutable domain to an MCP session.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "connect",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "copy",
      "domain": "streamfind",
      "label": "Copy a project",
      "definition": "Copy a project to another database and project identifier.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "copy",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "destination_database_path": {
              "type": "string",
              "examples": [
                "/data/copied.duckdb"
              ]
            },
            "destination_project_id": {
              "type": "string",
              "examples": [
                "copy"
              ]
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
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "destination_database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/copied.duckdb"
            ]
          },
          "example": "/data/copied.duckdb",
          "default": null
        },
        {
          "name": "destination_project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "copy"
            ]
          },
          "example": "copy",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#projectDescriptorResult",
        "schema": {
          "type": "table",
          "properties": {
            "project_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "domain": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "metadata": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "schema_version": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "framework_version": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "created_at": {
              "type": "array",
              "items": {
                "type": "timestamp"
              }
            },
            "workflow": {
              "type": "array",
              "items": {
                "type": "array",
                "items": {
                  "type": "object",
                  "properties": {
                    "id": {
                      "type": "string"
                    },
                    "name": {
                      "type": "string"
                    },
                    "description": {
                      "type": "string"
                    },
                    "domain": {
                      "type": "string"
                    },
                    "parameters": {
                      "type": "object"
                    },
                    "cacheable": {
                      "type": "boolean"
                    },
                    "required_methods": {
                      "type": "array",
                      "items": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
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
      "kind": "operation",
      "canonical_id": "create",
      "domain": "streamfind",
      "label": "Create a project",
      "definition": "Create a persisted project with an immutable domain.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "create",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "domain": {
              "type": "string",
              "examples": [
                "mass_spec"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "domain"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "domain",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "mass_spec"
            ]
          },
          "example": "mass_spec",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#projectDescriptorResult",
        "schema": {
          "type": "table",
          "properties": {
            "project_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "domain": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "metadata": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "schema_version": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "framework_version": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "created_at": {
              "type": "array",
              "items": {
                "type": "timestamp"
              }
            },
            "workflow": {
              "type": "array",
              "items": {
                "type": "array",
                "items": {
                  "type": "object",
                  "properties": {
                    "id": {
                      "type": "string"
                    },
                    "name": {
                      "type": "string"
                    },
                    "description": {
                      "type": "string"
                    },
                    "domain": {
                      "type": "string"
                    },
                    "parameters": {
                      "type": "object"
                    },
                    "cacheable": {
                      "type": "boolean"
                    },
                    "required_methods": {
                      "type": "array",
                      "items": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
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
      "kind": "operation",
      "canonical_id": "delete_cache",
      "domain": "streamfind",
      "label": "Delete project cache",
      "definition": "Delete all cache entries stored for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "delete_cache",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
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
      "kind": "operation",
      "canonical_id": "describe",
      "domain": "streamfind",
      "label": "Describe a project",
      "definition": "Read a project's identity and persisted metadata.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "describe",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#projectDescriptorResult",
        "schema": {
          "type": "table",
          "properties": {
            "project_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "domain": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "metadata": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "schema_version": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "framework_version": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "created_at": {
              "type": "array",
              "items": {
                "type": "timestamp"
              }
            },
            "workflow": {
              "type": "array",
              "items": {
                "type": "array",
                "items": {
                  "type": "object",
                  "properties": {
                    "id": {
                      "type": "string"
                    },
                    "name": {
                      "type": "string"
                    },
                    "description": {
                      "type": "string"
                    },
                    "domain": {
                      "type": "string"
                    },
                    "parameters": {
                      "type": "object"
                    },
                    "cacheable": {
                      "type": "boolean"
                    },
                    "required_methods": {
                      "type": "array",
                      "items": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
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
      "kind": "operation",
      "canonical_id": "get_audit_trail",
      "domain": "streamfind",
      "label": "Read project audit events",
      "definition": "Return audit events recorded for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_audit_trail",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#auditEntriesResult",
        "schema": {
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
              "operation_details": {
                "type": "object"
              },
              "created_at": {
                "type": "timestamp"
              }
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
      "kind": "operation",
      "canonical_id": "get_available_methods",
      "domain": "streamfind",
      "label": "List methods registered for a domain",
      "definition": "Return workflow methods registered for a domain.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_available_methods",
        "input_schema": {
          "type": "object",
          "properties": {
            "domain": {
              "type": "string",
              "examples": [
                "mass_spec"
              ]
            }
          },
          "required": [
            "domain"
          ]
        }
      },
      "parameters": [
        {
          "name": "domain",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "mass_spec"
            ]
          },
          "example": "mass_spec",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#methodsResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "object"
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "get_cache",
      "domain": "streamfind",
      "label": "Read project cache",
      "definition": "Return cache entries stored for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_cache",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#cacheEntriesResult",
        "schema": {
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
                "type": "timestamp"
              }
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
      "kind": "operation",
      "canonical_id": "get_cache_size",
      "domain": "streamfind",
      "label": "Read project cache size",
      "definition": "Return the number of cache entries stored for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_cache_size",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#cacheSizeResult",
        "schema": {
          "type": "integer"
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
      "kind": "operation",
      "canonical_id": "get_domain",
      "domain": "streamfind",
      "label": "Read the project domain",
      "definition": "Read the immutable domain assigned to a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_domain",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#domainResult",
        "schema": {
          "type": "string"
        }
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
      "kind": "operation",
      "canonical_id": "get_metadata",
      "domain": "streamfind",
      "label": "Read project metadata",
      "definition": "Return the metadata stored for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_metadata",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#metadataResult",
        "schema": {
          "type": "table",
          "properties": {
            "metadata": {
              "type": "array",
              "items": {
                "type": "string"
              }
            }
          }
        }
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
      "kind": "operation",
      "canonical_id": "get_workflow",
      "domain": "streamfind",
      "label": "Read the project workflow",
      "definition": "Return the persisted workflow for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_workflow",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#workflowResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "id": {
                "type": "string"
              },
              "name": {
                "type": "string"
              },
              "description": {
                "type": "string"
              },
              "domain": {
                "type": "string"
              },
              "parameters": {
                "type": "object"
              },
              "cacheable": {
                "type": "boolean"
              },
              "required_methods": {
                "type": "array",
                "items": {
                  "type": "string"
                }
              }
            }
          }
        }
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
      "kind": "operation",
      "canonical_id": "get_workflow_execution",
      "domain": "streamfind",
      "label": "Read workflow execution",
      "definition": "Return execution status, hashes, timestamps, errors, and cache keys for the project's workflow steps.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_workflow_execution",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#workflowExecutionEntriesResult",
        "schema": {
          "type": "table",
          "properties": {
            "project_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "workflow_revision": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "step_index": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "method": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "parameter_hash": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "status": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "started_at": {
              "type": "array",
              "items": {
                "type": "timestamp"
              }
            },
            "completed_at": {
              "type": "array",
              "items": {
                "type": "timestamp"
              }
            },
            "error": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "cache_key": {
              "type": "array",
              "items": {
                "type": "string"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "WORKFLOW_EXECUTION"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.add_analyses",
      "domain": "mass_spec",
      "label": "Add mass spectrometry analyses",
      "definition": "Read mass spectrometry files and persist their analysis metadata in the project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "add_analyses",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analyses": {
              "type": "array",
              "examples": [
                [
                  {
                    "path": "data/sample.mzML",
                    "replicate_name": "r1"
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "path": "data/sample.mzML",
                    "replicate_name": "r1"
                  }
                ],
                "properties": {
                  "path": {
                    "type": "string",
                    "examples": [
                      "data/sample.mzML"
                    ]
                  },
                  "replicate_name": {
                    "type": "string",
                    "examples": [
                      "r1"
                    ]
                  },
                  "blank_name": {
                    "type": "string",
                    "examples": [
                      "blank"
                    ]
                  }
                },
                "required": [
                  "path"
                ]
              }
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analyses"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analyses",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "analysisFile",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "path": "data/sample.mzML",
                  "replicate_name": "r1"
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "path": "data/sample.mzML",
                  "replicate_name": "r1"
                }
              ],
              "properties": {
                "path": {
                  "type": "string",
                  "examples": [
                    "data/sample.mzML"
                  ]
                },
                "replicate_name": {
                  "type": "string",
                  "examples": [
                    "r1"
                  ]
                },
                "blank_name": {
                  "type": "string",
                  "examples": [
                    "blank"
                  ]
                }
              },
              "required": [
                "path"
              ]
            }
          },
          "example": [
            {
              "path": "data/sample.mzML",
              "replicate_name": "r1"
            }
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#addAnalysesResult",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "file_path": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "replicate": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "blank": {
              "type": "array",
              "items": {
                "type": "string"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": true,
        "reads": [],
        "writes": [
          "MASS_SPEC_ANALYSES"
        ]
      }
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.annotate_components",
      "domain": "mass_spec",
      "label": "Annotate components",
      "definition": "Annotate feature components with isotopic, adduct, and fragment relationships.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "max_isotopes": {
              "type": "integer",
              "examples": [
                5
              ]
            },
            "max_charge": {
              "type": "integer",
              "examples": [
                2
              ]
            },
            "max_gaps": {
              "type": "integer",
              "examples": [
                3
              ]
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "isotope_elements": {
              "type": "array",
              "examples": [
                [
                  "C",
                  "H",
                  "N",
                  "O",
                  "S"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "max_isotopes",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              5
            ]
          },
          "example": 5,
          "default": null
        },
        {
          "name": "max_charge",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              2
            ]
          },
          "example": 2,
          "default": null
        },
        {
          "name": "max_gaps",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              3
            ]
          },
          "example": 3,
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "isotope_elements",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "C",
                "H",
                "N",
                "O",
                "S"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "C",
            "H",
            "N",
            "O",
            "S"
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.correct_matrix_suppression",
      "domain": "mass_spec",
      "label": "Correct matrix suppression",
      "definition": "Apply matrix/suppression correction factors derived from analysis intensity profiles.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "mp_rt_window": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "ref_blank_replicate": {
              "type": "string",
              "examples": [
                "blank"
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "mp_rt_window",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "ref_blank_replicate",
          "type": "string",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "blank"
            ]
          },
          "example": "blank",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.create_components",
      "domain": "mass_spec",
      "label": "Create components",
      "definition": "Join correlated features into components based on EIC correlation within a retention-time window.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "rt_window": {
              "type": "array",
              "examples": [
                [
                  0.0,
                  0.0
                ]
              ],
              "items": {
                "type": "real",
                "examples": [
                  1.0
                ]
              }
            },
            "min_correlation": {
              "type": "real",
              "examples": [
                0.8
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "rt_window",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "realItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                0.0,
                0.0
              ]
            ],
            "items": {
              "type": "real",
              "examples": [
                1.0
              ]
            }
          },
          "example": [
            0.0,
            0.0
          ],
          "default": null
        },
        {
          "name": "min_correlation",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.fill_features",
      "domain": "mass_spec",
      "label": "Fill feature gaps",
      "definition": "Fill missing feature values across analyses by extracting and integrating EIC peaks in the expected windows.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "within_replicate": {
              "type": "boolean"
            },
            "filtered": {
              "type": "boolean"
            },
            "rt_expand": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "mz_expand": {
              "type": "real",
              "examples": [
                0.005
              ]
            },
            "max_peak_width": {
              "type": "real",
              "examples": [
                30.0
              ]
            },
            "min_traces_intensity": {
              "type": "real"
            },
            "min_number_traces": {
              "type": "integer",
              "examples": [
                3
              ]
            },
            "min_intensity_ms1": {
              "type": "real",
              "examples": [
                1000.0
              ]
            },
            "rt_apex_deviation": {
              "type": "real",
              "examples": [
                1.0
              ]
            },
            "min_signal_to_noise_ratio": {
              "type": "real",
              "examples": [
                3.0
              ]
            },
            "min_gaussian_fit": {
              "type": "real",
              "examples": [
                0.8
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "within_replicate",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        },
        {
          "name": "filtered",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        },
        {
          "name": "rt_expand",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "mz_expand",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.005
            ]
          },
          "example": 0.005,
          "default": null
        },
        {
          "name": "max_peak_width",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              30.0
            ]
          },
          "example": 30.0,
          "default": null
        },
        {
          "name": "min_traces_intensity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "min_number_traces",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              3
            ]
          },
          "example": 3,
          "default": null
        },
        {
          "name": "min_intensity_ms1",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1000.0
            ]
          },
          "example": 1000.0,
          "default": null
        },
        {
          "name": "rt_apex_deviation",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1.0
            ]
          },
          "example": 1.0,
          "default": null
        },
        {
          "name": "min_signal_to_noise_ratio",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              3.0
            ]
          },
          "example": 3.0,
          "default": null
        },
        {
          "name": "min_gaussian_fit",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.filter_chromatograms_retention_time",
      "domain": "mass_spec",
      "label": "Filter chromatograms by retention time",
      "definition": "Keep chromatogram rows whose retention time is within the inclusive minimum and maximum window.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "rt_min": {
              "type": "real",
              "examples": [
                900.0
              ]
            },
            "rt_max": {
              "type": "real",
              "examples": [
                1200.0
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "rt_min",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              900.0
            ]
          },
          "example": 900.0,
          "default": null
        },
        {
          "name": "rt_max",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1200.0
            ]
          },
          "example": 1200.0,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_CHROMATOGRAMS"
        ],
        "writes": [
          "MASS_SPEC_CHROMATOGRAMS"
        ]
      },
      "cacheable": false,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.filter_features",
      "domain": "mass_spec",
      "label": "Filter features",
      "definition": "Remove or flag features failing signal, shape, and quality criteria.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "min_sn": {
              "type": "real",
              "examples": [
                3.0
              ]
            },
            "min_intensity": {
              "type": "real",
              "examples": [
                10000.0
              ]
            },
            "min_area": {
              "type": "real",
              "examples": [
                10000.0
              ]
            },
            "min_width": {
              "type": "real",
              "examples": [
                5.0
              ]
            },
            "max_width": {
              "type": "real",
              "examples": [
                100.0
              ]
            },
            "max_ppm": {
              "type": "real",
              "examples": [
                10.0
              ]
            },
            "min_fwhm_rt": {
              "type": "real",
              "examples": [
                1.0
              ]
            },
            "max_fwhm_rt": {
              "type": "real",
              "examples": [
                100.0
              ]
            },
            "min_fwhm_mz": {
              "type": "real",
              "examples": [
                0.001
              ]
            },
            "max_fwhm_mz": {
              "type": "real",
              "examples": [
                0.1
              ]
            },
            "min_gaussian_a": {
              "type": "real"
            },
            "min_gaussian_mu": {
              "type": "real"
            },
            "max_gaussian_mu": {
              "type": "real",
              "examples": [
                2000.0
              ]
            },
            "min_gaussian_sigma": {
              "type": "real"
            },
            "max_gaussian_sigma": {
              "type": "real",
              "examples": [
                100.0
              ]
            },
            "min_gaussian_r2": {
              "type": "real",
              "examples": [
                0.8
              ]
            },
            "max_jaggedness": {
              "type": "real",
              "examples": [
                100.0
              ]
            },
            "min_sharpness": {
              "type": "real"
            },
            "min_asymmetry": {
              "type": "real"
            },
            "max_asymmetry": {
              "type": "real",
              "examples": [
                100.0
              ]
            },
            "max_modality": {
              "type": "integer",
              "examples": [
                2
              ]
            },
            "min_plates": {
              "type": "real",
              "examples": [
                100.0
              ]
            },
            "only_filled": {
              "type": "boolean",
              "examples": [
                true
              ]
            },
            "remove_filled": {
              "type": "boolean"
            },
            "min_size_eic": {
              "type": "integer",
              "examples": [
                5
              ]
            },
            "min_size_ms1": {
              "type": "integer",
              "examples": [
                5
              ]
            },
            "min_size_ms2": {
              "type": "integer",
              "examples": [
                5
              ]
            },
            "min_rel_presence_replicate": {
              "type": "real",
              "examples": [
                0.8
              ]
            },
            "remove_isotopes": {
              "type": "boolean"
            },
            "remove_adducts": {
              "type": "boolean"
            },
            "remove_losses": {
              "type": "boolean"
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "min_sn",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              3.0
            ]
          },
          "example": 3.0,
          "default": null
        },
        {
          "name": "min_intensity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              10000.0
            ]
          },
          "example": 10000.0,
          "default": null
        },
        {
          "name": "min_area",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              10000.0
            ]
          },
          "example": 10000.0,
          "default": null
        },
        {
          "name": "min_width",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              5.0
            ]
          },
          "example": 5.0,
          "default": null
        },
        {
          "name": "max_width",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ]
          },
          "example": 100.0,
          "default": null
        },
        {
          "name": "max_ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              10.0
            ]
          },
          "example": 10.0,
          "default": null
        },
        {
          "name": "min_fwhm_rt",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1.0
            ]
          },
          "example": 1.0,
          "default": null
        },
        {
          "name": "max_fwhm_rt",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ]
          },
          "example": 100.0,
          "default": null
        },
        {
          "name": "min_fwhm_mz",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.001
            ]
          },
          "example": 0.001,
          "default": null
        },
        {
          "name": "max_fwhm_mz",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.1
            ]
          },
          "example": 0.1,
          "default": null
        },
        {
          "name": "min_gaussian_a",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "min_gaussian_mu",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "max_gaussian_mu",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              2000.0
            ]
          },
          "example": 2000.0,
          "default": null
        },
        {
          "name": "min_gaussian_sigma",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "max_gaussian_sigma",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ]
          },
          "example": 100.0,
          "default": null
        },
        {
          "name": "min_gaussian_r2",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        },
        {
          "name": "max_jaggedness",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ]
          },
          "example": 100.0,
          "default": null
        },
        {
          "name": "min_sharpness",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "min_asymmetry",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "max_asymmetry",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ]
          },
          "example": 100.0,
          "default": null
        },
        {
          "name": "max_modality",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              2
            ]
          },
          "example": 2,
          "default": null
        },
        {
          "name": "min_plates",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ]
          },
          "example": 100.0,
          "default": null
        },
        {
          "name": "only_filled",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean",
            "examples": [
              true
            ]
          },
          "example": true,
          "default": null
        },
        {
          "name": "remove_filled",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        },
        {
          "name": "min_size_eic",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              5
            ]
          },
          "example": 5,
          "default": null
        },
        {
          "name": "min_size_ms1",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              5
            ]
          },
          "example": 5,
          "default": null
        },
        {
          "name": "min_size_ms2",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              5
            ]
          },
          "example": 5,
          "default": null
        },
        {
          "name": "min_rel_presence_replicate",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        },
        {
          "name": "remove_isotopes",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        },
        {
          "name": "remove_adducts",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        },
        {
          "name": "remove_losses",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.filter_features_ms2",
      "domain": "mass_spec",
      "label": "Filter feature MS2 spectra",
      "definition": "Clean feature MS2 spectra: remove blank contaminants, apply relative intensity and top-N limits.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "top": {
              "type": "integer"
            },
            "min_intensity_ms2": {
              "type": "real",
              "examples": [
                100.0
              ]
            },
            "rel_min_intensity": {
              "type": "real",
              "examples": [
                0.01
              ]
            },
            "blank_clean": {
              "type": "boolean",
              "examples": [
                true
              ]
            },
            "mz_clust": {
              "type": "real",
              "examples": [
                0.003
              ]
            },
            "blank_presence_threshold": {
              "type": "real",
              "examples": [
                0.5
              ]
            },
            "global_presence_threshold": {
              "type": "real"
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "top",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer"
          },
          "example": null,
          "default": null
        },
        {
          "name": "min_intensity_ms2",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ]
          },
          "example": 100.0,
          "default": null
        },
        {
          "name": "rel_min_intensity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.01
            ]
          },
          "example": 0.01,
          "default": null
        },
        {
          "name": "blank_clean",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean",
            "examples": [
              true
            ]
          },
          "example": true,
          "default": null
        },
        {
          "name": "mz_clust",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.003
            ]
          },
          "example": 0.003,
          "default": null
        },
        {
          "name": "blank_presence_threshold",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.5
            ]
          },
          "example": 0.5,
          "default": null
        },
        {
          "name": "global_presence_threshold",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.filter_internal_standards",
      "domain": "mass_spec",
      "label": "Filter internal standards",
      "definition": "Refine internal-standard matches by applying name, score, RT/mass error, identification-level, fragment, and cosine-similarity thresholds.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "names": {
              "type": "array",
              "examples": [
                [
                  "caffeine"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "min_score": {
              "type": "real",
              "examples": [
                0.5
              ]
            },
            "max_error_rt": {
              "type": "real",
              "examples": [
                30.0
              ]
            },
            "max_error_mass": {
              "type": "real",
              "examples": [
                5.0
              ]
            },
            "id_levels": {
              "type": "array",
              "examples": [
                [
                  1,
                  2,
                  3
                ]
              ],
              "items": {
                "type": "integer",
                "examples": [
                  1
                ]
              }
            },
            "min_shared_fragments": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "min_cosine_similarity": {
              "type": "real",
              "examples": [
                0.8
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "names",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "caffeine"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "caffeine"
          ],
          "default": null
        },
        {
          "name": "min_score",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.5
            ]
          },
          "example": 0.5,
          "default": null
        },
        {
          "name": "max_error_rt",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              30.0
            ]
          },
          "example": 30.0,
          "default": null
        },
        {
          "name": "max_error_mass",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              5.0
            ]
          },
          "example": 5.0,
          "default": null
        },
        {
          "name": "id_levels",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "integerItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                1,
                2,
                3
              ]
            ],
            "items": {
              "type": "integer",
              "examples": [
                1
              ]
            }
          },
          "example": [
            1,
            2,
            3
          ],
          "default": null
        },
        {
          "name": "min_shared_fragments",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "min_cosine_similarity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.filter_suspects",
      "domain": "mass_spec",
      "label": "Filter suspects",
      "definition": "Refine suspect-screening results by applying name, score, RT/mass error, identification-level, fragment, and cosine-similarity thresholds.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "names": {
              "type": "array",
              "examples": [
                [
                  "caffeine"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "min_score": {
              "type": "real",
              "examples": [
                0.5
              ]
            },
            "max_error_rt": {
              "type": "real",
              "examples": [
                30.0
              ]
            },
            "max_error_mass": {
              "type": "real",
              "examples": [
                5.0
              ]
            },
            "id_levels": {
              "type": "array",
              "examples": [
                [
                  1,
                  2,
                  3
                ]
              ],
              "items": {
                "type": "integer",
                "examples": [
                  1
                ]
              }
            },
            "min_shared_fragments": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "min_cosine_similarity": {
              "type": "real",
              "examples": [
                0.8
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "names",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "caffeine"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "caffeine"
          ],
          "default": null
        },
        {
          "name": "min_score",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.5
            ]
          },
          "example": 0.5,
          "default": null
        },
        {
          "name": "max_error_rt",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              30.0
            ]
          },
          "example": 30.0,
          "default": null
        },
        {
          "name": "max_error_mass",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              5.0
            ]
          },
          "example": 5.0,
          "default": null
        },
        {
          "name": "id_levels",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "integerItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                1,
                2,
                3
              ]
            ],
            "items": {
              "type": "integer",
              "examples": [
                1
              ]
            }
          },
          "example": [
            1,
            2,
            3
          ],
          "default": null
        },
        {
          "name": "min_shared_fragments",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "min_cosine_similarity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.find_features",
      "domain": "mass_spec",
      "label": "Find mass spectrometry features",
      "definition": "Group MS1 centroid traces within retention-time windows and persist detected NTA features.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "rt_windows_min": {
              "type": "array",
              "examples": [
                [
                  0.0
                ]
              ],
              "items": {
                "type": "real",
                "examples": [
                  1.0
                ]
              }
            },
            "rt_windows_max": {
              "type": "array",
              "examples": [
                [
                  1800.0
                ]
              ],
              "items": {
                "type": "real",
                "examples": [
                  1.0
                ]
              }
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "ppm_threshold": {
              "type": "real",
              "examples": [
                15.0
              ]
            },
            "noise_threshold": {
              "type": "real",
              "examples": [
                15.0
              ]
            },
            "min_snr": {
              "type": "real",
              "examples": [
                3.0
              ]
            },
            "min_traces": {
              "type": "integer",
              "examples": [
                3
              ]
            },
            "baseline_window": {
              "type": "real",
              "examples": [
                30.0
              ]
            },
            "max_feature_width": {
              "type": "real",
              "examples": [
                30.0
              ]
            },
            "base_quantile": {
              "type": "real",
              "examples": [
                0.1
              ]
            }
          },
          "required": [
            "rt_windows_min",
            "rt_windows_max",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "rt_windows_min",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "realItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                0.0
              ]
            ],
            "items": {
              "type": "real",
              "examples": [
                1.0
              ]
            }
          },
          "example": [
            0.0
          ],
          "default": null
        },
        {
          "name": "rt_windows_max",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "realItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                1800.0
              ]
            ],
            "items": {
              "type": "real",
              "examples": [
                1.0
              ]
            }
          },
          "example": [
            1800.0
          ],
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "ppm_threshold",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              15.0
            ]
          },
          "example": 15.0,
          "default": null
        },
        {
          "name": "noise_threshold",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              15.0
            ]
          },
          "example": 15.0,
          "default": null
        },
        {
          "name": "min_snr",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              3.0
            ]
          },
          "example": 3.0,
          "default": null
        },
        {
          "name": "min_traces",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              3
            ]
          },
          "example": 3,
          "default": null
        },
        {
          "name": "baseline_window",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              30.0
            ]
          },
          "example": 30.0,
          "default": null
        },
        {
          "name": "max_feature_width",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              30.0
            ]
          },
          "example": 30.0,
          "default": null
        },
        {
          "name": "base_quantile",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.1
            ]
          },
          "example": 0.1,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": true
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.find_internal_standards",
      "domain": "mass_spec",
      "label": "Find internal standards",
      "definition": "Match detected features against internal-standard targets by mass, RT, and MS2 similarity.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "targets": {
              "type": "array",
              "examples": [
                [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ],
                "properties": {
                  "id": {
                    "type": "string",
                    "examples": [
                      "caffeine"
                    ]
                  },
                  "analyses": {
                    "type": "array",
                    "examples": [
                      [
                        "sample-r001",
                        "sample-r002"
                      ]
                    ],
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  },
                  "polarity": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  },
                  "levels": {
                    "type": "array",
                    "examples": [
                      [
                        1,
                        2
                      ]
                    ],
                    "items": {
                      "type": "integer",
                      "examples": [
                        1
                      ]
                    }
                  },
                  "mass": {
                    "type": "real",
                    "examples": [
                      194.0804
                    ]
                  },
                  "mass_min": {
                    "type": "real",
                    "examples": [
                      194.0
                    ]
                  },
                  "mass_max": {
                    "type": "real",
                    "examples": [
                      194.2
                    ]
                  },
                  "mz": {
                    "type": "real",
                    "examples": [
                      195.0877
                    ]
                  },
                  "mz_min": {
                    "type": "real",
                    "examples": [
                      195.0
                    ]
                  },
                  "mz_max": {
                    "type": "real",
                    "examples": [
                      195.2
                    ]
                  },
                  "rt": {
                    "type": "real",
                    "examples": [
                      1020.0
                    ]
                  },
                  "rt_min": {
                    "type": "real",
                    "examples": [
                      1000.0
                    ]
                  },
                  "rt_max": {
                    "type": "real",
                    "examples": [
                      1040.0
                    ]
                  }
                }
              }
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "sec": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "ppm_ms2": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "mzr_ms2": {
              "type": "real",
              "examples": [
                0.01
              ]
            },
            "min_cosine_similarity": {
              "type": "real",
              "examples": [
                0.8
              ]
            },
            "min_shared_fragments": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "filtered": {
              "type": "boolean"
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "targets",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "targetRange",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ],
              "properties": {
                "id": {
                  "type": "string",
                  "examples": [
                    "caffeine"
                  ]
                },
                "analyses": {
                  "type": "array",
                  "examples": [
                    [
                      "sample-r001",
                      "sample-r002"
                    ]
                  ],
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                },
                "polarity": {
                  "type": "integer",
                  "examples": [
                    1
                  ]
                },
                "levels": {
                  "type": "array",
                  "examples": [
                    [
                      1,
                      2
                    ]
                  ],
                  "items": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  }
                },
                "mass": {
                  "type": "real",
                  "examples": [
                    194.0804
                  ]
                },
                "mass_min": {
                  "type": "real",
                  "examples": [
                    194.0
                  ]
                },
                "mass_max": {
                  "type": "real",
                  "examples": [
                    194.2
                  ]
                },
                "mz": {
                  "type": "real",
                  "examples": [
                    195.0877
                  ]
                },
                "mz_min": {
                  "type": "real",
                  "examples": [
                    195.0
                  ]
                },
                "mz_max": {
                  "type": "real",
                  "examples": [
                    195.2
                  ]
                },
                "rt": {
                  "type": "real",
                  "examples": [
                    1020.0
                  ]
                },
                "rt_min": {
                  "type": "real",
                  "examples": [
                    1000.0
                  ]
                },
                "rt_max": {
                  "type": "real",
                  "examples": [
                    1040.0
                  ]
                }
              }
            }
          },
          "example": [
            {
              "id": "caffeine",
              "mass": 194.0804
            }
          ],
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "sec",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "ppm_ms2",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "mzr_ms2",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.01
            ]
          },
          "example": 0.01,
          "default": null
        },
        {
          "name": "min_cosine_similarity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        },
        {
          "name": "min_shared_fragments",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "filtered",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_analyses_info",
      "domain": "mass_spec",
      "label": "Get mass spectrometry analysis information",
      "definition": "Return persisted mass spectrometry analysis metadata from the project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_analyses_info",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#getAnalysesInfoResult",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "replicate": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "blank": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "file_path": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "format": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "number_spectra": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "number_chromatograms": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_analysis_names",
      "domain": "mass_spec",
      "label": "Get mass spectrometry analysis names",
      "definition": "Read analysis names.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_analysis_names",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#analysisNamesResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_blank_names",
      "domain": "mass_spec",
      "label": "Get blank names",
      "definition": "Read blank labels.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_blank_names",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#blankNamesResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_chromatograms",
      "domain": "mass_spec",
      "label": "Get chromatograms",
      "definition": "Read chromatogram arrays for selected analyses and indices.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_chromatograms",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            },
            "indices": {
              "type": "array",
              "examples": [
                [
                  0,
                  2
                ]
              ],
              "items": {
                "type": "integer",
                "examples": [
                  1
                ]
              },
              "default": []
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        },
        {
          "name": "indices",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "integerItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                0,
                2
              ]
            ],
            "items": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "default": []
          },
          "example": [
            0,
            2
          ],
          "default": []
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#chromatogramsResult",
        "schema": {
          "type": "table",
          "properties": {
            "project_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "chromatogram_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "raw_intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "baseline": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_CHROMATOGRAMS"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_chromatograms_headers",
      "domain": "mass_spec",
      "label": "Get chromatogram headers",
      "definition": "Read chromatogram header rows for selected analyses.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_chromatograms_headers",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#chromatogramsHeadersResult",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "index": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "chromatogram_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "array_length": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "precursor_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "activation_ce": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "product_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "signal_type": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "chromatogram_type": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "detector": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "channel": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "units": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "wavelength_nm": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "interval_ms": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "start_time": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "end_time": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity_multiplier": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_CHROMATOGRAMS_HEADERS"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_concentrations",
      "domain": "mass_spec",
      "label": "Get concentrations",
      "definition": "Read analysis concentrations.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_concentrations",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#concentrationsResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "real"
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_features",
      "domain": "mass_spec",
      "label": "Get NTA features",
      "definition": "Read persisted non-target-analysis features matching analysis, mass or m/z, retention time, and polarity targets.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_features",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            },
            "targets": {
              "type": "array",
              "examples": [
                [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ],
                "properties": {
                  "id": {
                    "type": "string",
                    "examples": [
                      "caffeine"
                    ]
                  },
                  "analyses": {
                    "type": "array",
                    "examples": [
                      [
                        "sample-r001",
                        "sample-r002"
                      ]
                    ],
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  },
                  "polarity": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  },
                  "levels": {
                    "type": "array",
                    "examples": [
                      [
                        1,
                        2
                      ]
                    ],
                    "items": {
                      "type": "integer",
                      "examples": [
                        1
                      ]
                    }
                  },
                  "mass": {
                    "type": "real",
                    "examples": [
                      194.0804
                    ]
                  },
                  "mass_min": {
                    "type": "real",
                    "examples": [
                      194.0
                    ]
                  },
                  "mass_max": {
                    "type": "real",
                    "examples": [
                      194.2
                    ]
                  },
                  "mz": {
                    "type": "real",
                    "examples": [
                      195.0877
                    ]
                  },
                  "mz_min": {
                    "type": "real",
                    "examples": [
                      195.0
                    ]
                  },
                  "mz_max": {
                    "type": "real",
                    "examples": [
                      195.2
                    ]
                  },
                  "rt": {
                    "type": "real",
                    "examples": [
                      1020.0
                    ]
                  },
                  "rt_min": {
                    "type": "real",
                    "examples": [
                      1000.0
                    ]
                  },
                  "rt_max": {
                    "type": "real",
                    "examples": [
                      1040.0
                    ]
                  }
                }
              }
            },
            "polarity": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ],
              "default": 20.0
            },
            "rt_tolerance": {
              "type": "real",
              "examples": [
                60.0
              ],
              "default": 60.0
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        },
        {
          "name": "targets",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "targetRange",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ],
              "properties": {
                "id": {
                  "type": "string",
                  "examples": [
                    "caffeine"
                  ]
                },
                "analyses": {
                  "type": "array",
                  "examples": [
                    [
                      "sample-r001",
                      "sample-r002"
                    ]
                  ],
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                },
                "polarity": {
                  "type": "integer",
                  "examples": [
                    1
                  ]
                },
                "levels": {
                  "type": "array",
                  "examples": [
                    [
                      1,
                      2
                    ]
                  ],
                  "items": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  }
                },
                "mass": {
                  "type": "real",
                  "examples": [
                    194.0804
                  ]
                },
                "mass_min": {
                  "type": "real",
                  "examples": [
                    194.0
                  ]
                },
                "mass_max": {
                  "type": "real",
                  "examples": [
                    194.2
                  ]
                },
                "mz": {
                  "type": "real",
                  "examples": [
                    195.0877
                  ]
                },
                "mz_min": {
                  "type": "real",
                  "examples": [
                    195.0
                  ]
                },
                "mz_max": {
                  "type": "real",
                  "examples": [
                    195.2
                  ]
                },
                "rt": {
                  "type": "real",
                  "examples": [
                    1020.0
                  ]
                },
                "rt_min": {
                  "type": "real",
                  "examples": [
                    1000.0
                  ]
                },
                "rt_max": {
                  "type": "real",
                  "examples": [
                    1040.0
                  ]
                }
              }
            }
          },
          "example": [
            {
              "id": "caffeine",
              "mass": 194.0804
            }
          ],
          "default": null
        },
        {
          "name": "polarity",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ],
            "default": 20.0
          },
          "example": 20.0,
          "default": 20.0
        },
        {
          "name": "rt_tolerance",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ],
            "default": 60.0
          },
          "example": 60.0,
          "default": 60.0
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#featuresResult",
        "schema": {
          "type": "table",
          "properties": {
            "project_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "feature": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "feature_component": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "feature_group": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "adduct": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mass": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "noise": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "sn": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "area": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "rtmin": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "rtmax": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "width": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mzmin": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mzmax": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "ppm": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "fwhm_rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "fwhm_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "gaussian_A": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "gaussian_mu": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "gaussian_sigma": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "gaussian_r2": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "jaggedness": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "sharpness": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "asymmetry": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "modality": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "plates": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "filtered": {
              "type": "array",
              "items": {
                "type": "boolean"
              }
            },
            "filter": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "filled": {
              "type": "array",
              "items": {
                "type": "boolean"
              }
            },
            "correction": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "eic_size": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "eic_rt": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "eic_mz": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "eic_intensity": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "eic_baseline": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "eic_smoothed": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "ms1_size": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "ms1_mz": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "ms1_intensity": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "ms2_size": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "ms2_mz": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "ms2_intensity": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "annotation_category": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "annotation_type": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "annotation_parent_feature": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "annotation_element": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "annotation_mass_error_da": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "annotation_mass_error_ppm": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "annotation_rt_error": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "annotation_rel_intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "annotation_expected_rel_intensity_min": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "annotation_expected_rel_intensity_max": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "annotation_score": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_size": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "component_rt_center": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_rt_spread": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_density": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_mean_correlation": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_best_partner": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "component_max_correlation": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_mean_correlation_to_component": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_membership_score": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "component_is_core": {
              "type": "array",
              "items": {
                "type": "boolean"
              }
            },
            "component_bridge_flag": {
              "type": "array",
              "items": {
                "type": "boolean"
              }
            },
            "created_at": {
              "type": "array",
              "items": {
                "type": "timestamp"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_raw_chromatograms",
      "domain": "mass_spec",
      "label": "Get raw chromatograms",
      "definition": "Read chromatogram point records directly from the selected mass spectrometry files.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_raw_chromatograms",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "indices": {
              "type": "array",
              "examples": [
                [
                  0,
                  2
                ]
              ],
              "items": {
                "type": "integer",
                "examples": [
                  1
                ]
              }
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "indices",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "integerItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                0,
                2
              ]
            ],
            "items": {
              "type": "integer",
              "examples": [
                1
              ]
            }
          },
          "example": [
            0,
            2
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#chromatogramsResult",
        "schema": {
          "type": "table",
          "properties": {
            "project_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "chromatogram_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "raw_intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "baseline": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_raw_spectra",
      "domain": "mass_spec",
      "label": "Get raw spectra",
      "definition": "Read raw spectrum points using independent target ranges and shared mass-spec filters.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_raw_spectra",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            },
            "levels": {
              "type": "array",
              "examples": [
                [
                  1,
                  2
                ]
              ],
              "items": {
                "type": "integer",
                "examples": [
                  1
                ]
              },
              "default": []
            },
            "targets": {
              "type": "array",
              "examples": [
                [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ],
                "properties": {
                  "id": {
                    "type": "string",
                    "examples": [
                      "caffeine"
                    ]
                  },
                  "analyses": {
                    "type": "array",
                    "examples": [
                      [
                        "sample-r001",
                        "sample-r002"
                      ]
                    ],
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  },
                  "polarity": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  },
                  "levels": {
                    "type": "array",
                    "examples": [
                      [
                        1,
                        2
                      ]
                    ],
                    "items": {
                      "type": "integer",
                      "examples": [
                        1
                      ]
                    }
                  },
                  "mass": {
                    "type": "real",
                    "examples": [
                      194.0804
                    ]
                  },
                  "mass_min": {
                    "type": "real",
                    "examples": [
                      194.0
                    ]
                  },
                  "mass_max": {
                    "type": "real",
                    "examples": [
                      194.2
                    ]
                  },
                  "mz": {
                    "type": "real",
                    "examples": [
                      195.0877
                    ]
                  },
                  "mz_min": {
                    "type": "real",
                    "examples": [
                      195.0
                    ]
                  },
                  "mz_max": {
                    "type": "real",
                    "examples": [
                      195.2
                    ]
                  },
                  "rt": {
                    "type": "real",
                    "examples": [
                      1020.0
                    ]
                  },
                  "rt_min": {
                    "type": "real",
                    "examples": [
                      1000.0
                    ]
                  },
                  "rt_max": {
                    "type": "real",
                    "examples": [
                      1040.0
                    ]
                  }
                }
              }
            },
            "polarity": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "rt_tolerance": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "charge": {
              "type": "integer",
              "examples": [
                1
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        },
        {
          "name": "levels",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "integerItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                1,
                2
              ]
            ],
            "items": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "default": []
          },
          "example": [
            1,
            2
          ],
          "default": []
        },
        {
          "name": "targets",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "targetRange",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ],
              "properties": {
                "id": {
                  "type": "string",
                  "examples": [
                    "caffeine"
                  ]
                },
                "analyses": {
                  "type": "array",
                  "examples": [
                    [
                      "sample-r001",
                      "sample-r002"
                    ]
                  ],
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                },
                "polarity": {
                  "type": "integer",
                  "examples": [
                    1
                  ]
                },
                "levels": {
                  "type": "array",
                  "examples": [
                    [
                      1,
                      2
                    ]
                  ],
                  "items": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  }
                },
                "mass": {
                  "type": "real",
                  "examples": [
                    194.0804
                  ]
                },
                "mass_min": {
                  "type": "real",
                  "examples": [
                    194.0
                  ]
                },
                "mass_max": {
                  "type": "real",
                  "examples": [
                    194.2
                  ]
                },
                "mz": {
                  "type": "real",
                  "examples": [
                    195.0877
                  ]
                },
                "mz_min": {
                  "type": "real",
                  "examples": [
                    195.0
                  ]
                },
                "mz_max": {
                  "type": "real",
                  "examples": [
                    195.2
                  ]
                },
                "rt": {
                  "type": "real",
                  "examples": [
                    1020.0
                  ]
                },
                "rt_min": {
                  "type": "real",
                  "examples": [
                    1000.0
                  ]
                },
                "rt_max": {
                  "type": "real",
                  "examples": [
                    1040.0
                  ]
                }
              }
            }
          },
          "example": [
            {
              "id": "caffeine",
              "mass": 194.0804
            }
          ],
          "default": null
        },
        {
          "name": "polarity",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "rt_tolerance",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "charge",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#spectraResult",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "replicate": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "target_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "level": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "pre_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzlow": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzhigh": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_ce": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mobility": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_raw_spectra_eic",
      "domain": "mass_spec",
      "label": "Get extracted ion chromatograms",
      "definition": "Read MS1 raw points grouped as extracted ion chromatograms for independent target ranges.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_raw_spectra_eic",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            },
            "targets": {
              "type": "array",
              "examples": [
                [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ],
                "properties": {
                  "id": {
                    "type": "string",
                    "examples": [
                      "caffeine"
                    ]
                  },
                  "analyses": {
                    "type": "array",
                    "examples": [
                      [
                        "sample-r001",
                        "sample-r002"
                      ]
                    ],
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  },
                  "polarity": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  },
                  "levels": {
                    "type": "array",
                    "examples": [
                      [
                        1,
                        2
                      ]
                    ],
                    "items": {
                      "type": "integer",
                      "examples": [
                        1
                      ]
                    }
                  },
                  "mass": {
                    "type": "real",
                    "examples": [
                      194.0804
                    ]
                  },
                  "mass_min": {
                    "type": "real",
                    "examples": [
                      194.0
                    ]
                  },
                  "mass_max": {
                    "type": "real",
                    "examples": [
                      194.2
                    ]
                  },
                  "mz": {
                    "type": "real",
                    "examples": [
                      195.0877
                    ]
                  },
                  "mz_min": {
                    "type": "real",
                    "examples": [
                      195.0
                    ]
                  },
                  "mz_max": {
                    "type": "real",
                    "examples": [
                      195.2
                    ]
                  },
                  "rt": {
                    "type": "real",
                    "examples": [
                      1020.0
                    ]
                  },
                  "rt_min": {
                    "type": "real",
                    "examples": [
                      1000.0
                    ]
                  },
                  "rt_max": {
                    "type": "real",
                    "examples": [
                      1040.0
                    ]
                  }
                }
              }
            },
            "polarity": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "rt_tolerance": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "charge": {
              "type": "integer",
              "examples": [
                1
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        },
        {
          "name": "targets",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "targetRange",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ],
              "properties": {
                "id": {
                  "type": "string",
                  "examples": [
                    "caffeine"
                  ]
                },
                "analyses": {
                  "type": "array",
                  "examples": [
                    [
                      "sample-r001",
                      "sample-r002"
                    ]
                  ],
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                },
                "polarity": {
                  "type": "integer",
                  "examples": [
                    1
                  ]
                },
                "levels": {
                  "type": "array",
                  "examples": [
                    [
                      1,
                      2
                    ]
                  ],
                  "items": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  }
                },
                "mass": {
                  "type": "real",
                  "examples": [
                    194.0804
                  ]
                },
                "mass_min": {
                  "type": "real",
                  "examples": [
                    194.0
                  ]
                },
                "mass_max": {
                  "type": "real",
                  "examples": [
                    194.2
                  ]
                },
                "mz": {
                  "type": "real",
                  "examples": [
                    195.0877
                  ]
                },
                "mz_min": {
                  "type": "real",
                  "examples": [
                    195.0
                  ]
                },
                "mz_max": {
                  "type": "real",
                  "examples": [
                    195.2
                  ]
                },
                "rt": {
                  "type": "real",
                  "examples": [
                    1020.0
                  ]
                },
                "rt_min": {
                  "type": "real",
                  "examples": [
                    1000.0
                  ]
                },
                "rt_max": {
                  "type": "real",
                  "examples": [
                    1040.0
                  ]
                }
              }
            }
          },
          "example": [
            {
              "id": "caffeine",
              "mass": 194.0804
            }
          ],
          "default": null
        },
        {
          "name": "polarity",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "rt_tolerance",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "charge",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#eicResult",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "replicate": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "target_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "level": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "pre_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzlow": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzhigh": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_ce": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mobility": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_raw_spectra_ms1",
      "domain": "mass_spec",
      "label": "Get MS1 spectra",
      "definition": "Read MS1 raw spectrum points using independent target ranges and shared filters.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_raw_spectra_ms1",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            },
            "targets": {
              "type": "array",
              "examples": [
                [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ],
                "properties": {
                  "id": {
                    "type": "string",
                    "examples": [
                      "caffeine"
                    ]
                  },
                  "analyses": {
                    "type": "array",
                    "examples": [
                      [
                        "sample-r001",
                        "sample-r002"
                      ]
                    ],
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  },
                  "polarity": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  },
                  "levels": {
                    "type": "array",
                    "examples": [
                      [
                        1,
                        2
                      ]
                    ],
                    "items": {
                      "type": "integer",
                      "examples": [
                        1
                      ]
                    }
                  },
                  "mass": {
                    "type": "real",
                    "examples": [
                      194.0804
                    ]
                  },
                  "mass_min": {
                    "type": "real",
                    "examples": [
                      194.0
                    ]
                  },
                  "mass_max": {
                    "type": "real",
                    "examples": [
                      194.2
                    ]
                  },
                  "mz": {
                    "type": "real",
                    "examples": [
                      195.0877
                    ]
                  },
                  "mz_min": {
                    "type": "real",
                    "examples": [
                      195.0
                    ]
                  },
                  "mz_max": {
                    "type": "real",
                    "examples": [
                      195.2
                    ]
                  },
                  "rt": {
                    "type": "real",
                    "examples": [
                      1020.0
                    ]
                  },
                  "rt_min": {
                    "type": "real",
                    "examples": [
                      1000.0
                    ]
                  },
                  "rt_max": {
                    "type": "real",
                    "examples": [
                      1040.0
                    ]
                  }
                }
              }
            },
            "polarity": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "rt_tolerance": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "charge": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "mz_clust": {
              "type": "real",
              "examples": [
                0.003
              ],
              "default": 0.003
            },
            "presence": {
              "type": "real",
              "examples": [
                0.8
              ],
              "default": 0.8
            },
            "min_intensity_ms1": {
              "type": "real",
              "examples": [
                1000.0
              ],
              "default": 0.0
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        },
        {
          "name": "targets",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "targetRange",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ],
              "properties": {
                "id": {
                  "type": "string",
                  "examples": [
                    "caffeine"
                  ]
                },
                "analyses": {
                  "type": "array",
                  "examples": [
                    [
                      "sample-r001",
                      "sample-r002"
                    ]
                  ],
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                },
                "polarity": {
                  "type": "integer",
                  "examples": [
                    1
                  ]
                },
                "levels": {
                  "type": "array",
                  "examples": [
                    [
                      1,
                      2
                    ]
                  ],
                  "items": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  }
                },
                "mass": {
                  "type": "real",
                  "examples": [
                    194.0804
                  ]
                },
                "mass_min": {
                  "type": "real",
                  "examples": [
                    194.0
                  ]
                },
                "mass_max": {
                  "type": "real",
                  "examples": [
                    194.2
                  ]
                },
                "mz": {
                  "type": "real",
                  "examples": [
                    195.0877
                  ]
                },
                "mz_min": {
                  "type": "real",
                  "examples": [
                    195.0
                  ]
                },
                "mz_max": {
                  "type": "real",
                  "examples": [
                    195.2
                  ]
                },
                "rt": {
                  "type": "real",
                  "examples": [
                    1020.0
                  ]
                },
                "rt_min": {
                  "type": "real",
                  "examples": [
                    1000.0
                  ]
                },
                "rt_max": {
                  "type": "real",
                  "examples": [
                    1040.0
                  ]
                }
              }
            }
          },
          "example": [
            {
              "id": "caffeine",
              "mass": 194.0804
            }
          ],
          "default": null
        },
        {
          "name": "polarity",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "rt_tolerance",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "charge",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "mz_clust",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.003
            ],
            "default": 0.003
          },
          "example": 0.003,
          "default": 0.003
        },
        {
          "name": "presence",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ],
            "default": 0.8
          },
          "example": 0.8,
          "default": 0.8
        },
        {
          "name": "min_intensity_ms1",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1000.0
            ],
            "default": 0.0
          },
          "example": 1000.0,
          "default": 0.0
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#ms1Result",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "replicate": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "target_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "level": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "pre_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzlow": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzhigh": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_ce": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mobility": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_raw_spectra_ms2",
      "domain": "mass_spec",
      "label": "Get MS2 spectra",
      "definition": "Read MS2 raw spectrum points using independent target ranges and shared filters.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_raw_spectra_ms2",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            },
            "targets": {
              "type": "array",
              "examples": [
                [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ],
                "properties": {
                  "id": {
                    "type": "string",
                    "examples": [
                      "caffeine"
                    ]
                  },
                  "analyses": {
                    "type": "array",
                    "examples": [
                      [
                        "sample-r001",
                        "sample-r002"
                      ]
                    ],
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  },
                  "polarity": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  },
                  "levels": {
                    "type": "array",
                    "examples": [
                      [
                        1,
                        2
                      ]
                    ],
                    "items": {
                      "type": "integer",
                      "examples": [
                        1
                      ]
                    }
                  },
                  "mass": {
                    "type": "real",
                    "examples": [
                      194.0804
                    ]
                  },
                  "mass_min": {
                    "type": "real",
                    "examples": [
                      194.0
                    ]
                  },
                  "mass_max": {
                    "type": "real",
                    "examples": [
                      194.2
                    ]
                  },
                  "mz": {
                    "type": "real",
                    "examples": [
                      195.0877
                    ]
                  },
                  "mz_min": {
                    "type": "real",
                    "examples": [
                      195.0
                    ]
                  },
                  "mz_max": {
                    "type": "real",
                    "examples": [
                      195.2
                    ]
                  },
                  "rt": {
                    "type": "real",
                    "examples": [
                      1020.0
                    ]
                  },
                  "rt_min": {
                    "type": "real",
                    "examples": [
                      1000.0
                    ]
                  },
                  "rt_max": {
                    "type": "real",
                    "examples": [
                      1040.0
                    ]
                  }
                }
              }
            },
            "polarity": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "rt_tolerance": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "charge": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "isolation_window": {
              "type": "real",
              "examples": [
                1.3
              ],
              "default": 1.3
            },
            "mz_clust": {
              "type": "real",
              "examples": [
                0.003
              ],
              "default": 0.005
            },
            "presence": {
              "type": "real",
              "examples": [
                0.8
              ],
              "default": 0.0
            },
            "min_intensity_ms2": {
              "type": "real",
              "examples": [
                100.0
              ],
              "default": 0.0
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        },
        {
          "name": "targets",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "targetRange",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ],
              "properties": {
                "id": {
                  "type": "string",
                  "examples": [
                    "caffeine"
                  ]
                },
                "analyses": {
                  "type": "array",
                  "examples": [
                    [
                      "sample-r001",
                      "sample-r002"
                    ]
                  ],
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                },
                "polarity": {
                  "type": "integer",
                  "examples": [
                    1
                  ]
                },
                "levels": {
                  "type": "array",
                  "examples": [
                    [
                      1,
                      2
                    ]
                  ],
                  "items": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  }
                },
                "mass": {
                  "type": "real",
                  "examples": [
                    194.0804
                  ]
                },
                "mass_min": {
                  "type": "real",
                  "examples": [
                    194.0
                  ]
                },
                "mass_max": {
                  "type": "real",
                  "examples": [
                    194.2
                  ]
                },
                "mz": {
                  "type": "real",
                  "examples": [
                    195.0877
                  ]
                },
                "mz_min": {
                  "type": "real",
                  "examples": [
                    195.0
                  ]
                },
                "mz_max": {
                  "type": "real",
                  "examples": [
                    195.2
                  ]
                },
                "rt": {
                  "type": "real",
                  "examples": [
                    1020.0
                  ]
                },
                "rt_min": {
                  "type": "real",
                  "examples": [
                    1000.0
                  ]
                },
                "rt_max": {
                  "type": "real",
                  "examples": [
                    1040.0
                  ]
                }
              }
            }
          },
          "example": [
            {
              "id": "caffeine",
              "mass": 194.0804
            }
          ],
          "default": null
        },
        {
          "name": "polarity",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "rt_tolerance",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "charge",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "isolation_window",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1.3
            ],
            "default": 1.3
          },
          "example": 1.3,
          "default": 1.3
        },
        {
          "name": "mz_clust",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.003
            ],
            "default": 0.005
          },
          "example": 0.003,
          "default": 0.005
        },
        {
          "name": "presence",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ],
            "default": 0.0
          },
          "example": 0.8,
          "default": 0.0
        },
        {
          "name": "min_intensity_ms2",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              100.0
            ],
            "default": 0.0
          },
          "example": 100.0,
          "default": 0.0
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#ms2Result",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "replicate": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "target_id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "id": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "level": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "pre_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzlow": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_mzhigh": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "pre_ce": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mobility": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_replicate_names",
      "domain": "mass_spec",
      "label": "Get replicate names",
      "definition": "Read replicate labels.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_replicate_names",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#replicateNamesResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_spectra_headers",
      "domain": "mass_spec",
      "label": "Get spectra headers",
      "definition": "Read spectra header rows for selected analyses.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_spectra_headers",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#spectraHeadersResult",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "index": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "scan": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "array_length": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "level": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "mode": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "configuration": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "lowmz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "highmz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "bpmz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "bpint": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "tic": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mobility": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "window_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "window_mzlow": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "window_mzhigh": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "precursor_mz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "precursor_intensity": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "precursor_charge": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "activation_ce": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_SPECTRA_HEADERS"
        ],
        "writes": []
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.get_spectra_tic",
      "domain": "mass_spec",
      "label": "Get spectra TIC",
      "definition": "Read total ion current rows with the shared mass-spec filters.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "get_spectra_tic",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              },
              "default": []
            },
            "levels": {
              "type": "array",
              "examples": [
                [
                  1,
                  2
                ]
              ],
              "items": {
                "type": "integer",
                "examples": [
                  1
                ]
              },
              "default": []
            },
            "rt_min": {
              "type": "real",
              "examples": [
                900.0
              ]
            },
            "rt_max": {
              "type": "real",
              "examples": [
                1200.0
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            },
            "default": []
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": []
        },
        {
          "name": "levels",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "integerItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                1,
                2
              ]
            ],
            "items": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "default": []
          },
          "example": [
            1,
            2
          ],
          "default": []
        },
        {
          "name": "rt_min",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              900.0
            ]
          },
          "example": 900.0,
          "default": null
        },
        {
          "name": "rt_max",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1200.0
            ]
          },
          "example": 1200.0,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#ticResult",
        "schema": {
          "type": "table",
          "properties": {
            "analysis": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "replicate": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "polarity": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "level": {
              "type": "array",
              "items": {
                "type": "integer"
              }
            },
            "rt": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "mobility": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "tic": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "bpmz": {
              "type": "array",
              "items": {
                "type": "real"
              }
            },
            "bpint": {
              "type": "array",
              "items": {
                "type": "real"
              }
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_SPECTRA_HEADERS"
        ],
        "writes": []
      }
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.group_features",
      "domain": "mass_spec",
      "label": "Group features",
      "definition": "Group features across analyses into shared feature groups using RT/mass tolerance and an alignment method.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "method": {
              "type": "string",
              "examples": [
                "mass_spec.get_raw_spectra"
              ]
            },
            "rt_deviation": {
              "type": "real",
              "examples": [
                40.0
              ]
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "min_samples": {
              "type": "integer",
              "examples": [
                2
              ]
            },
            "bin_size": {
              "type": "real",
              "examples": [
                5.0
              ]
            }
          },
          "required": [
            "analysis_names",
            "method"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "method",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "mass_spec.get_raw_spectra"
            ]
          },
          "example": "mass_spec.get_raw_spectra",
          "default": null
        },
        {
          "name": "rt_deviation",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              40.0
            ]
          },
          "example": 40.0,
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "min_samples",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              2
            ]
          },
          "example": 2,
          "default": null
        },
        {
          "name": "bin_size",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              5.0
            ]
          },
          "example": 5.0,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.load_chromatograms",
      "domain": "mass_spec",
      "label": "Load chromatograms",
      "definition": "Load selected chromatograms from persisted mass spectrometry analyses into MASS_SPEC_CHROMATOGRAMS.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "chromatogram_id_regex": {
              "type": "array",
              "examples": [
                [
                  "^TIC.*"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "ignore_case": {
              "type": "boolean",
              "examples": [
                true
              ]
            },
            "invert": {
              "type": "boolean"
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "chromatogram_id_regex",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "^TIC.*"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "^TIC.*"
          ],
          "default": null
        },
        {
          "name": "ignore_case",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean",
            "examples": [
              true
            ]
          },
          "example": true,
          "default": null
        },
        {
          "name": "invert",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_ANALYSES"
        ],
        "writes": [
          "MASS_SPEC_CHROMATOGRAMS"
        ]
      },
      "cacheable": false,
      "required_methods": [],
      "single_occurrence": true
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.load_features_ms1",
      "domain": "mass_spec",
      "label": "Load MS1 spectra for features",
      "definition": "Resolve and cluster MS1 spectra for each persisted feature and store the joined MS1 spectrum on the feature row.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "filtered": {
              "type": "boolean"
            },
            "rt_window": {
              "type": "array",
              "examples": [
                [
                  0.0,
                  0.0
                ]
              ],
              "items": {
                "type": "real",
                "examples": [
                  1.0
                ]
              }
            },
            "mz_window": {
              "type": "array",
              "examples": [
                [
                  0.0,
                  0.0
                ]
              ],
              "items": {
                "type": "real",
                "examples": [
                  1.0
                ]
              }
            },
            "min_traces_intensity": {
              "type": "real"
            },
            "mz_clust": {
              "type": "real",
              "examples": [
                0.003
              ]
            },
            "presence": {
              "type": "real",
              "examples": [
                0.8
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "filtered",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        },
        {
          "name": "rt_window",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "realItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                0.0,
                0.0
              ]
            ],
            "items": {
              "type": "real",
              "examples": [
                1.0
              ]
            }
          },
          "example": [
            0.0,
            0.0
          ],
          "default": null
        },
        {
          "name": "mz_window",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "realItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                0.0,
                0.0
              ]
            ],
            "items": {
              "type": "real",
              "examples": [
                1.0
              ]
            }
          },
          "example": [
            0.0,
            0.0
          ],
          "default": null
        },
        {
          "name": "min_traces_intensity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "mz_clust",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.003
            ]
          },
          "example": 0.003,
          "default": null
        },
        {
          "name": "presence",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.load_features_ms2",
      "domain": "mass_spec",
      "label": "Load MS2 spectra for features",
      "definition": "Resolve and cluster MS2 spectra for each persisted feature using the precursor isolation window and store the joined MS2 spectrum on the feature row.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "filtered": {
              "type": "boolean"
            },
            "min_traces_intensity": {
              "type": "real"
            },
            "isolation_window": {
              "type": "real",
              "examples": [
                1.3
              ]
            },
            "mz_clust": {
              "type": "real",
              "examples": [
                0.003
              ]
            },
            "presence": {
              "type": "real",
              "examples": [
                0.8
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "filtered",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        },
        {
          "name": "min_traces_intensity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real"
          },
          "example": null,
          "default": null
        },
        {
          "name": "isolation_window",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              1.3
            ]
          },
          "example": 1.3,
          "default": null
        },
        {
          "name": "mz_clust",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.003
            ]
          },
          "example": 0.003,
          "default": null
        },
        {
          "name": "presence",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.remove_analyses",
      "domain": "mass_spec",
      "label": "Remove mass spectrometry analyses",
      "definition": "Remove persisted mass spectrometry analyses by analysis name.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "remove_analyses",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            }
          },
          "required": [
            "database_path",
            "project_id",
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#removeAnalysesResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      },
      "effects": {
        "mutates_project": true,
        "reads": [],
        "writes": [
          "MASS_SPEC_ANALYSES"
        ]
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.set_blank_names",
      "domain": "mass_spec",
      "label": "Set blank names",
      "definition": "Update blank labels.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "set_blank_names",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "blank_names": {
              "type": "array",
              "examples": [
                [
                  "blank",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            }
          },
          "required": [
            "database_path",
            "project_id",
            "blank_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "blank_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "blank",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "blank",
            "blank"
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#updatedResult",
        "schema": {
          "type": "object",
          "properties": {
            "updated": {
              "type": "integer"
            }
          }
        }
      },
      "effects": {
        "mutates_project": true,
        "reads": [],
        "writes": [
          "MASS_SPEC_ANALYSES"
        ]
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.set_concentrations",
      "domain": "mass_spec",
      "label": "Set concentrations",
      "definition": "Update analysis concentrations.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "set_concentrations",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "concentrations": {
              "type": "array",
              "examples": [
                [
                  1.0,
                  2.0
                ]
              ],
              "items": {
                "type": "real",
                "examples": [
                  1.0
                ]
              }
            }
          },
          "required": [
            "database_path",
            "project_id",
            "concentrations"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "concentrations",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "realItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                1.0,
                2.0
              ]
            ],
            "items": {
              "type": "real",
              "examples": [
                1.0
              ]
            }
          },
          "example": [
            1.0,
            2.0
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#updatedResult",
        "schema": {
          "type": "object",
          "properties": {
            "updated": {
              "type": "integer"
            }
          }
        }
      },
      "effects": {
        "mutates_project": true,
        "reads": [],
        "writes": [
          "MASS_SPEC_ANALYSES"
        ]
      }
    },
    {
      "kind": "operation",
      "canonical_id": "mass_spec.set_replicate_names",
      "domain": "mass_spec",
      "label": "Set replicate names",
      "definition": "Update replicate labels.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "set_replicate_names",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "replicate_names": {
              "type": "array",
              "examples": [
                [
                  "r1",
                  "r2"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            }
          },
          "required": [
            "database_path",
            "project_id",
            "replicate_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "replicate_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "r1",
                "r2"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "r1",
            "r2"
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/domains/mass_spec#updatedResult",
        "schema": {
          "type": "object",
          "properties": {
            "updated": {
              "type": "integer"
            }
          }
        }
      },
      "effects": {
        "mutates_project": true,
        "reads": [],
        "writes": [
          "MASS_SPEC_ANALYSES"
        ]
      }
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.subtract_blank",
      "domain": "mass_spec",
      "label": "Subtract blank features",
      "definition": "Flag features whose intensity is largely explained by blank analyses, using RT and m/z expansion windows.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "blank_threshold": {
              "type": "real",
              "examples": [
                0.3
              ]
            },
            "rt_expand": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "mz_expand": {
              "type": "real",
              "examples": [
                0.005
              ]
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "blank_threshold",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.3
            ]
          },
          "example": 0.3,
          "default": null
        },
        {
          "name": "rt_expand",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "mz_expand",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.005
            ]
          },
          "example": 0.005,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "mass_spec.suspect_screening",
      "domain": "mass_spec",
      "label": "Screen suspect features",
      "definition": "Match detected features against a suspect list by mass, RT, and MS2 similarity and record candidate assignments.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "None",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            },
            "targets": {
              "type": "array",
              "examples": [
                [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "id": "caffeine",
                    "mass": 194.0804
                  }
                ],
                "properties": {
                  "id": {
                    "type": "string",
                    "examples": [
                      "caffeine"
                    ]
                  },
                  "analyses": {
                    "type": "array",
                    "examples": [
                      [
                        "sample-r001",
                        "sample-r002"
                      ]
                    ],
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  },
                  "polarity": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  },
                  "levels": {
                    "type": "array",
                    "examples": [
                      [
                        1,
                        2
                      ]
                    ],
                    "items": {
                      "type": "integer",
                      "examples": [
                        1
                      ]
                    }
                  },
                  "mass": {
                    "type": "real",
                    "examples": [
                      194.0804
                    ]
                  },
                  "mass_min": {
                    "type": "real",
                    "examples": [
                      194.0
                    ]
                  },
                  "mass_max": {
                    "type": "real",
                    "examples": [
                      194.2
                    ]
                  },
                  "mz": {
                    "type": "real",
                    "examples": [
                      195.0877
                    ]
                  },
                  "mz_min": {
                    "type": "real",
                    "examples": [
                      195.0
                    ]
                  },
                  "mz_max": {
                    "type": "real",
                    "examples": [
                      195.2
                    ]
                  },
                  "rt": {
                    "type": "real",
                    "examples": [
                      1020.0
                    ]
                  },
                  "rt_min": {
                    "type": "real",
                    "examples": [
                      1000.0
                    ]
                  },
                  "rt_max": {
                    "type": "real",
                    "examples": [
                      1040.0
                    ]
                  }
                }
              }
            },
            "ppm": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "sec": {
              "type": "real",
              "examples": [
                60.0
              ]
            },
            "ppm_ms2": {
              "type": "real",
              "examples": [
                20.0
              ]
            },
            "mzr_ms2": {
              "type": "real",
              "examples": [
                0.01
              ]
            },
            "min_cosine_similarity": {
              "type": "real",
              "examples": [
                0.8
              ]
            },
            "min_shared_fragments": {
              "type": "integer",
              "examples": [
                1
              ]
            },
            "filtered": {
              "type": "boolean"
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        },
        {
          "name": "targets",
          "type": "array",
          "required": false,
          "constraints": {},
          "items": "targetRange",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "id": "caffeine",
                  "mass": 194.0804
                }
              ],
              "properties": {
                "id": {
                  "type": "string",
                  "examples": [
                    "caffeine"
                  ]
                },
                "analyses": {
                  "type": "array",
                  "examples": [
                    [
                      "sample-r001",
                      "sample-r002"
                    ]
                  ],
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                },
                "polarity": {
                  "type": "integer",
                  "examples": [
                    1
                  ]
                },
                "levels": {
                  "type": "array",
                  "examples": [
                    [
                      1,
                      2
                    ]
                  ],
                  "items": {
                    "type": "integer",
                    "examples": [
                      1
                    ]
                  }
                },
                "mass": {
                  "type": "real",
                  "examples": [
                    194.0804
                  ]
                },
                "mass_min": {
                  "type": "real",
                  "examples": [
                    194.0
                  ]
                },
                "mass_max": {
                  "type": "real",
                  "examples": [
                    194.2
                  ]
                },
                "mz": {
                  "type": "real",
                  "examples": [
                    195.0877
                  ]
                },
                "mz_min": {
                  "type": "real",
                  "examples": [
                    195.0
                  ]
                },
                "mz_max": {
                  "type": "real",
                  "examples": [
                    195.2
                  ]
                },
                "rt": {
                  "type": "real",
                  "examples": [
                    1020.0
                  ]
                },
                "rt_min": {
                  "type": "real",
                  "examples": [
                    1000.0
                  ]
                },
                "rt_max": {
                  "type": "real",
                  "examples": [
                    1040.0
                  ]
                }
              }
            }
          },
          "example": [
            {
              "id": "caffeine",
              "mass": 194.0804
            }
          ],
          "default": null
        },
        {
          "name": "ppm",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "sec",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              60.0
            ]
          },
          "example": 60.0,
          "default": null
        },
        {
          "name": "ppm_ms2",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              20.0
            ]
          },
          "example": 20.0,
          "default": null
        },
        {
          "name": "mzr_ms2",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.01
            ]
          },
          "example": 0.01,
          "default": null
        },
        {
          "name": "min_cosine_similarity",
          "type": "real",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "real",
            "examples": [
              0.8
            ]
          },
          "example": 0.8,
          "default": null
        },
        {
          "name": "min_shared_fragments",
          "type": "integer",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "integer",
            "examples": [
              1
            ]
          },
          "example": 1,
          "default": null
        },
        {
          "name": "filtered",
          "type": "boolean",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "boolean"
          },
          "example": null,
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [
          "MASS_SPEC_NTA_FEATURES"
        ],
        "writes": [
          "MASS_SPEC_NTA_FEATURES"
        ]
      },
      "cacheable": true,
      "required_methods": [],
      "single_occurrence": false
    },
    {
      "kind": "method",
      "canonical_id": "raman.add_analyses",
      "domain": "raman",
      "label": "Add Raman analyses",
      "definition": "Add Raman analysis files to a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "add_analyses",
        "input_schema": {
          "type": "object",
          "properties": {
            "analyses": {
              "type": "array",
              "examples": [
                [
                  {
                    "path": "data/sample.mzML",
                    "replicate_name": "r1"
                  }
                ]
              ],
              "items": {
                "type": "object",
                "examples": [
                  {
                    "path": "data/sample.mzML",
                    "replicate_name": "r1"
                  }
                ],
                "properties": {
                  "path": {
                    "type": "string",
                    "examples": [
                      "data/sample.mzML"
                    ]
                  },
                  "replicate_name": {
                    "type": "string",
                    "examples": [
                      "r1"
                    ]
                  },
                  "blank_name": {
                    "type": "string",
                    "examples": [
                      "blank"
                    ]
                  }
                },
                "required": [
                  "path"
                ]
              }
            }
          },
          "required": [
            "analyses"
          ]
        }
      },
      "parameters": [
        {
          "name": "analyses",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "analysisFile",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                {
                  "path": "data/sample.mzML",
                  "replicate_name": "r1"
                }
              ]
            ],
            "items": {
              "type": "object",
              "examples": [
                {
                  "path": "data/sample.mzML",
                  "replicate_name": "r1"
                }
              ],
              "properties": {
                "path": {
                  "type": "string",
                  "examples": [
                    "data/sample.mzML"
                  ]
                },
                "replicate_name": {
                  "type": "string",
                  "examples": [
                    "r1"
                  ]
                },
                "blank_name": {
                  "type": "string",
                  "examples": [
                    "blank"
                  ]
                }
              },
              "required": [
                "path"
              ]
            }
          },
          "example": [
            {
              "path": "data/sample.mzML",
              "replicate_name": "r1"
            }
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [],
        "writes": []
      },
      "cacheable": false,
      "required_methods": [],
      "single_occurrence": true
    },
    {
      "kind": "method",
      "canonical_id": "raman.remove_analyses",
      "domain": "raman",
      "label": "Remove Raman analyses",
      "definition": "Remove Raman analysis files from a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "remove_analyses",
        "input_schema": {
          "type": "object",
          "properties": {
            "analysis_names": {
              "type": "array",
              "examples": [
                [
                  "sample",
                  "blank"
                ]
              ],
              "items": {
                "type": "string",
                "examples": [
                  "sample"
                ]
              }
            }
          },
          "required": [
            "analysis_names"
          ]
        }
      },
      "parameters": [
        {
          "name": "analysis_names",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "stringItem",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              [
                "sample",
                "blank"
              ]
            ],
            "items": {
              "type": "string",
              "examples": [
                "sample"
              ]
            }
          },
          "example": [
            "sample",
            "blank"
          ],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#operationStatusResult",
        "schema": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "finished",
                "failed"
              ]
            },
            "info": {
              "type": "string"
            }
          }
        }
      },
      "effects": {
        "mutates_project": false,
        "reads": [],
        "writes": []
      },
      "cacheable": false,
      "required_methods": [],
      "single_occurrence": true
    },
    {
      "kind": "operation",
      "canonical_id": "remove_method",
      "domain": "streamfind",
      "label": "Remove a method from the project workflow",
      "definition": "Remove the first matching method object from the ordered project workflow.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "remove_method",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "method": {
              "type": "string",
              "examples": [
                "mass_spec.get_raw_spectra"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "method"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "method",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "mass_spec.get_raw_spectra"
            ]
          },
          "example": "mass_spec.get_raw_spectra",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#workflowResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "id": {
                "type": "string"
              },
              "name": {
                "type": "string"
              },
              "description": {
                "type": "string"
              },
              "domain": {
                "type": "string"
              },
              "parameters": {
                "type": "object"
              },
              "cacheable": {
                "type": "boolean"
              },
              "required_methods": {
                "type": "array",
                "items": {
                  "type": "string"
                }
              }
            }
          }
        }
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
      "kind": "operation",
      "canonical_id": "run_method",
      "domain": "streamfind",
      "label": "Run a planned workflow method",
      "definition": "Execute only the next pending method already present in the project's workflow.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "run_method",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "method": {
              "type": "string",
              "examples": [
                "mass_spec.get_raw_spectra"
              ]
            },
            "parameters": {
              "type": "object",
              "examples": [
                {}
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "method"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "method",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "mass_spec.get_raw_spectra"
            ]
          },
          "example": "mass_spec.get_raw_spectra",
          "default": null
        },
        {
          "name": "parameters",
          "type": "object",
          "required": false,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "object",
            "examples": [
              {}
            ]
          },
          "example": {},
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#workflowExecutionResult",
        "schema": {
          "type": "object"
        }
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
      "kind": "operation",
      "canonical_id": "run_workflow",
      "domain": "streamfind",
      "label": "Run the project workflow",
      "definition": "Execute the persisted workflow for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "run_workflow",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#workflowExecutionResult",
        "schema": {
          "type": "object"
        }
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
      "kind": "operation",
      "canonical_id": "set_metadata",
      "domain": "streamfind",
      "label": "Set project metadata",
      "definition": "Replace the metadata stored for a project.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "set_metadata",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "metadata": {
              "type": "object",
              "examples": [
                {}
              ]
            }
          },
          "required": [
            "database_path",
            "project_id",
            "metadata"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "metadata",
          "type": "object",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "object",
            "examples": [
              {}
            ]
          },
          "example": {},
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#metadataResult",
        "schema": {
          "type": "table",
          "properties": {
            "metadata": {
              "type": "array",
              "items": {
                "type": "string"
              }
            }
          }
        }
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
      "kind": "operation",
      "canonical_id": "set_workflow",
      "domain": "streamfind",
      "label": "Set the project workflow",
      "definition": "Validate and persist a project's workflow.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "set_workflow",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            },
            "workflow": {
              "type": "array",
              "examples": [
                []
              ],
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "type": "string"
                  },
                  "name": {
                    "type": "string"
                  },
                  "description": {
                    "type": "string"
                  },
                  "domain": {
                    "type": "string"
                  },
                  "parameters": {
                    "type": "object"
                  },
                  "cacheable": {
                    "type": "boolean"
                  },
                  "required_methods": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  }
                }
              }
            }
          },
          "required": [
            "database_path",
            "project_id",
            "workflow"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        },
        {
          "name": "workflow",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "methodField",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              []
            ],
            "items": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string"
                },
                "name": {
                  "type": "string"
                },
                "description": {
                  "type": "string"
                },
                "domain": {
                  "type": "string"
                },
                "parameters": {
                  "type": "object"
                },
                "cacheable": {
                  "type": "boolean"
                },
                "required_methods": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                }
              }
            }
          },
          "example": [],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#workflowResult",
        "schema": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "id": {
                "type": "string"
              },
              "name": {
                "type": "string"
              },
              "description": {
                "type": "string"
              },
              "domain": {
                "type": "string"
              },
              "parameters": {
                "type": "object"
              },
              "cacheable": {
                "type": "boolean"
              },
              "required_methods": {
                "type": "array",
                "items": {
                  "type": "string"
                }
              }
            }
          }
        }
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
      "kind": "operation",
      "canonical_id": "validate",
      "domain": "streamfind",
      "label": "Validate a project",
      "definition": "Validate a project's schema and persisted state.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "validate",
        "input_schema": {
          "type": "object",
          "properties": {
            "database_path": {
              "type": "string",
              "examples": [
                "/data/project.duckdb"
              ]
            },
            "project_id": {
              "type": "string",
              "examples": [
                "demo"
              ]
            }
          },
          "required": [
            "database_path",
            "project_id"
          ]
        }
      },
      "parameters": [
        {
          "name": "database_path",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "/data/project.duckdb"
            ]
          },
          "example": "/data/project.duckdb",
          "default": null
        },
        {
          "name": "project_id",
          "type": "string",
          "required": true,
          "constraints": {},
          "items": null,
          "extensions": [],
          "schema": {
            "type": "string",
            "examples": [
              "demo"
            ]
          },
          "example": "demo",
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#validationResult",
        "schema": {
          "type": "object",
          "properties": {
            "valid": {
              "type": "boolean"
            },
            "info": {
              "type": "string"
            }
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
      "kind": "operation",
      "canonical_id": "validate_workflow",
      "domain": "streamfind",
      "label": "Validate a workflow",
      "definition": "Validate workflow methods, ordering, domains, and parameters.",
      "executable": true,
      "exposed": true,
      "mcp": {
        "name": "validate_workflow",
        "input_schema": {
          "type": "object",
          "properties": {
            "workflow": {
              "type": "array",
              "examples": [
                []
              ],
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "type": "string"
                  },
                  "name": {
                    "type": "string"
                  },
                  "description": {
                    "type": "string"
                  },
                  "domain": {
                    "type": "string"
                  },
                  "parameters": {
                    "type": "object"
                  },
                  "cacheable": {
                    "type": "boolean"
                  },
                  "required_methods": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "examples": [
                        "sample"
                      ]
                    }
                  }
                }
              }
            }
          },
          "required": [
            "workflow"
          ]
        }
      },
      "parameters": [
        {
          "name": "workflow",
          "type": "array",
          "required": true,
          "constraints": {},
          "items": "methodField",
          "extensions": [],
          "schema": {
            "type": "array",
            "examples": [
              []
            ],
            "items": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string"
                },
                "name": {
                  "type": "string"
                },
                "description": {
                  "type": "string"
                },
                "domain": {
                  "type": "string"
                },
                "parameters": {
                  "type": "object"
                },
                "cacheable": {
                  "type": "boolean"
                },
                "required_methods": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "examples": [
                      "sample"
                    ]
                  }
                }
              }
            }
          },
          "example": [],
          "default": null
        }
      ],
      "result": {
        "id": "https://streamfind.dev/catalogue/core#validationResult",
        "schema": {
          "type": "object",
          "properties": {
            "valid": {
              "type": "boolean"
            },
            "info": {
              "type": "string"
            }
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
}
"###;

pub const TOOLS: &str = r###"
[
  {
    "name": "add_method",
    "description": "Add a method to the project workflow",
    "inputSchema": {
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
    },
    "outputSchema": {
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
          },
          "max_occurrences": {
            "type": "integer"
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
    "name": "close",
    "description": "Close a project handle",
    "inputSchema": {
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
    },
    "outputSchema": {
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
    },
    "outputSchema": {
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
    },
    "outputSchema": {
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
                },
                "max_occurrences": {
                  "type": "integer"
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
    "name": "create",
    "description": "Create a project",
    "inputSchema": {
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
    },
    "outputSchema": {
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
                },
                "max_occurrences": {
                  "type": "integer"
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
    "name": "delete_cache",
    "description": "Delete project cache",
    "inputSchema": {
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
    },
    "outputSchema": {
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
    },
    "outputSchema": {
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
                },
                "max_occurrences": {
                  "type": "integer"
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
    "name": "get_audit_trail",
    "description": "Read project audit events",
    "inputSchema": {
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
          "operation_details": {
            "type": "object"
          },
          "created_at": {
            "type": "timestamp"
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
          "type": "string",
          "examples": [
            "mass_spec"
          ]
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
            "type": "timestamp"
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
    },
    "outputSchema": {
      "type": "table",
      "properties": {
        "metadata": {
          "type": "array",
          "items": {
            "type": "string"
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
    "name": "get_workflow",
    "description": "Read the project workflow",
    "inputSchema": {
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
    },
    "outputSchema": {
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
          },
          "max_occurrences": {
            "type": "integer"
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
    "name": "remove_method",
    "description": "Remove a method from the project workflow",
    "inputSchema": {
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
    },
    "outputSchema": {
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
          },
          "max_occurrences": {
            "type": "integer"
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
    "name": "run_method",
    "description": "Append and run a workflow method",
    "inputSchema": {
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
    },
    "outputSchema": {
      "type": "table",
      "properties": {
        "metadata": {
          "type": "array",
          "items": {
            "type": "string"
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
    "name": "set_workflow",
    "description": "Set the project workflow",
    "inputSchema": {
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
              },
              "max_occurrences": {
                "type": "integer"
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
    },
    "outputSchema": {
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
          },
          "max_occurrences": {
            "type": "integer"
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
    "name": "validate",
    "description": "Validate a project",
    "inputSchema": {
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
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "valid": {
          "type": "boolean"
        },
        "info": {
          "type": "string"
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
              },
              "max_occurrences": {
                "type": "integer"
              }
            }
          }
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
        "info": {
          "type": "string"
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
"###;
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
              },
              "max_occurrences": {
                "type": "integer"
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
        "mutates_project": true,
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
                    },
                    "max_occurrences": {
                      "type": "integer"
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
                    },
                    "max_occurrences": {
                      "type": "integer"
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
                    },
                    "max_occurrences": {
                      "type": "integer"
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
              },
              "max_occurrences": {
                "type": "integer"
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
      }
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
          "MASS_SPEC_ANALYSES"
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
      }
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
      }
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
      }
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
              },
              "max_occurrences": {
                "type": "integer"
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
      "label": "Append and run a workflow method",
      "definition": "Append a method to a project's workflow, validate it, and execute it.",
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
                  },
                  "max_occurrences": {
                    "type": "integer"
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
                },
                "max_occurrences": {
                  "type": "integer"
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
              },
              "max_occurrences": {
                "type": "integer"
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
                  },
                  "max_occurrences": {
                    "type": "integer"
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
                },
                "max_occurrences": {
                  "type": "integer"
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

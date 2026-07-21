from __future__ import annotations

import os
import platform
from importlib.resources import as_file, files
from pathlib import Path
from typing import Any


def _package_root() -> Path:
    return Path(__file__).resolve().parent


def _repo_root() -> Path:
    return _package_root().parent.parent


def _platform_tag() -> str:
    if os.name == "nt":
        return "windows-x64"
    if platform.system() == "Darwin":
        return "macos-arm64"
    return "linux-x64"


def _duckdb_filename() -> str:
    if os.name == "nt":
        return "duckdb.dll"
    if platform.system() == "Darwin":
        return "libduckdb.dylib"
    return "libduckdb_static.a"


def get_resource_path(*parts: str) -> Path:
    return _package_root().joinpath("resources", *parts)


def get_openbabel_data_path() -> Path:
    env_path = os.environ.get("STREAMFIND_OPENBABEL_DATA")
    if env_path:
        return Path(env_path)

    try:
        resource = files("cf_streamfind.resources.openbabel").joinpath("data")
        with as_file(resource) as resolved:
            resolved_path = Path(resolved)
            if resolved_path.exists():
                return resolved_path
    except Exception:
        pass

    return _repo_root() / "src" / "core" / "external" / "openbabel" / "openbabel-3-2-0" / "data"


def get_duckdb_library_path() -> Path:
    env_path = os.environ.get("STREAMFIND_DUCKDB_LIBRARY")
    if env_path:
        return Path(env_path)

    candidates = [
        _package_root() / "libs" / _duckdb_filename(),
        _repo_root() / "src" / "core" / "external" / "duckdb" / "lib" / _platform_tag() / _duckdb_filename(),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate

    return candidates[0]


def get_user_tool_path(tool: str) -> Path:
    home = Path(os.environ.get("STREAMFIND_HOME", Path.home() / ".streamfind"))
    return home / "tools" / tool


def configure_bundled_runtime() -> dict[str, str]:
    openbabel_data = str(get_openbabel_data_path())
    duckdb_library = str(get_duckdb_library_path())

    os.environ.setdefault("STREAMFIND_OPENBABEL_DATA", openbabel_data)
    os.environ.setdefault("BABEL_DATADIR", openbabel_data)
    os.environ.setdefault("STREAMFIND_DUCKDB_LIBRARY", duckdb_library)

    libs_dir = _package_root() / "libs"
    if os.name == "nt" and libs_dir.exists():
        if hasattr(os, "add_dll_directory"):
            os.add_dll_directory(str(libs_dir))
        os.environ["PATH"] = str(libs_dir) + os.pathsep + os.environ.get("PATH", "")

    return {
        "openbabel_data": openbabel_data,
        "duckdb_library": duckdb_library,
    }


def check_external_tools() -> dict[str, Any]:
    runtime = configure_bundled_runtime()
    return {
        "bundled_openbabel_data": runtime["openbabel_data"],
        "bundled_duckdb_library": runtime["duckdb_library"],
        "user_tools_dir": str(get_user_tool_path("")),
        "metfrag_dir": str(get_user_tool_path("metfrag")),
    }

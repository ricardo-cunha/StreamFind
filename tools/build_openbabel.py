#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Iterable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build vendored Open Babel/InChI runtime artifacts for StreamFind."
    )
    parser.add_argument("--repo-root", required=True, help="Path to the repository root.")
    parser.add_argument(
        "--platform",
        required=True,
        choices=("windows", "linux", "macos"),
        help="Output platform key used under src/core/external/openbabel/build/.",
    )
    parser.add_argument("--cc", required=True, help="C compiler command.")
    parser.add_argument("--cxx", required=True, help="C++ compiler command.")
    parser.add_argument("--ar", required=True, help="Archiver command.")
    parser.add_argument("--cflag", action="append", default=[], help="Extra C compiler flag.")
    parser.add_argument("--cxxflag", action="append", default=[], help="Extra C++ compiler flag.")
    parser.add_argument("--force", action="store_true", help="Force a full rebuild.")
    parser.add_argument(
        "--release-artifact-only",
        action="store_true",
        help="Keep only the built archives and stamp metadata; delete intermediate object caches after a successful build.",
    )
    return parser.parse_args()


def split_command(command: str) -> list[str]:
    return shlex.split(command, posix=os.name != "nt")


def expand_flags(values: Iterable[str]) -> list[str]:
    expanded: list[str] = []
    for value in values:
        if not value:
            continue
        expanded.extend(split_command(value))
    return expanded


def read_manifest(repo_root: Path, manifest: Path) -> list[Path]:
    entries: list[Path] = []
    for raw_line in manifest.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        matches = sorted(repo_root.glob(line))
        if not matches:
            raise FileNotFoundError(f"Manifest entry '{line}' in {manifest} matched no files.")
        entries.extend(matches)
    return entries


def iter_dependency_files(repo_root: Path) -> Iterable[Path]:
    openbabel_root = repo_root / "src" / "core" / "external" / "openbabel" / "openbabel-3-2-0"
    inchi_upstream_root = repo_root / "src" / "core" / "external" / "openbabel" / "inchi-iupac-1.07.5"
    inchi_base_root = repo_root / "src" / "core" / "external" / "openbabel" / "INCHI_BASE"
    manifests = repo_root / "tools" / "openbabel_sources"
    patterns = (
        openbabel_root / "include",
        openbabel_root / "src",
        openbabel_root / "data",
        inchi_upstream_root / "src",
        inchi_base_root / "src",
        manifests,
    )
    for root in patterns:
        if not root.exists():
            continue
        for extension in ("*.h", "*.hpp", "*.txt", "*.cmake"):
            yield from root.rglob(extension)
    yield repo_root / "tools" / "build_openbabel.py"
    yield repo_root / "src" / "core" / "external" / "openbabel" / "openbabel_c_api.cpp"
    yield repo_root / "src" / "core" / "external" / "openbabel" / "streamfind_openbabel_api.h"


def latest_mtime(paths: Iterable[Path]) -> float:
    latest = 0.0
    for path in paths:
        if path.exists():
            latest = max(latest, path.stat().st_mtime)
    return latest


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def safe_rmtree(path: Path) -> None:
    if path.exists():
        for child in path.iterdir():
            if child.is_dir():
                safe_rmtree(child)
            else:
                child.unlink()
        path.rmdir()


def object_path(build_dir: Path, repo_root: Path, source: Path) -> Path:
    relative = source.relative_to(repo_root)
    return build_dir / "obj" / relative.with_suffix(".o")


def compile_source(
    compiler: list[str],
    flags: list[str],
    include_flags: list[str],
    repo_root: Path,
    source: Path,
    obj: Path,
    command_file: Path,
    global_dependency_mtime: float,
    force: bool,
) -> bool:
    ensure_parent(obj)
    ensure_parent(command_file)
    command = compiler + flags + include_flags + ["-c", str(source), "-o", str(obj)]
    command_signature = json.dumps(command, separators=(",", ":"))
    needs_rebuild = force or not obj.exists() or not command_file.exists()
    if not needs_rebuild:
        obj_mtime = obj.stat().st_mtime
        if source.stat().st_mtime > obj_mtime or global_dependency_mtime > obj_mtime:
            needs_rebuild = True
        elif command_file.read_text(encoding="utf-8") != command_signature:
            needs_rebuild = True
    if not needs_rebuild:
        return False

    print(f"[openbabel] compiling {source.relative_to(repo_root)}")
    subprocess.run(command, check=True)
    command_file.write_text(command_signature, encoding="utf-8")
    return True


def build_archive(ar: list[str], archive: Path, objects: list[Path], force: bool) -> None:
    ensure_parent(archive)
    archive_is_stale = force or not archive.exists()
    if not archive_is_stale:
        archive_mtime = archive.stat().st_mtime
        archive_is_stale = any(obj.stat().st_mtime > archive_mtime for obj in objects)
    if not archive_is_stale:
        return
    subprocess.run(ar + ["rcs", str(archive)] + [str(obj) for obj in objects], check=True)


def build_windows_dll(
    cxx_compiler: list[str],
    objects: list[Path],
    output_dll: Path,
    force: bool,
) -> None:
    ensure_parent(output_dll)
    dll_is_stale = force or not output_dll.exists()
    if not dll_is_stale:
        dll_mtime = output_dll.stat().st_mtime
        dll_is_stale = any(obj.stat().st_mtime > dll_mtime for obj in objects)
    if not dll_is_stale:
        return
    # Write to a temp file first, then rename to avoid permission errors
    # when the old DLL is locked by a running R process.
    tmp_dll = output_dll.with_suffix(".dll.tmp")
    command = cxx_compiler + [
        "-shared",
        "-o",
        str(tmp_dll),
    ] + [str(obj) for obj in objects]
    subprocess.run(command, check=True)
    if tmp_dll.exists():
        if output_dll.exists():
            try:
                output_dll.unlink()
            except PermissionError:
                pass
        try:
            os.replace(str(tmp_dll), str(output_dll))
        except PermissionError:
            pass
        except OSError:
            pass


def sync_runtime_artifact(source: Path, destinations: list[Path]) -> None:
    for destination in destinations:
      ensure_parent(destination)
      shutil.copy2(source, destination)


def sync_runtime_directory(source: Path, destinations: list[Path]) -> None:
    for destination in destinations:
        ensure_parent(destination)
        shutil.copytree(source, destination, dirs_exist_ok=True)


def read_stamp_metadata(stamp: Path) -> dict[str, object]:
    if not stamp.exists():
        return {}
    try:
        return json.loads(stamp.read_text(encoding="utf-8"))
    except Exception:
        return {}


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    build_root = repo_root / "src" / "core" / "external" / "openbabel" / "build" / args.platform
    include_root = repo_root / "src" / "core" / "external" / "openbabel" / "openbabel-3-2-0"
    data_root = include_root / "data"
    manifests_root = repo_root / "tools" / "openbabel_sources"

    include_flags = [
        f"-I{include_root / 'include'}",
        f"-I{include_root / 'include' / 'inchi'}",
        f"-I{include_root / 'src'}",
        f"-I{include_root / 'data'}",
        f"-I{include_root / 'src' / 'formats' / 'libinchi'}",
        f"-I{repo_root / 'src' / 'core' / 'external' / 'openbabel' / 'inchi-iupac-1.07.5' / 'src'}",
        f"-I{repo_root / 'src' / 'core' / 'external' / 'openbabel' / 'INCHI_BASE' / 'src'}",
        "-DTARGET_API_LIB",
    ]

    cpp_sources = read_manifest(repo_root, manifests_root / "openbabel_cpp.txt")
    c_sources = read_manifest(repo_root, manifests_root / "inchi_c.txt")
    cpp_sources.append(repo_root / "src" / "core" / "external" / "openbabel" / "openbabel_c_api.cpp")
    dependency_mtime = latest_mtime(iter_dependency_files(repo_root))
    stamp = build_root / ".stamp"

    cxx_flags = expand_flags(args.cxxflag)
    c_flags = expand_flags(args.cflag)
    if args.platform == "windows":
        c_flags = c_flags + ["-DHAVE_ISFINITE=1"]
        cxx_flags = cxx_flags + ["-DHAVE_ISFINITE=1", "-DSTREAMFIND_OPENBABEL_BUILD_DLL"]
    cxx_compiler = split_command(args.cxx)
    c_compiler = split_command(args.cc)
    archiver = split_command(args.ar)

    if not args.force and args.platform == "windows":
        runtime_dll = build_root / "bin" / "openbabel_streamfind.dll"
        stamp_meta = read_stamp_metadata(stamp)
        stamp_mtime = stamp.stat().st_mtime if stamp.exists() else 0.0
        if (
            runtime_dll.exists()
            and stamp.exists()
            and dependency_mtime <= stamp_mtime
            and stamp_meta.get("platform") == args.platform
            and bool(stamp_meta.get("release_artifact_only")) == bool(args.release_artifact_only)
        ):
            sync_runtime_artifact(
                runtime_dll,
                [
                    repo_root / "inst" / "libs" / "x64" / "openbabel_streamfind.dll",
                    repo_root / "python" / "cf_streamfind" / "bin" / "openbabel_streamfind.dll",
                ],
            )
            sync_runtime_directory(
                data_root,
                [
                    repo_root / "inst" / "openbabel-3-2-0" / "data",
                    repo_root / "python" / "cf_streamfind" / "openbabel-3-2-0" / "data",
                ],
            )
            print(f"[openbabel] reusing: {runtime_dll.relative_to(repo_root)}")
            return 0

    openbabel_objects: list[Path] = []
    inchi_objects: list[Path] = []
    any_rebuilt = False

    for source in cpp_sources:
        obj = object_path(build_root, repo_root, source)
        cmd_file = obj.with_suffix(".cmd")
        rebuilt = compile_source(
            cxx_compiler,
            cxx_flags,
            include_flags,
            repo_root,
            source,
            obj,
            cmd_file,
            dependency_mtime,
            args.force,
        )
        any_rebuilt = any_rebuilt or rebuilt
        openbabel_objects.append(obj)

    for source in c_sources:
        obj = object_path(build_root, repo_root, source)
        cmd_file = obj.with_suffix(".cmd")
        rebuilt = compile_source(
            c_compiler,
            c_flags,
            include_flags,
            repo_root,
            source,
            obj,
            cmd_file,
            dependency_mtime,
            args.force,
        )
        any_rebuilt = any_rebuilt or rebuilt
        inchi_objects.append(obj)

    lib_dir = build_root / "lib"
    openbabel_archive = lib_dir / "libopenbabel_streamfind.a"
    inchi_archive = lib_dir / "libinchi_streamfind.a"

    metadata: dict[str, object] = {
        "platform": args.platform,
        "release_artifact_only": args.release_artifact_only,
    }

    if args.platform == "windows":
        bin_dir = build_root / "bin"
        runtime_dll = bin_dir / "openbabel_streamfind.dll"
        build_windows_dll(
            cxx_compiler,
            openbabel_objects + inchi_objects,
            runtime_dll,
            args.force or any_rebuilt,
        )
        sync_runtime_artifact(
            runtime_dll,
            [
                repo_root / "inst" / "libs" / "x64" / "openbabel_streamfind.dll",
                repo_root / "python" / "cf_streamfind" / "bin" / "openbabel_streamfind.dll",
            ],
        )
        sync_runtime_directory(
            data_root,
            [
                repo_root / "inst" / "openbabel-3-2-0" / "data",
                repo_root / "python" / "cf_streamfind" / "openbabel-3-2-0" / "data",
            ],
        )
        metadata["openbabel_runtime"] = str(runtime_dll.relative_to(repo_root))
        safe_rmtree(lib_dir)
    else:
        build_archive(archiver, openbabel_archive, openbabel_objects, args.force or any_rebuilt)
        build_archive(archiver, inchi_archive, inchi_objects, args.force or any_rebuilt)
        metadata["openbabel_archive"] = str(openbabel_archive.relative_to(repo_root))
        metadata["inchi_archive"] = str(inchi_archive.relative_to(repo_root))

    ensure_parent(stamp)
    stamp.write_text(
        json.dumps(metadata, indent=2)
        + "\n",
        encoding="utf-8",
    )

    if args.release_artifact_only:
        safe_rmtree(build_root / "obj")

    if args.platform == "windows":
        print(f"[openbabel] ready: {(build_root / 'bin' / 'openbabel_streamfind.dll').relative_to(repo_root)}")
    else:
        print(f"[openbabel] ready: {openbabel_archive.relative_to(repo_root)}")
        print(f"[openbabel] ready: {inchi_archive.relative_to(repo_root)}")
    if args.release_artifact_only:
        print(f"[openbabel] cleaned: {(build_root / 'obj').relative_to(repo_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

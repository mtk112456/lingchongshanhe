#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 handover/ 打成跨平台 zip（统一正斜杠路径）。"""
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent
HANDOVER = ROOT / "handover"
FULL = ROOT / "Qingzhu_Lingchong_Handover_20261109_dev_full.zip"
DOCS = ROOT / "Qingzhu_Lingchong_Handover_20261109_dev_docs.zip"


def files_for(full: bool):
    for path in sorted(HANDOVER.rglob("*")):
        if not path.is_file():
            continue
        if "__pycache__" in path.parts:
            continue
        rel = path.relative_to(HANDOVER).as_posix()
        if not full and (rel.startswith("build/") or rel.startswith("client/assets/")):
            continue
        yield path, rel


def write_zip(path: Path, full: bool):
    if path.exists():
        path.unlink()
    count = 0
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for src, rel in files_for(full):
            z.write(src, rel)
            count += 1
    print(f"{path.name}: {count} files, {path.stat().st_size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    write_zip(FULL, True)
    write_zip(DOCS, False)

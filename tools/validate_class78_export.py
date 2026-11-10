"""Validate the 78-class CSV export before importing into qingzhu_slice_trial.

Usage:
  python tools/validate_class78_export.py
  python tools/validate_class78_export.py --dir trial_data/class78

It never writes to the database. It only checks files and prints a summary.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DIR = ROOT / "trial_data" / "class78"


def read_csv(path: Path) -> tuple[list[str], list[dict]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = [dict(r) for r in reader]
        return list(reader.fieldnames or []), rows


def norm(value) -> str:
    return str(value or "").strip()


def validate(folder: Path) -> dict:
    result = {
        "folder": str(folder),
        "files": {},
        "errors": [],
        "warnings": [],
        "students": 0,
        "pets": 0,
        "templates": 0,
    }

    required = ["students.csv", "student_pets.csv", "pet_templates.csv"]
    for name in required:
        p = folder / name
        result["files"][name] = p.is_file()
        if not p.is_file():
            result["errors"].append(f"missing {name}")
    if result["errors"]:
        return result

    s_head, students = read_csv(folder / "students.csv")
    p_head, pets = read_csv(folder / "student_pets.csv")
    t_head, templates = read_csv(folder / "pet_templates.csv")
    result["students"] = len(students)
    result["pets"] = len(pets)
    result["templates"] = len(templates)
    result["headers"] = {
        "students": s_head,
        "student_pets": p_head,
        "pet_templates": t_head,
    }

    s_ids = set()
    s_names = set()
    for i, row in enumerate(students, start=2):
        sid = norm(row.get("id"))
        name = norm(row.get("name") or row.get("show_name"))
        if not sid:
            result["errors"].append(f"students.csv line {i}: empty id")
            continue
        if sid in s_ids:
            result["errors"].append(f"students.csv line {i}: duplicate id {sid}")
        s_ids.add(sid)
        if not name:
            result["errors"].append(f"students.csv line {i}: empty name/show_name")
        if name:
            s_names.add(name)
        score = norm(row.get("score"))
        if score and not score.lstrip("-").isdigit():
            result["warnings"].append(f"students.csv line {i}: score is not an integer: {score}")
        if not norm(row.get("password")):
            result["warnings"].append(f"students.csv line {i}: empty password (temporary password will be used)")

    if result["students"] < 8:
        result["errors"].append(f"need at least 8 students, got {result['students']}")
    if result["students"] > 12:
        result["warnings"].append(f"{result['students']} students; the trial should select 8-12")

    template_codes = set()
    for i, row in enumerate(templates, start=2):
        code = norm(row.get("code"))
        if not code:
            result["errors"].append(f"pet_templates.csv line {i}: empty code")
        elif code in template_codes:
            result["errors"].append(f"pet_templates.csv line {i}: duplicate code {code}")
        template_codes.add(code)

    pet_owner = {}
    for i, row in enumerate(pets, start=2):
        sid = norm(row.get("student_id"))
        code = norm(row.get("pet_code") or row.get("code"))
        if sid not in s_ids:
            result["warnings"].append(f"student_pets.csv line {i}: student_id {sid} not in students.csv")
        if code and template_codes and code not in template_codes:
            result["warnings"].append(f"student_pets.csv line {i}: pet_code {code} not in pet_templates.csv")
        pet_owner.setdefault(sid, 0)
        pet_owner[sid] += 1

    missing_pet = [sid for sid in s_ids if pet_owner.get(sid, 0) == 0]
    if missing_pet:
        result["errors"].append("students without pets: " + ", ".join(missing_pet[:20]))

    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default=str(DEFAULT_DIR))
    args = parser.parse_args()
    folder = Path(args.dir)
    result = validate(folder)

    print(json.dumps(result, ensure_ascii=False, indent=2))
    out = folder / "VALIDATION.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

    if result["errors"]:
        print("\nNOT READY:", "; ".join(result["errors"]))
        raise SystemExit(1)
    print("\nREADY:", result["students"], "students,", result["pets"], "pets,", result["templates"], "templates")


if __name__ == "__main__":
    main()

"""Read two already-exported Preset XML files; never touch grandMA3 show data."""
from __future__ import annotations

import argparse
from pathlib import Path
import xml.etree.ElementTree as ET


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def flatten(node: ET.Element, prefix: str = "") -> dict[str, str]:
    result = {prefix + "@" + key: value for key, value in node.attrib.items()}
    if node.text and node.text.strip():
        result[prefix + "#text"] = node.text.strip()
    counts: dict[str, int] = {}
    for child in node:
        tag = local(child.tag)
        counts[tag] = counts.get(tag, 0) + 1
        result.update(flatten(child, prefix + tag + "[" + str(counts[tag]) + "]/"))
    return result


def sources(path: Path) -> dict[str, dict[str, str]]:
    root = ET.parse(path).getroot()
    found: dict[str, dict[str, str]] = {}
    recipes = [node for node in root.iter() if local(node.tag) == "PhaserRecipe"]
    for recipe_index, recipe in enumerate(recipes, 1):
        steps = [node for node in recipe.iter() if local(node.tag) == "PhaserRecipeStep"]
        for step_index, step in enumerate(steps, 1):
            values = [node for node in step.iter() if local(node.tag) == "PhaserRecipeValueSource"]
            for source_index, value in enumerate(values, 1):
                key = f"recipe={recipe_index}/step={step_index}/source={source_index}"
                found[key] = flatten(value)
    return found


def related(field: str) -> bool:
    key = field.lower()
    if "abs" in key and "rel" not in key:
        return False
    return any(word in key for word in ("raw", "value", "rel", "layer", "mask", "active", "mode", "stor", "author", "flag", "own"))


def compare(a: Path, b: Path, a_repeat: Path | None = None,
            b_repeat: Path | None = None) -> tuple[str, str]:
    left, right = sources(a), sources(b)
    if not left or left.keys() != right.keys():
        return "INCONCLUSIVE", "SERIALIZED_VALUESOURCE_STRUCTURE_MISMATCH"
    repeat_left = sources(a_repeat) if a_repeat else None
    repeat_right = sources(b_repeat) if b_repeat else None
    if (repeat_left is None) != (repeat_right is None):
        return "INCONCLUSIVE", "REPEAT_EXPORT_PAIR_INCOMPLETE"
    if repeat_left is not None and (repeat_left != left or repeat_right != right):
        return "INCONCLUSIVE", "SERIALIZED_REEXPORT_NOT_STABLE"
    differences = []
    semantic = []
    absolute_changed = []
    for key in sorted(left):
        raw_a = left[key].get("@RawValueRel", "<omitted>")
        raw_b = right[key].get("@RawValueRel", "<omitted>")
        print(f"GROUND_TRUTH_SERIALIZATION_CASE case=A key={key} raw_rel_property={raw_a} exported_representation={left[key]}")
        print(f"GROUND_TRUTH_SERIALIZATION_CASE case=B key={key} raw_rel_property={raw_b} exported_representation={right[key]}")
        for field in sorted(left[key].keys() | right[key].keys()):
            av, bv = left[key].get(field, "<omitted>"), right[key].get(field, "<omitted>")
            if av != bv:
                differences.append(key + ":" + field)
                if "abs" in field.lower() and "rel" not in field.lower():
                    absolute_changed.append(key + ":" + field)
                if related(field):
                    semantic.append(key + ":" + field)
                print(f"GROUND_TRUTH_PROPERTY_DIFF source=SERIALIZATION key={key} field={field} A={av} B={bv} repeatable={repeat_left is not None}")
    if not differences:
        return "INCONCLUSIVE", "NO_SERIALIZED_VALUESOURCE_DIFF;NATIVE_COMPARISON_REQUIRED"
    if absolute_changed:
        return "INCONCLUSIVE", "ABS_CONTROL_DIFFERENCE:" + ",".join(absolute_changed)
    if semantic and repeat_left is not None:
        return "DISCRIMINATOR_PROVEN", "STABLE_SERIALIZED_VALUESOURCE_DIFF:" + ",".join(semantic)
    return "INCONCLUSIVE", "SERIALIZATION_DIFF_OBSERVED;NATIVE_OR_REEXPORT_CORROBORATION_REQUIRED:" + ",".join(differences)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--a", type=Path, required=True, help="existing export of the known blank-REL control")
    parser.add_argument("--b", type=Path, required=True, help="existing export of the authored-zero copy")
    parser.add_argument("--a-repeat", type=Path)
    parser.add_argument("--b-repeat", type=Path)
    args = parser.parse_args()
    try:
        classification, evidence = compare(args.a, args.b, args.a_repeat, args.b_repeat)
    except (OSError, ET.ParseError, ValueError) as error:
        classification, evidence = "INCONCLUSIVE", str(error).replace("\n", " ")
    print(f"RAW_REL_GROUND_TRUTH_RESULT classification={classification} evidence={evidence} source=EXISTING_EXPORTS_ONLY")


if __name__ == "__main__":
    main()

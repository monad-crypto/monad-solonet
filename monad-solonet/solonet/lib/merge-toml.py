#!/usr/bin/env python3
"""Deep-merge a TOML patch file into a TOML base file (in-place).

Usage: merge-toml.py <base.toml> <patch.toml>

Keys present in the patch override those in the base; nested tables are
merged recursively.  The merged result is written back to <base.toml>.
"""
import sys
import tomllib


def deep_merge(base: dict, patch: dict) -> None:
    for k, v in patch.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            deep_merge(base[k], v)
        else:
            base[k] = v


def toml_scalar(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        s = repr(v)
        # Ensure there is always a decimal point so TOML parses it as a float
        return s if ("." in s or "e" in s or "E" in s) else s + ".0"
    if isinstance(v, str):
        escaped = v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    if isinstance(v, list):
        if not v or not isinstance(v[0], dict):
            return "[" + ", ".join(toml_scalar(i) for i in v) + "]"
        raise ValueError("array-of-tables must not be serialised as a scalar")
    raise TypeError(f"unsupported TOML value type: {type(v)}")


def write_section(data: dict, key_prefix: str, output: list) -> None:
    """Append lines for *data* to *output*, using *key_prefix* for header names."""
    scalars = {}
    subtables = {}
    array_tables = {}

    for k, v in data.items():
        if isinstance(v, dict):
            subtables[k] = v
        elif isinstance(v, list) and v and isinstance(v[0], dict):
            array_tables[k] = v
        else:
            scalars[k] = v

    for k, v in scalars.items():
        output.append(f"{k} = {toml_scalar(v)}")

    for k, v in subtables.items():
        full_key = f"{key_prefix}.{k}" if key_prefix else k
        # Only emit an explicit [table] header when there are inline scalars;
        # otherwise the [[array.of.tables]] children implicitly create the parent.
        has_scalars = any(
            not isinstance(sv, dict)
            and not (isinstance(sv, list) and sv and isinstance(sv[0], dict))
            for sv in v.values()
        )
        if has_scalars:
            output.append(f"\n[{full_key}]")
        write_section(v, full_key, output)

    for k, v in array_tables.items():
        full_key = f"{key_prefix}.{k}" if key_prefix else k
        for item in v:
            output.append(f"\n[[{full_key}]]")
            write_section(item, full_key, output)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <base.toml> <patch.toml>", file=sys.stderr)
        sys.exit(1)

    base_file, patch_file = sys.argv[1], sys.argv[2]

    with open(base_file, "rb") as f:
        base = tomllib.load(f)

    with open(patch_file, "rb") as f:
        patch = tomllib.load(f)

    deep_merge(base, patch)

    lines: list[str] = []
    write_section(base, "", lines)

    with open(base_file, "w") as f:
        f.write("\n".join(lines) + "\n")

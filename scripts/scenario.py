#!/usr/bin/env python3

from __future__ import annotations

import argparse
import ipaddress
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tomllib
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCENARIOS_DIR = ROOT / "scenarios"
GENERATED_DIR = ROOT / "generated"
SOLONET_BUILD_CONTEXT = ROOT / "monad-solonet"
PORT_STRIDE = 100
NODE_IP_OFFSET = 10
DEFAULT_KEYSTORE_PASSWORD = "password"
DEFAULT_STAKE_UNIT = 100_000
DEFAULT_SUBNET = "172.21.0.0/24"
DEFAULT_PORT_BASE = 48080
DEFAULT_DEVICE_ID_START = 40

VALID_NODE_TYPES = {"validator", "dedicated", "public"}
VALID_PROFILE_KINDS = {"default", "custom"}
VALID_BINARY_ORIGINS = {"image", "local"}
SERVICE_OVERRIDE_TARGETS = {
    "monad_bft": "/solonet/services/monad-bft.ini",
    "monad_execution": "/solonet/services/monad-execution.ini",
    "monad_rpc": "/solonet/services/monad-rpc.ini",
}


class ScenarioError(RuntimeError):
    pass


def yaml_scalar(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if value is None:
        return "null"
    text = str(value)
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def dump_yaml(data: Any, indent: int = 0) -> str:
    pad = " " * indent
    if isinstance(data, dict):
        lines: list[str] = []
        for key, value in data.items():
            if isinstance(value, (dict, list)):
                lines.append(f"{pad}{key}:")
                lines.append(dump_yaml(value, indent + 2))
            else:
                lines.append(f"{pad}{key}: {yaml_scalar(value)}")
        return "\n".join(lines)
    if isinstance(data, list):
        lines = []
        for item in data:
            if isinstance(item, (dict, list)):
                dumped = dump_yaml(item, indent + 2).splitlines()
                if dumped:
                    lines.append(f"{pad}- {dumped[0].lstrip()}")
                    lines.extend(" " * (indent + 2) + line.lstrip() for line in dumped[1:])
                else:
                    lines.append(f"{pad}-")
            else:
                lines.append(f"{pad}- {yaml_scalar(item)}")
        return "\n".join(lines)
    return f"{pad}{yaml_scalar(data)}"


def load_scenario(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    validate_scenario(data, path)
    return data


def scenario_name_from_path(path: Path) -> str:
    return path.stem


def validate_scenario(data: dict[str, Any], path: Path) -> None:
    if not isinstance(data, dict):
        raise ScenarioError(f"{path}: scenario must be a TOML table")

    for field in ("name", "profiles", "nodes"):
        if field not in data:
            raise ScenarioError(f"{path}: missing required field '{field}'")

    if not isinstance(data["profiles"], dict) or not data["profiles"]:
        raise ScenarioError(f"{path}: profiles must be a non-empty table")
    if not isinstance(data["nodes"], list) or not data["nodes"]:
        raise ScenarioError(f"{path}: nodes must be a non-empty array")

    seen_profiles: set[str] = set()
    for profile_name, profile in data["profiles"].items():
        if profile_name in seen_profiles:
            raise ScenarioError(f"{path}: duplicate profile '{profile_name}'")
        seen_profiles.add(profile_name)

        if not isinstance(profile, dict):
            raise ScenarioError(f"{path}: profile '{profile_name}' must be a table")

        profile_kind = profile.get("profile_kind")
        if profile_kind not in VALID_PROFILE_KINDS:
            raise ScenarioError(
                f"{path}: profile '{profile_name}' has invalid profile_kind '{profile_kind}'"
            )

        binary_origin = profile.get("binary_origin", "image")
        if binary_origin not in VALID_BINARY_ORIGINS:
            raise ScenarioError(
                f"{path}: profile '{profile_name}' has invalid binary_origin '{binary_origin}'"
            )

        if profile_kind == "default" and binary_origin != "image":
            raise ScenarioError(
                f"{path}: profile '{profile_name}' is default but binary_origin is '{binary_origin}'"
            )

        if profile_kind == "custom" and binary_origin == "local":
            if not any(profile.get(key) for key in ("monad_node", "monad", "monad_rpc")):
                raise ScenarioError(
                    f"{path}: custom profile '{profile_name}' with local binaries must set at least one binary path"
                )

        env = profile.get("env", {})
        if env and not isinstance(env, dict):
            raise ScenarioError(f"{path}: profile '{profile_name}'.env must be a table")

        service_overrides = profile.get("service_overrides", {})
        if service_overrides and not isinstance(service_overrides, dict):
            raise ScenarioError(
                f"{path}: profile '{profile_name}'.service_overrides must be a table"
            )

        mounts = profile.get("mounts", [])
        if mounts and not isinstance(mounts, list):
            raise ScenarioError(f"{path}: profile '{profile_name}'.mounts must be an array")

    seen_ids: set[int] = set()
    profiles = data["profiles"]
    for node in data["nodes"]:
        if not isinstance(node, dict):
            raise ScenarioError(f"{path}: each node must be a table")

        node_id = node.get("id")
        if not isinstance(node_id, int) or node_id <= 0:
            raise ScenarioError(f"{path}: node id must be a positive integer")
        if node_id in seen_ids:
            raise ScenarioError(f"{path}: duplicate node id {node_id}")
        seen_ids.add(node_id)

        node_type = node.get("node_type")
        if node_type not in VALID_NODE_TYPES:
            raise ScenarioError(
                f"{path}: node {node_id} has invalid node_type '{node_type}'"
            )

        profile_name = node.get("profile")
        if profile_name not in profiles:
            raise ScenarioError(
                f"{path}: node {node_id} references unknown profile '{profile_name}'"
            )

        stake_weight = node.get("stake_weight", 1)
        if not isinstance(stake_weight, int) or stake_weight <= 0:
            raise ScenarioError(
                f"{path}: node {node_id} has invalid stake_weight '{stake_weight}'"
            )
        node["stake_weight"] = stake_weight


def ensure_parent_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def resolve_binary_mount(profile_name: str, binary_name: str) -> str:
    return f"/opt/solonet/custom/{profile_name}/{binary_name}"


def render_compose(scenario_path: Path) -> Path:
    scenario = load_scenario(scenario_path)
    scenario_name = scenario["name"]
    subnet = ipaddress.ip_network(scenario.get("subnet", DEFAULT_SUBNET))
    port_base = int(scenario.get("port_base", DEFAULT_PORT_BASE))
    device_id_start = int(scenario.get("device_id_start", DEFAULT_DEVICE_ID_START))
    keystore_password = scenario.get("keystore_password", DEFAULT_KEYSTORE_PASSWORD)
    stake_unit = int(scenario.get("stake_unit", DEFAULT_STAKE_UNIT))

    compose: dict[str, Any] = {
        "volumes": {"shared-data": {}},
        "networks": {
            "solonet": {
                "driver": "bridge",
                "ipam": {"config": [{"subnet": str(subnet)}]},
            }
        },
        "services": {
            "init": {
                "container_name": f"{scenario_name}-init",
                "build": str(SOLONET_BUILD_CONTEXT),
                "command": ["setup-monad-sysctl.sh"],
                "privileged": True,
                "network_mode": "host",
                "volumes": ["/:/host"],
            }
        },
    }

    total_nodes = len(scenario["nodes"])
    for node in scenario["nodes"]:
        node_id = node["id"]
        profile_name = node["profile"]
        profile = scenario["profiles"][profile_name]
        profile_kind = profile["profile_kind"]
        binary_origin = profile.get("binary_origin", "image")

        host_rpc_port = port_base + (node_id - 1) * PORT_STRIDE
        container_ip = str(subnet.network_address + NODE_IP_OFFSET + node_id)
        service_name = f"solonet-node-{node_id}"

        env: dict[str, Any] = {
            "KEYSTORE_PASSWORD": keystore_password,
            "NODE_ID": node_id,
            "NODE_TYPE": node["node_type"],
            "TOTAL_NODE_NUMBER": total_nodes,
            "DEVICE_ID_START": device_id_start,
            "PROFILE_NAME": profile_name,
            "PROFILE_KIND": profile_kind,
            "STAKE_WEIGHT": node["stake_weight"],
            "STAKING_REGISTER_AMOUNT": stake_unit,
            "STAKING_DELEGATE_AMOUNT": stake_unit * node["stake_weight"],
        }

        volumes = ["shared-data:/shared"]

        if binary_origin == "local":
            binary_map = {
                "monad_node": "monad-node",
                "monad": "monad",
                "monad_rpc": "monad-rpc",
            }
            env_key_map = {
                "monad_node": "MONAD_NODE_BIN",
                "monad": "MONAD_EXEC_BIN",
                "monad_rpc": "MONAD_RPC_BIN",
            }
            for profile_key, binary_name in binary_map.items():
                source = profile.get(profile_key)
                if not source:
                    continue
                mount_target = resolve_binary_mount(profile_name, binary_name)
                volumes.append(f"{Path(source).resolve()}:{mount_target}:ro")
                env[env_key_map[profile_key]] = mount_target

        chain_override = profile.get("chain_override")
        if chain_override:
            target = f"/opt/solonet/custom/{profile_name}/chain-override.toml"
            volumes.append(f"{Path(chain_override).resolve()}:{target}:ro")
            extra = shlex.split(str(env.get("MONAD_NODE_EXTRA_ARGS", "")))
            extra.append(f"--devnet-chain-config-override={target}")
            env["MONAD_NODE_EXTRA_ARGS"] = " ".join(extra)

        for service_key, target in SERVICE_OVERRIDE_TARGETS.items():
            override_path = profile.get("service_overrides", {}).get(service_key)
            if override_path:
                volumes.append(f"{Path(override_path).resolve()}:{target}:ro")

        for mount in profile.get("mounts", []):
            source = Path(mount["source"]).resolve()
            target = mount["target"]
            mode = mount.get("mode", "ro")
            volumes.append(f"{source}:{target}:{mode}")

        for key, value in profile.get("env", {}).items():
            env[key] = value

        service = {
            "container_name": f"{scenario_name}-{service_name}",
            "build": str(SOLONET_BUILD_CONTEXT),
            "depends_on": {"init": {"condition": "service_completed_successfully"}},
            "networks": {"solonet": {"ipv4_address": container_ip}},
            "privileged": True,
            "ports": [
                f"{host_rpc_port}:8080",
                f"{host_rpc_port + 1}:8081",
                f"{host_rpc_port + 2}:8082",
            ],
            "ulimits": {"nofile": {"soft": 16384, "hard": 16384}},
            "volumes": volumes,
            "environment": env,
        }

        compose["services"][service_name] = service

    output_dir = GENERATED_DIR / scenario_name
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "docker-compose.yaml"
    output_path.write_text(dump_yaml(compose) + "\n", encoding="utf-8")
    return output_path


def resolve_generated_compose(scenario_path: Path) -> Path:
    scenario = load_scenario(scenario_path)
    return GENERATED_DIR / scenario["name"] / "docker-compose.yaml"


def run_command(cmd: list[str], cwd: Path | None = None) -> None:
    subprocess.run(cmd, cwd=cwd, check=True)


def check_ports_free(compose_path: Path) -> None:
    content = compose_path.read_text(encoding="utf-8")
    used_ports: list[int] = []
    port_pattern = re.compile(r'^\s*-\s*"?(?P<host>\d+):(8080|8081|8082)"?\s*$')
    for line in content.splitlines():
        match = port_pattern.match(line)
        if match:
            used_ports.append(int(match.group("host")))

    busy_ports = []
    for port in used_ports:
        try:
            import socket

            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                if sock.connect_ex(("127.0.0.1", port)) == 0:
                    busy_ports.append(port)
        except OSError:
            busy_ports.append(port)

    if busy_ports:
        raise ScenarioError(f"ports already in use: {', '.join(str(p) for p in busy_ports)}")


def count_available_loop_devices(start_id: int, node_ids: list[int]) -> None:
    missing = []
    for node_id in node_ids:
        loop_path = Path(f"/dev/loop{start_id + node_id}")
        if not loop_path.exists():
            missing.append(str(loop_path))
    if missing:
        raise ScenarioError(f"missing loop devices: {', '.join(missing)}")


def preflight(scenario_path: Path, compose_path: Path) -> None:
    scenario = load_scenario(scenario_path)
    check_ports_free(compose_path)
    count_available_loop_devices(
        int(scenario.get("device_id_start", DEFAULT_DEVICE_ID_START)),
        [node["id"] for node in scenario["nodes"]],
    )

    for profile_name, profile in scenario["profiles"].items():
        for key in ("monad_node", "monad", "monad_rpc", "chain_override"):
            path = profile.get(key)
            if path and not Path(path).exists():
                raise ScenarioError(
                    f"profile '{profile_name}' references missing path for {key}: {path}"
                )
        for override_key, override_path in profile.get("service_overrides", {}).items():
            if not Path(override_path).exists():
                raise ScenarioError(
                    f"profile '{profile_name}' references missing service override for {override_key}: {override_path}"
                )
        for mount in profile.get("mounts", []):
            source = Path(mount["source"])
            if not source.exists():
                raise ScenarioError(
                    f"profile '{profile_name}' references missing mount source: {source}"
                )


def docker_compose_base(compose_path: Path, project_name: str) -> list[str]:
    return ["docker", "compose", "-f", str(compose_path), "-p", project_name]


def project_name_for(scenario_path: Path) -> str:
    return load_scenario(scenario_path)["name"]


def write_scenario_template(
    output_path: Path,
    name: str,
    validators: int,
    custom_specs: list[str],
    subnet: str,
    port_base: int,
    device_id_start: int,
    stake_unit: int,
) -> None:
    if validators <= 0:
        raise ScenarioError("--validators must be positive")

    groups: list[tuple[str, int, int]] = []
    assigned_nodes = 0
    assigned_weight = 0
    for spec in custom_specs:
        try:
            profile_name, remainder = spec.split("=", 1)
            count_text, weight_text = remainder.split(":", 1)
            count = int(count_text)
            weight = int(weight_text)
        except ValueError as exc:
            raise ScenarioError(
                f"invalid --custom-profile '{spec}', expected NAME=COUNT:TOTAL_WEIGHT"
            ) from exc

        if count <= 0 or weight <= 0:
            raise ScenarioError(
                f"invalid --custom-profile '{spec}', COUNT and TOTAL_WEIGHT must be positive"
            )
        if weight < count:
            raise ScenarioError(
                f"invalid --custom-profile '{spec}', TOTAL_WEIGHT ({weight}) "
                f"must be >= COUNT ({count}) so every node gets a positive stake_weight"
            )
        groups.append((profile_name, count, weight))
        assigned_nodes += count
        assigned_weight += weight

    if assigned_nodes > validators:
        raise ScenarioError("custom profile groups exceed total validators")

    default_count = validators - assigned_nodes
    default_weight = max(default_count, 1) if default_count else 0

    lines: list[str] = [
        f'name = "{name}"',
        f'subnet = "{subnet}"',
        f"port_base = {port_base}",
        f"device_id_start = {device_id_start}",
        f"stake_unit = {stake_unit}",
        "",
        "[profiles.default]",
        'profile_kind = "default"',
        'binary_origin = "image"',
        "",
    ]

    for profile_name, _, _ in groups:
        lines.extend(
            [
                f"[profiles.{profile_name}]",
                'profile_kind = "custom"',
                'binary_origin = "local"',
                f'monad_node = "/home/ubuntu/monad-bft/.worktrees/{profile_name}/target/release/monad-node"',
                f'monad = "/home/ubuntu/monad/.worktrees/{profile_name}/build/cmd/monad"',
                "",
                f"[profiles.{profile_name}.env]",
                f'{profile_name.upper()}_ENABLED = "1"',
                "",
            ]
        )

    next_id = 1
    for profile_name, count, total_weight in groups:
        base = total_weight // count
        remainder = total_weight % count
        for index in range(count):
            stake_weight = base + (1 if index < remainder else 0)
            lines.extend(
                [
                    "[[nodes]]",
                    f"id = {next_id}",
                    'node_type = "validator"',
                    f'profile = "{profile_name}"',
                    f"stake_weight = {stake_weight}",
                    "",
                ]
            )
            next_id += 1

    for _ in range(default_count):
        lines.extend(
            [
                "[[nodes]]",
                f"id = {next_id}",
                'node_type = "validator"',
                'profile = "default"',
                "stake_weight = 1",
                "",
            ]
        )
        next_id += 1

    ensure_parent_dir(output_path)
    output_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render and operate scenario-based solonet networks")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="write a scenario template")
    init_parser.add_argument("--name", required=True, help="scenario name")
    init_parser.add_argument(
        "--output",
        help="output path for the scenario TOML (defaults to scenarios/<name>.toml)",
    )
    init_parser.add_argument(
        "--validators",
        type=int,
        default=3,
        help="number of validator nodes to generate",
    )
    init_parser.add_argument(
        "--custom-profile",
        action="append",
        default=[],
        help="profile group in the form NAME=COUNT:TOTAL_WEIGHT",
    )
    init_parser.add_argument("--subnet", default=DEFAULT_SUBNET)
    init_parser.add_argument("--port-base", type=int, default=DEFAULT_PORT_BASE)
    init_parser.add_argument(
        "--device-id-start", type=int, default=DEFAULT_DEVICE_ID_START
    )
    init_parser.add_argument("--stake-unit", type=int, default=DEFAULT_STAKE_UNIT)

    for name in ("render", "up", "down", "logs", "ps"):
        subparser = subparsers.add_parser(name)
        subparser.add_argument("scenario", help="path to a scenario TOML file")
        if name == "logs":
            subparser.add_argument("service", nargs="?", help="optional compose service name")

    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    try:
        if args.command == "init":
            output = (
                Path(args.output).resolve()
                if args.output
                else (SCENARIOS_DIR / f"{args.name}.toml")
            )
            write_scenario_template(
                output_path=output,
                name=args.name,
                validators=args.validators,
                custom_specs=args.custom_profile,
                subnet=args.subnet,
                port_base=args.port_base,
                device_id_start=args.device_id_start,
                stake_unit=args.stake_unit,
            )
            print(output)
            return 0

        scenario_path = Path(args.scenario).resolve()
        project_name = project_name_for(scenario_path)

        if args.command == "render":
            compose_path = render_compose(scenario_path)
            print(compose_path)
            return 0

        compose_path = render_compose(scenario_path)

        if args.command == "up":
            preflight(scenario_path, compose_path)
            run_command(docker_compose_base(compose_path, project_name) + ["up", "-d", "--build"])
            return 0

        if args.command == "down":
            run_command(docker_compose_base(compose_path, project_name) + ["down", "--volumes"])
            return 0

        if args.command == "logs":
            cmd = docker_compose_base(compose_path, project_name) + ["logs", "-f"]
            if args.service:
                cmd.append(args.service)
            run_command(cmd)
            return 0

        if args.command == "ps":
            run_command(docker_compose_base(compose_path, project_name) + ["ps"])
            return 0

        raise ScenarioError(f"unsupported command {args.command}")
    except ScenarioError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

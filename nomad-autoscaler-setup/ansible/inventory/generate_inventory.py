#!/usr/bin/env python3

import json
import os
import socket
import subprocess
import sys
from pathlib import Path


def terraform_outputs(terraform_dir: Path) -> dict:
    result = subprocess.run(
        ["terraform", f"-chdir={terraform_dir}", "output", "-json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def get_value(outputs: dict, key: str, default):
    output = outputs.get(key)
    if not output:
        return default
    return output.get("value", default)


def can_connect(host: str, port: int, timeout: float = 1.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def resolve_inventory_mode(nodes) -> str:
    # Supported values: auto (default), direct, orb
    mode = os.getenv("INVENTORY_SSH_MODE", "auto").strip().lower()
    if mode in {"direct", "orb"}:
        return mode

    for node in nodes[:3]:
        if can_connect(node["ssh_host"], int(node["ssh_port"])):
            return "direct"
    return "orb"


def host_map(nodes, mode: str, ansible_user: str):
    hosts = {}
    for node in nodes:
        name = node["name"]
        if mode == "orb":
            # Use OrbStack SSH mux host when direct bridge networking is unavailable.
            hosts[name] = {
                "ansible_host": "orb",
                "ansible_user": f"{ansible_user}@{name}",
                "node_ip": node["ssh_host"],
            }
        else:
            hosts[name] = {
                "ansible_host": node["ssh_host"],
                "ansible_port": node["ssh_port"],
                "node_ip": node["ssh_host"],
            }
    return hosts


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    ansible_dir = script_dir.parent
    project_root = ansible_dir.parent

    try:
        outputs = terraform_outputs(project_root)
    except subprocess.CalledProcessError as exc:
        print("Failed to read Terraform outputs. Run terraform apply first.", file=sys.stderr)
        print(exc.stderr, file=sys.stderr)
        return exc.returncode or 1

    servers = get_value(outputs, "server_vm_connections", [])
    clients = get_value(outputs, "client_vm_connections", [])
    prometheus = get_value(outputs, "prometheus_vm_connection", {})
    all_nodes = servers + clients + ([prometheus] if prometheus else [])

    ansible_user = os.getenv("ANSIBLE_USER", "root")
    mode = resolve_inventory_mode(all_nodes)
    default_key = "~/.orbstack/ssh/id_ed25519" if mode == "orb" else "~/.ssh/id_ed25519"
    ansible_key = os.getenv("ANSIBLE_PRIVATE_KEY_FILE", default_key)

    inventory = {
        "all": {
            "vars": {
                "ansible_user": ansible_user,
                "ansible_ssh_private_key_file": ansible_key,
            },
            "children": {
                "nomad_servers": {
                    "hosts": host_map(servers, mode, ansible_user),
                },
                "nomad_clients": {
                    "hosts": host_map(clients, mode, ansible_user),
                },
                "prometheus": {
                    "hosts": host_map([prometheus], mode, ansible_user) if prometheus else {},
                },
            }
        }
    }

    hosts_path = script_dir / "hosts.yml"
    hosts_path.write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")

    print(f"Inventory generated at {hosts_path} (mode={mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

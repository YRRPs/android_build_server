#!/usr/bin/env python3
import json
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def test_compose_contract() -> None:
    env = os.environ | {
        "SSH_AUTHORIZED_KEYS": "ssh-ed25519 AAAA_SYNTHETIC test",
        "YRRP_PROJECT_PATH": str(ROOT),
    }
    rendered = subprocess.run(
        [
            "docker",
            "compose",
            "--project-directory",
            str(ROOT),
            "-f",
            str(ROOT / "docker-compose.yml"),
            "config",
            "--format",
            "json",
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    config = json.loads(rendered.stdout)
    builder = config["services"]["builder"]
    volumes = {volume["target"]: volume for volume in builder["volumes"]}
    assert volumes["/var/run/docker.sock"]["source"] == "/var/run/docker.sock"
    assert volumes["/opt/yrrp/project"]["read_only"] is True
    assert volumes["/opt/yrrp/signing"].get("read_only", False) is False
    assert builder["environment"]["YRRP_CERT_DIR"] == "/opt/yrrp/signing"
    assert builder["environment"]["OTA_NETWORK"] == "proxy-net"
    assert builder["image"] == "ghcr.io/yim-s-riced-rom-project/android-build-server:main"


def test_workflow_contract() -> None:
    workflow = (ROOT / ".github/workflows/container.yml").read_text()
    assert re.search(r"(?m)^permissions:\s*\{\}\s*$", workflow)
    assert "pull_request:" in workflow
    assert "packages: write" in workflow
    assert "provenance: mode=max" in workflow
    assert "sbom: true" in workflow
    for action in re.findall(r"(?m)^\s*uses:\s*([^\s#]+)", workflow):
        assert re.fullmatch(r"[^@]+@[0-9a-f]{40}", action), action


if __name__ == "__main__":
    test_compose_contract()
    test_workflow_contract()
    print("Builder configuration contract passed")

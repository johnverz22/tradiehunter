"""Shared building blocks for the unified E2E flows (docs/todos/12_e2e_flow_unification_plan.md).

stdlib only. Modules:
  api      HTTP helpers, polling, uploads (raising, Decimal-aware) + a non-raising `http`
  asserts  decimal money, status-order and audit-trail assertions
  stage    signal server, Show/timeline, console log, sim screenshots, screen recording, actors
  sims     simulator discovery and window arrangement
  fabric   persona-fabric provisioning, manifest loading, cleanup, job recording
  report   timeline report + JUnit writer
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
MOBILE = REPO / "mobile"
WEB = REPO / "web"
SCRIPTS = REPO / "scripts"

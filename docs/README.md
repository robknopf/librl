# Documentation

| Doc | Audience | Purpose |
|-----|----------|---------|
| [API.md](API.md) | Integrators | Public C API reference (`include/*.h`) |
| [BINDINGS.md](BINDINGS.md) | Binding authors | JS, Haxe, Nim, and Lua binding conventions |
| [MAINTAINER.md](MAINTAINER.md) | Maintainers | Build matrix, repo conventions, gotchas, current architecture |
| [ROADMAP.md](ROADMAP.md) | Maintainers | Work tracking — **now / next / backlog / research / parked / done** (includes binding parity gap table) |

Repo root [AGENTS.md](../AGENTS.md) defines the agent/editor contract (binding parity, API docs, commit policy).

**Binding tooling:** `tools/audit_binding_parity.py`, `tools/gen_binding_versions.py`, `tools/gen_librl_dts.py`, `tools/gen_haxe_public_sections.py` — see [MAINTAINER.md](MAINTAINER.md) § Tools (Python-first policy).

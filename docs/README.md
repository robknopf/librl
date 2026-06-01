# Documentation

| Doc | Audience | Purpose |
|-----|----------|---------|
| [API.md](API.md) | Integrators | Public C API reference (`include/*.h`) |
| [BINDINGS.md](BINDINGS.md) | Binding authors | JS, Haxe, Nim, and Lua binding conventions |
| [MAINTAINER.md](MAINTAINER.md) | Maintainers | Build matrix, repo conventions, gotchas, current architecture |
| [ROADMAP.md](ROADMAP.md) | Maintainers | Work tracking — **now / next / backlog / research / parked / done** |
| [design/rl_scene.md](design/rl_scene.md) | Maintainers / agents | **Design / implementation notes** — retained `rl_scene` layer, layer ordering, and 3D pass behavior |

Repo root [AGENTS.md](../AGENTS.md) defines the agent/editor contract (binding parity, API docs, commit policy).

**Binding tooling:** `tools/audit_binding_parity.py`, `tools/gen_binding_versions.py`, `bindings/js/package.json` (`npm run build`), `tools/gen_haxe_public_sections.py` — see [MAINTAINER.md](MAINTAINER.md) § Tools (Python-first policy for repo tooling; JS binding build uses npm scripts in `bindings/js/`).

# The Collective — Claude Code Plugin (`collective`)

A [Claude Code plugin](https://code.claude.com/docs/en/plugins) that installs
The Collective's operator **safety floor** and the `c-*` workflow skills with a
single command, with automatic updates through the plugin marketplace.

> **Status: SAFETY FLOOR ONLY (v0.1.0).**
> This first cut ships *only* the two safety hooks (catastrophic-command
> denylist + protected-file guard) and the `c-*` skills. The telemetry,
> session-context, and knowledge-nudge hooks (`session-start`, `post-tool-use`,
> `user-prompt-submit`, `stop`, `notification`) are intentionally **not** bundled
> yet — they come after the H2 server-ification work. The MCP server is also not
> bundled here; operators still configure it separately.

## What it bundles

| Component | Path | Purpose |
|---|---|---|
| Safety hook — Bash | `hooks/pre-tool-use` | `PreToolUse` on `Bash`. Client-side catastrophic-command denylist (`rm -rf /`, `DROP DATABASE`, fork bomb, `dd` to a raw disk, `mkfs`, recursive `chmod`/`chown` on `/`, force-push to `main`/`master`/`prod`, `_prisma_migrations` tampering), then server-side validation when configured. |
| Safety hook — file guard | `hooks/safety-files-guard` | `PreToolUse` on `Edit\|Write\|MultiEdit`. Blocks direct edits to platform-safety files (`.claude/hooks/*`, `.mcp.json`, `.claude/settings.local.json`). |
| Skills | `skills/c-*` | The 10 `c-*` workflow skills: `c-where`, `c-ready`, `c-objective`, `c-complete`, `c-sync`, `c-health`, `c-items`, `c-stale`, `c-assess`, `c-ship`. |

The two hook scripts are **generated** from the single source of truth in
`backend/src/mcp-server/utils/hookGenerators.ts` via
`plugin/scripts/generate-plugin-hooks.ts`. They are generated project-ID-agnostic
(empty `projectId`) — the denylist and file guard are pure-local and need no
project. Do not hand-edit `hooks/pre-tool-use` or `hooks/safety-files-guard`;
regenerate instead:

```bash
cd backend && npx tsx ../plugin/scripts/generate-plugin-hooks.ts
```

## Install (operator)

The marketplace will be hosted in a **public** git repo — post-Fort-Knox, the
bundled hooks carry no secrets, so public hosting is safe. **That publish step is
deliberately NOT done here**; this is the in-repo skeleton only. Once published:

```
/plugin marketplace add <public-marketplace-repo>
/plugin install collective@collective
```

- `collective@collective` = plugin `collective` from the marketplace named
  `collective` (see `.claude-plugin/marketplace.json`).
- To test locally before publishing:
  ```bash
  claude --plugin-dir ./plugin
  ```

## Layout

```
plugin/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (name "collective", v0.1.0)
│   └── marketplace.json     # single-plugin marketplace (name "collective")
├── hooks/
│   ├── hooks.json           # wires the two PreToolUse safety hooks
│   ├── pre-tool-use         # GENERATED — catastrophic-command denylist
│   └── safety-files-guard   # GENERATED — protected-file guard
├── scripts/
│   └── generate-plugin-hooks.ts   # regenerates the two hooks from the backend generators
├── skills/
│   └── c-*/SKILL.md         # 10 c-* workflow skills
└── README.md
```

## Not yet done (follow-ups)

- Publish the marketplace to its public repo and wire `/plugin install` into onboarding.
- Bundle the telemetry / context hooks once H2 server-ification lands.
- Bundle the MCP server config (`.mcp.json`) for one-command MCP setup.

# agent-sessions

Zsh completion of session IDs for Claude Code, Codex and OpenCode.

```
$ opencode -s <Tab>
ses_e6c152051ffe59pT2E2KkrW6z1  -- Nov 1 10:16 · Add Windows support to the installer · my-project
```

| Command | Completes after |
|---|---|
| `claude` | `--resume` or `-r` |
| `codex` | `resume` |
| `opencode` | `--session` or `-s` |

Each session shows its local time and its title or first prompt, newest first, up to 120 for each tool. The plugin reads only local files and starts no agent. It makes no network requests:

- Claude Code: `~/.claude/projects/**/*.jsonl`
- Codex: `~/.codex/session_index.jsonl`
- OpenCode: `~/.local/share/opencode/opencode.db`, opened read-only

For other arguments, the command's own completion runs as before.

## Install

The plugin needs `python3`. Source it after `compinit`:

```zsh
source /path/to/agent-sessions/agent-sessions.plugin.zsh
```

Plugin managers that load `*.plugin.zsh` (antidote, zinit, Oh My Zsh custom plugins) can load the repo as is.

If you run `compinit` again later, also run `agent:session:complete:install` again. That puts the session completion back in place.

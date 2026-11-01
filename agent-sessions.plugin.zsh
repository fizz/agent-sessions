# Session completion for the three agents we actually use.  The stores are local;
# no agent is started, no network request is made, and the result is rebuilt on Tab.
typeset -gA _agent_session_original_completion

_agent:session:choices() {
  local kind=$1
  python - "$kind" <<'PY'
import glob, json, os, sqlite3, sys
from datetime import datetime

home = os.path.expanduser("~")
kind = sys.argv[1]
items = []

def clean(s, limit=72):
    s = " ".join(str(s or "").replace("\n", " ").split())
    return (s[:limit - 1] + "…") if len(s) > limit else s

def stamp(epoch):
    """A real local timestamp, compact enough for Zsh's completion menu."""
    try:
        return datetime.fromtimestamp(float(epoch)).strftime("%b %-d %H:%M")
    except (TypeError, ValueError, OSError):
        return "unknown time"

if kind == "claude":
    files = sorted(
        (p for p in glob.glob(home + "/.claude/projects/**/*.jsonl", recursive=True)
         if "/subagents/" not in p),
        key=os.path.getmtime, reverse=True,
    )[:120]
    for path in files:
        sid = os.path.basename(path)[:-6]
        label = ""
        try:
            with open(path, encoding="utf-8") as fh:
                for line in fh:
                    obj = json.loads(line)
                    msg = obj.get("message", {})
                    if msg.get("role") == "user":
                        content = msg.get("content", "")
                        if isinstance(content, list):
                            content = " ".join(x.get("text", "") for x in content if isinstance(x, dict))
                        label = clean(content)
                        if label:
                            break
                    if obj.get("type") == "queue-operation":
                        label = clean(obj.get("content"))
                        if label:
                            break
        except (OSError, ValueError):
            continue
        items.append((sid, stamp(os.path.getmtime(path)), label or "Claude session"))

elif kind == "opencode":
    path = home + "/.local/share/opencode/opencode.db"
    try:
        db = sqlite3.connect("file:" + path + "?mode=ro", uri=True)
        rows = db.execute("""
          select id, coalesce(nullif(title, ''), nullif(slug, ''), 'OpenCode session'),
                 directory, time_updated
          from session_v2 order by time_updated desc limit 120
        """)
        for sid, title, directory, updated in rows:
            where = os.path.basename(directory.rstrip("/")) if directory else ""
            items.append((sid, stamp(updated / 1000), clean(f"{title} · {where}")))
    except (sqlite3.Error, OSError):
        pass

elif kind == "codex":
    path = home + "/.codex/session_index.jsonl"
    try:
        with open(path, encoding="utf-8") as fh:
            rows = [json.loads(line) for line in fh if line.strip()]
        rows.sort(key=lambda row: row.get("updated_at", ""), reverse=True)
        for row in rows[:120]:
            sid = row.get("id")
            if sid:
                updated = datetime.fromisoformat(row.get("updated_at", "")).timestamp()
                items.append((sid, stamp(updated), clean(row.get("thread_name") or "Codex session")))
    except (OSError, ValueError):
        pass

seen = set()
for sid, updated, label in items:
    if sid not in seen:
        seen.add(sid)
        print(f"{sid}\t{updated} · {label}")
PY
}

_agent:session:complete() {
  local kind=$1 line id label
  local -a choices
  while IFS=$'\t' read -r id label; do
    [[ -n $id ]] && choices+=("${id}:${label}")
  done < <(_agent:session:choices "$kind")
  _describe -t sessions "$kind session" choices
}

_agent:session:fallback() {
  local command=$1 original=${_agent_session_original_completion[$1]}
  if [[ -n $original && $original != _${command}_session_complete ]]; then
    "$original"
  else
    _default
  fi
}

_claude_session_complete() {
  if (( CURRENT > 1 )) && [[ ${words[CURRENT-1]} == (--resume|-r) ]]; then
    _agent:session:complete claude
  else
    _agent:session:fallback claude
  fi
}

_codex_session_complete() {
  if [[ ${words[2]} == resume ]] && (( CURRENT == 3 )); then
    _agent:session:complete codex
  else
    _agent:session:fallback codex
  fi
}

_opencode_session_complete() {
  if (( CURRENT > 1 )) && [[ ${words[CURRENT-1]} == (--session|-s) ]]; then
    _agent:session:complete opencode
  else
    _agent:session:fallback opencode
  fi
}

agent:session:complete:install() {
  (( $+functions[compdef] )) || return 0
  local command original
  for command in claude codex opencode; do
    original=${_comps[$command]-}
    if [[ -n $original && $original != _${command}_session_complete ]]; then
      _agent_session_original_completion[$command]=$original
    fi
  done
  compdef _claude_session_complete claude
  compdef _codex_session_complete codex
  compdef _opencode_session_complete opencode
}

agent:session:complete:install

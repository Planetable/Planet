# /save-session — Claude Code Skill

Save Claude Code session summaries to [Planet](https://planetable.xyz) as articles for later review. One planet per project, one article per session.

## Setup

1. **Symlink into your Claude Code skills directory:**

```bash
ln -s ../../tools/claude-code-skill .claude/skills/save-session
```

2. **Edit `config.json`** — set your Planet server URL and map project paths to planet IDs:

```json
{
  "planet_server": "http://127.0.0.1:8086",
  "planets": {
    "/path/to/your/project": "YOUR-PLANET-UUID"
  }
}
```

Find your planet UUID by running:
```bash
curl -s http://127.0.0.1:8086/v0/planets/my | python3 -c "import json,sys; [print(f'{p[\"id\"]}  {p[\"name\"]}') for p in json.load(sys.stdin)]"
```

3. **Use it** — type `/save-session` in Claude Code at the end of a session.

## Requirements

- Python 3 (stdlib only, no pip packages needed)
- Planet app running with API enabled (default port 8086)

## Files

- `SKILL.md` — Claude Code skill definition
- `save_session.py` — Script that creates the Planet article
- `config.json` — Planet server and project-to-planet mapping

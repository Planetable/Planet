---
name: save-session
description: Save the current Codex session summary as a Planet article for later review. Use when the user asks to save, archive, or sync the current Codex session into Planet, updating the same article for the same Codex thread.
---

Save the current Codex session into Planet.

## 1. Write the summary

Write a concise HTML summary of the current session. Prefer these sections and omit any that would be empty:

```html
<h2>What was done</h2>
<ul>
<li>Important task or change</li>
</ul>

<h2>Key decisions</h2>
<ul>
<li>Decision and why it matters</li>
</ul>

<h2>Files changed</h2>
<ul>
<li><code>path/to/file</code> - short change summary</li>
</ul>

<h2>Verification</h2>
<ul>
<li>Builds, tests, or manual checks</li>
</ul>

<h2>Open follow-ups</h2>
<ul>
<li>Anything still worth doing later</li>
</ul>
```

Keep it focused on future review. Do not restate the full conversation.

## 2. Save it through the installed script

Pipe the HTML into the save script:

```bash
python3 /Users/livid/.codex/skills/save-session/scripts/save_session.py <<'HTML'
<the summary HTML>
HTML
```

The script:

- resolves the Planet from the current working directory
- derives the session title from the Codex thread metadata
- updates the existing article for the current `CODEX_THREAD_ID` if one already exists
- otherwise creates a new article in Planet

Because Codex's sandbox cannot reach the local Planet API, run the command with escalated permissions.

## 3. Confirm the result

Tell the user whether the article was created or updated and include the final title.

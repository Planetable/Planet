---
name: save-session
description: Save the current Claude Code session as a Planet article for later review
allowed-tools: Bash, Read
---

Save the current session to Planet. Follow these steps exactly:

## 1. Generate a session title

Create a short, descriptive title (under 80 chars) in this format:

```
YYYY-MM-DD Session: <brief description of what was done>
```

Use today's date. The description should capture the main theme (e.g., "Build release notes Flask app", "Fix search performance", "Add Planet API sync").

## 2. Write a session summary

Write an HTML summary of this session. Structure it as:

```html
<h2>What was done</h2>
<ul>
<li>Key task or change 1</li>
<li>Key task or change 2</li>
...
</ul>

<h2>Key decisions</h2>
<ul>
<li>Decision 1 and why</li>
...
</ul>

<h2>Files changed</h2>
<ul>
<li><code>path/to/file1</code> — what changed</li>
<li><code>path/to/file2</code> — what changed</li>
...
</ul>
```

Be concise. Focus on what matters for future review. Omit sections if they don't apply (e.g., skip "Key decisions" if there were none worth noting).

## 3. Save to Planet

Run the save script. The title, summary, and session ID must be passed as arguments. Use `$TERM_SESSION_ID` as the session identifier — it is stable for the entire terminal session. Use a heredoc for the summary to handle HTML safely:

```bash
TITLE="<the title>"
SUMMARY=$(cat <<'HTMLEOF'
<the summary HTML>
HTMLEOF
)
python3 tools/claude-code-skill/save_session.py "$TITLE" "$SUMMARY" "$TERM_SESSION_ID"
```

The script reads `tools/claude-code-skill/config.json` to find the Planet server and planet ID for the current project.

The script embeds the session ID in the article content and uses it to find existing articles from the same session. This means multiple `/save-session` calls in the same session update the same article, even if the title changes.

## 4. Confirm

Tell the user the article was created or updated, with the title. The article is viewable in the Planet app.

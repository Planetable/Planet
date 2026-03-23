import logging
import os
import queue
import re
import subprocess
import threading
import time

from flask import Flask, abort, jsonify, redirect, request, url_for
from jinja2 import BaseLoader, Environment

app = Flask(__name__)
log = logging.getLogger(__name__)

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
APP_DIR = os.path.dirname(os.path.abspath(__file__))
CHANNELS = ['release', 'insider']

# Background generation queue: items are (channel, tag) tuples.
_gen_queue = queue.Queue()
_generating = {}  # tag -> True while being generated
_NUM_WORKERS = 2

# Tags cache: { channel: (timestamp, [tags]) }
_tags_cache = {}
# Tag dates cache: { tag: "YYYY-MM-DD" }
_tag_dates_cache = {}
_tag_dates_ts = 0.0
_TAGS_TTL = 60

# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

def git(*args):
    result = subprocess.run(
        ['git', '-C', REPO_ROOT, *args],
        capture_output=True, text=True,
    )
    return result.stdout.strip()


def get_tags_for_channel(channel):
    cached = _tags_cache.get(channel)
    if cached and time.monotonic() - cached[0] < _TAGS_TTL:
        return cached[1]
    output = git('tag', '--sort=-creatordate')
    prefix = channel + '-'
    tags = [t for t in output.split('\n') if t.startswith(prefix)]
    _tags_cache[channel] = (time.monotonic(), tags)
    return tags


def get_previous_tag(tag):
    series = tag.split('-')[0] + '-'
    output = git('tag', '--sort=-creatordate', '--merged', tag)
    for t in output.split('\n'):
        if t.startswith(series) and t != tag:
            return t
    return None


def get_commits_between(prev_tag, tag):
    if prev_tag:
        return git('log', '--oneline', '--no-merges', f'{prev_tag}..{tag}')
    return git('log', '--oneline', '--no-merges', tag)


def _refresh_tag_dates():
    global _tag_dates_ts
    now = time.monotonic()
    if now - _tag_dates_ts < _TAGS_TTL:
        return
    output = git('tag', '-l', '--sort=-creatordate',
                  '--format=%(refname:short)\t%(creatordate:short)')
    for line in output.split('\n'):
        if '\t' in line:
            name, date = line.split('\t', 1)
            _tag_dates_cache[name] = date
    _tag_dates_ts = now


def get_tag_date(tag):
    _refresh_tag_dates()
    return _tag_dates_cache.get(tag) or git('log', '-1', '--format=%cs', tag)


# ---------------------------------------------------------------------------
# Notes helpers
# ---------------------------------------------------------------------------

def notes_path(channel, tag):
    return os.path.join(APP_DIR, channel, f'{tag}.md')


def notes_exist(channel, tag):
    return os.path.isfile(notes_path(channel, tag))


def read_notes(channel, tag):
    with open(notes_path(channel, tag)) as f:
        return f.read()


def write_notes(channel, tag, content):
    path = notes_path(channel, tag)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)


def markdown_to_html(md_text):
    lines = md_text.strip().split('\n')
    html_lines = []
    in_list = False
    for line in lines:
        if line.startswith('- '):
            if not in_list:
                html_lines.append('<ul>')
                in_list = True
            item = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', line[2:])
            html_lines.append(f'  <li>{item}</li>')
        else:
            if in_list:
                html_lines.append('</ul>')
                in_list = False
            if line.strip():
                html_lines.append(f'<p>{line}</p>')
    if in_list:
        html_lines.append('</ul>')
    return '\n'.join(html_lines)


def search_notes(query):
    """Search tag names and note contents across all channels. Returns [(channel, tag, snippet)]."""
    results = []
    q = query.lower()
    for ch in CHANNELS:
        for tag_name in get_tags_for_channel(ch):
            match_tag = q in tag_name.lower()
            snippet = None
            if notes_exist(ch, tag_name):
                content = read_notes(ch, tag_name)
                if q in content.lower():
                    for line in content.split('\n'):
                        if q in line.lower():
                            snippet = line
                            break
                elif not match_tag:
                    continue
            elif not match_tag:
                continue
            results.append((ch, tag_name, get_tag_date(tag_name), snippet))
    return results


# ---------------------------------------------------------------------------
# Claude invocation
# ---------------------------------------------------------------------------

def generate_notes_with_claude(commits, prev_tag, tag):
    if prev_tag:
        scope = f"between `{prev_tag}` and `{tag}`"
    else:
        scope = f"up to `{tag}` (initial release)"
    prompt = (
        f"You are writing release notes from git commits {scope} "
        f"for a macOS app update.\n\n"
        "Rules:\n"
        "- Output ONLY a plain bullet list. No headings, no sections, no preamble.\n"
        "- Each bullet format: **Bold short label** — Description of what is new or changed.\n"
        "- Group closely related commits into one bullet. Use commas to list multiple related items within one bullet.\n"
        "- Aim for 3-12 bullets total depending on commit volume.\n"
        "- Tone: concise, confident, informative. Written for end users.\n"
        "- Name features, UI elements, and behaviors specifically.\n"
        "- Do NOT include commit hashes, author names, or issue numbers.\n"
        "- Do NOT wrap output in markdown code fences.\n"
        "- Do NOT include any preamble, commentary, or explanation. ONLY output lines starting with '- '.\n\n"
        "Example style:\n"
        "- **Continuity Camera** — Import photos/videos directly from iPhone into Writer\n"
        "- **Article selection & navigation** — Restore last selected article on launch, "
        "auto-scroll sidebar, preserve selection after saving/moving drafts\n"
        "- **Dependencies** — Replaced ENSKit with lightweight ENSDataKit, "
        "removed unused HDWalletKit, updated Sparkle to 2.9.0\n"
    )
    result = subprocess.run(
        ['claude', '-p', prompt],
        input=commits,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.stderr:
        log.warning('claude stderr for %s: %s', tag, result.stderr.strip())
    if result.returncode != 0:
        log.error('claude exited %d for %s', result.returncode, tag)
    log.info('claude output for %s:\n%s', tag, result.stdout.strip())
    raw = result.stdout.strip()
    return '\n'.join(line for line in raw.split('\n') if line.startswith('- '))


# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------

_jinja = Environment(loader=BaseLoader(), autoescape=True)

_STYLE = """
    :root {
      --color-text: #333;
      --color-text-secondary: #666;
      --color-text-muted: #888;
      --color-bg: #fff;
      --color-bg-sidebar: #f5f5f7;
      --color-bg-hover: #e8e8ed;
      --color-border: #ddd;
      --color-border-light: #f0f0f0;
      --color-accent: #007aff;
      --color-accent-hover: #005ec4;
      --color-green: #34c759;
      --color-orange: #ff9f0a;
      --color-error: #c00;
      --color-highlight: #fef3cd;
      --color-btn-secondary-bg: #f5f5f7;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
      display: flex; height: 100vh; color: var(--color-text); background: var(--color-bg);
    }
    .sidebar {
      width: 200px; background: var(--color-bg-sidebar); border-right: 1px solid var(--color-border);
      padding: 20px; flex-shrink: 0;
    }
    .sidebar h2 {
      font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em;
      color: var(--color-text-muted); margin-bottom: 12px;
    }
    .sidebar a {
      display: block; padding: 8px 12px; border-radius: 6px;
      text-decoration: none; color: var(--color-text); margin-bottom: 4px; font-size: 14px;
    }
    .sidebar a:hover { background: var(--color-bg-hover); }
    .sidebar a.active { background: var(--color-accent); color: #fff; }
    .content { flex: 1; overflow-y: auto; padding: 24px; }
    .tag-list { list-style: none; }
    .tag-list li { border-bottom: 1px solid var(--color-border-light); }
    .tag-list li a {
      display: flex; align-items: center; gap: 8px;
      padding: 10px 12px; text-decoration: none; color: var(--color-text); font-size: 14px;
    }
    .tag-list li a:hover { background: var(--color-bg-sidebar); }
    .dot {
      width: 8px; height: 8px; border-radius: 50%;
      background: var(--color-green); flex-shrink: 0;
    }
    .dot.empty { background: transparent; }
    .dot.pending { background: var(--color-orange); animation: pulse 1.2s ease-in-out infinite; }
    @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.4; } }
    .tag-date { color: var(--color-text-muted); margin-left: auto; font-size: 12px; }
    .meta { color: var(--color-text-secondary); font-size: 13px; margin-bottom: 16px; line-height: 1.6; }
    .notes { max-width: 720px; line-height: 1.7; font-size: 14px; }
    .notes ul { padding-left: 20px; margin: 8px 0; }
    .notes li { margin-bottom: 6px; }
    .btn {
      display: inline-block; padding: 8px 18px; background: var(--color-accent);
      color: #fff; border: none; border-radius: 6px; cursor: pointer;
      font-size: 13px; text-decoration: none;
    }
    .btn:hover { background: var(--color-accent-hover); }
    .btn.secondary { background: var(--color-btn-secondary-bg); color: var(--color-text); border: 1px solid var(--color-border); }
    .btn.secondary:hover { background: var(--color-bg-hover); }
    .loading { display: none; align-items: center; gap: 10px; font-size: 13px; color: var(--color-text-secondary); }
    .loading.active { display: flex; }
    .spinner {
      width: 16px; height: 16px; border: 2px solid var(--color-border);
      border-top-color: var(--color-accent); border-radius: 50%;
      animation: spin 0.7s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    h1 { font-size: 20px; font-weight: 600; margin-bottom: 8px; }
    .empty-state { color: var(--color-text-muted); font-size: 14px; margin-top: 40px; }
    .search-box {
      width: 100%; padding: 6px 10px; border: 1px solid var(--color-border); border-radius: 6px;
      font-size: 13px; margin-bottom: 16px; outline: none;
    }
    .search-box:focus { border-color: var(--color-accent); }
    .search-result { border-bottom: 1px solid var(--color-border-light); padding: 10px 0; }
    .search-result a { text-decoration: none; color: var(--color-accent); font-size: 14px; }
    .search-result .snippet { color: var(--color-text-secondary); font-size: 12px; margin-top: 4px; }
    .search-result .snippet mark { background: var(--color-highlight); border-radius: 2px; }
    .search-result .tag-channel { color: var(--color-text-muted); font-size: 12px; }
"""

_SIDEBAR = """
  <div class="sidebar">
    <form action="/search" method="get">
      <input id="search-input" class="search-box" type="text" name="q" placeholder="Search notes..." value="{{ query|default('') }}" autofocus>
    </form>
    <script>var _s=document.getElementById('search-input');if(_s&&_s.value)requestAnimationFrame(function(){_s.selectionStart=_s.selectionEnd=_s.value.length})</script>
    <h2>Channels</h2>
    {% for ch in channels %}
    <a href="/channel/{{ ch }}" class="{{ 'active' if ch == active_channel else '' }}">{{ ch }}</a>
    {% endfor %}
  </div>
"""

_TPL_CHANNEL = _jinja.from_string(
    '<!DOCTYPE html><html><head><meta charset="utf-8">'
    '<title>Sparkle Release Notes</title>'
    '<style>' + _STYLE + '</style></head><body>'
    + _SIDEBAR +
    """
  <div class="content">
    <h1>{{ active_channel }}</h1>
    {% if tags %}
    <ul class="tag-list">
      {% for tag, date, has_notes, is_pending in tags %}
      <li>
        <a href="/channel/{{ active_channel }}/tag/{{ tag }}">
          <span class="dot {{ '' if has_notes else ('pending' if is_pending else 'empty') }}"></span>
          {{ tag }}
          <span class="tag-date">{{ date }}</span>
        </a>
      </li>
      {% endfor %}
    </ul>
    {% else %}
    <p class="empty-state">No tags found for this channel.</p>
    {% endif %}
  </div>
</body></html>"""
)

_TPL_TAG = _jinja.from_string(
    '<!DOCTYPE html><html><head><meta charset="utf-8">'
    '<title>Sparkle Release Notes</title>'
    '<style>' + _STYLE + '</style></head><body>'
    + _SIDEBAR +
    """
  <div class="content">
    <h1>{{ tag }}</h1>
    <div class="meta">
      {{ tag_date }}
      {% if prev_tag %}
        &middot; Previous: <a href="/channel/{{ active_channel }}/tag/{{ prev_tag }}">{{ prev_tag }}</a>
      {% else %}
        &middot; Initial release
      {% endif %}
        &middot; {{ commit_count }} commit{{ 's' if commit_count != 1 else '' }}
    </div>

    <div id="notes-area">
      {% if notes_html %}
        <div class="notes">{{ notes_html | safe }}</div>
        <div style="margin-top: 16px;">
          <button class="btn secondary" onclick="regenerateNotes()">Regenerate</button>
        </div>
      {% elif is_pending %}
        <div id="loading-bg" class="loading active">
          <div class="spinner"></div>
          <span>Generating in background&hellip;</span>
        </div>
      {% else %}
        <button id="gen-btn" class="btn" onclick="generateNotes()">Generate</button>
      {% endif %}
    </div>

    <div id="loading" class="loading">
      <div class="spinner"></div>
      <span>Generating release notes&hellip;</span>
    </div>

    <script>
    async function doGenerate(endpoint) {
      const btn = document.getElementById('gen-btn');
      if (btn) btn.style.display = 'none';
      document.getElementById('loading').classList.add('active');
      document.querySelectorAll('.btn.secondary').forEach(b => b.style.display = 'none');
      try {
        const resp = await fetch(endpoint, { method: 'POST' });
        if (!resp.ok) {
          const err = await resp.text();
          throw new Error(err);
        }
        const data = await resp.json();
        document.getElementById('notes-area').innerHTML =
          '<div class="notes">' + data.html + '</div>' +
          '<div style="margin-top:16px"><button class="btn secondary" onclick="regenerateNotes()">Regenerate</button></div>';
      } catch (e) {
        document.getElementById('notes-area').innerHTML =
          '<p style="color:var(--color-error)">Error: ' + e.message + '</p>' +
          '<button class="btn" style="margin-top:8px" onclick="generateNotes()">Retry</button>';
      }
      document.getElementById('loading').classList.remove('active');
    }
    function generateNotes() {
      doGenerate('/channel/{{ active_channel }}/tag/{{ tag }}/generate');
    }
    function regenerateNotes() {
      doGenerate('/channel/{{ active_channel }}/tag/{{ tag }}/regenerate');
    }
    {% if is_pending %}
    (function pollStatus() {
      setTimeout(async () => {
        try {
          const resp = await fetch('/channel/{{ active_channel }}/tag/{{ tag }}/status');
          const data = await resp.json();
          if (data.has_notes) {
            location.reload();
          } else if (data.pending) {
            pollStatus();
          }
        } catch(e) { pollStatus(); }
      }, 3000);
    })();
    {% endif %}
    </script>
  </div>
</body></html>"""
)


_TPL_SEARCH = _jinja.from_string(
    '<!DOCTYPE html><html><head><meta charset="utf-8">'
    '<title>Search — Sparkle Release Notes</title>'
    '<style>' + _STYLE + '</style></head><body>'
    + _SIDEBAR +
    """
  <div class="content">
    <h1>Search: {{ query }}</h1>
    {% if results %}
    <p style="color:#888; font-size:13px; margin-bottom:16px;">{{ results|length }} result{{ 's' if results|length != 1 else '' }}</p>
    {% for ch, tag, date, snippet in results %}
    <div class="search-result">
      <a href="/channel/{{ ch }}/tag/{{ tag }}">{{ tag }}</a>
      <span class="tag-channel">{{ ch }}</span>
      <span class="tag-date" style="margin-left:8px;">{{ date }}</span>
      {% if snippet %}
      <div class="snippet">{{ snippet | safe }}</div>
      {% endif %}
    </div>
    {% endfor %}
    {% else %}
    <p class="empty-state">No results found.</p>
    {% endif %}
  </div>
</body></html>"""
)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route('/')
def index():
    return redirect(url_for('channel', channel_name=CHANNELS[0]))


@app.route('/search')
def search():
    query = request.args.get('q', '').strip()
    if not query:
        return redirect(url_for('index'))
    results = search_notes(query)
    # Highlight matching text in snippets
    from markupsafe import escape as html_escape
    highlighted = []
    for ch, tag_name, date, snippet in results:
        if snippet:
            # Strip markdown formatting, then HTML-escape, then highlight
            clean = re.sub(r'\*\*(.+?)\*\*', r'\1', snippet)
            clean = clean.lstrip('- ')
            safe = str(html_escape(clean))
            safe = re.sub(
                re.escape(str(html_escape(query))),
                lambda m: f'<mark>{m.group()}</mark>',
                safe,
                flags=re.IGNORECASE,
            )
            highlighted.append((ch, tag_name, date, safe))
        else:
            highlighted.append((ch, tag_name, date, None))
    return _TPL_SEARCH.render(
        channels=CHANNELS,
        active_channel=None,
        query=query,
        results=highlighted,
    )


@app.route('/channel/<channel_name>')
def channel(channel_name):
    if channel_name not in CHANNELS:
        abort(404)
    tags = get_tags_for_channel(channel_name)
    tag_info = []
    for t in tags:
        date = get_tag_date(t)
        has_notes = notes_exist(channel_name, t)
        is_pending = t in _generating
        tag_info.append((t, date, has_notes, is_pending))
    return _TPL_CHANNEL.render(
        channels=CHANNELS,
        active_channel=channel_name,
        tags=tag_info,
    )


@app.route('/channel/<channel_name>/tag/<tag_name>')
def tag(channel_name, tag_name):
    if channel_name not in CHANNELS:
        abort(404)
    if not tag_name.startswith(channel_name + '-'):
        abort(404)

    prev_tag = get_previous_tag(tag_name)
    tag_date = get_tag_date(tag_name)
    commits = get_commits_between(prev_tag, tag_name)
    commit_count = len(commits.split('\n')) if commits else 0

    notes_html = None
    if notes_exist(channel_name, tag_name):
        notes_html = markdown_to_html(read_notes(channel_name, tag_name))

    is_pending = tag_name in _generating

    return _TPL_TAG.render(
        channels=CHANNELS,
        active_channel=channel_name,
        tag=tag_name,
        tag_date=tag_date,
        prev_tag=prev_tag,
        commit_count=commit_count,
        notes_html=notes_html,
        is_pending=is_pending,
    )


@app.route('/channel/<channel_name>/tag/<tag_name>/generate', methods=['POST'])
def generate(channel_name, tag_name):
    if channel_name not in CHANNELS or not tag_name.startswith(channel_name + '-'):
        abort(404)

    prev_tag = get_previous_tag(tag_name)
    commits = get_commits_between(prev_tag, tag_name)
    if not commits:
        notes = '- No changes in this release.\n'
    else:
        notes = generate_notes_with_claude(commits, prev_tag, tag_name)

    write_notes(channel_name, tag_name, notes)
    return jsonify(html=markdown_to_html(notes))


@app.route('/channel/<channel_name>/tag/<tag_name>/status')
def tag_status(channel_name, tag_name):
    return jsonify(
        has_notes=notes_exist(channel_name, tag_name),
        pending=tag_name in _generating,
    )


@app.route('/channel/<channel_name>/tag/<tag_name>/regenerate', methods=['POST'])
def regenerate(channel_name, tag_name):
    if channel_name not in CHANNELS or not tag_name.startswith(channel_name + '-'):
        abort(404)

    path = notes_path(channel_name, tag_name)
    if os.path.isfile(path):
        os.remove(path)

    return generate(channel_name, tag_name)


# ---------------------------------------------------------------------------
# Background generation worker
# ---------------------------------------------------------------------------

def _worker():
    while True:
        channel, tag_name = _gen_queue.get()
        try:
            if notes_exist(channel, tag_name):
                continue
            prev_tag = get_previous_tag(tag_name)
            commits = get_commits_between(prev_tag, tag_name)
            if not commits:
                write_notes(channel, tag_name, '- No changes in this release.\n')
            else:
                log.info('Generating notes for %s', tag_name)
                notes = generate_notes_with_claude(commits, prev_tag, tag_name)
                write_notes(channel, tag_name, notes)
                log.info('Done: %s', tag_name)
        except Exception:
            log.exception('Failed to generate notes for %s', tag_name)
        finally:
            _generating.pop(tag_name, None)
            _gen_queue.task_done()


def _cleanup_empty_notes():
    """Delete 0-size .md files so they get regenerated."""
    for ch in CHANNELS:
        ch_dir = os.path.join(APP_DIR, ch)
        if not os.path.isdir(ch_dir):
            continue
        for fname in os.listdir(ch_dir):
            if fname.endswith('.md'):
                path = os.path.join(ch_dir, fname)
                if os.path.getsize(path) == 0:
                    log.info('Removing empty %s/%s', ch, fname)
                    os.remove(path)


def enqueue_missing():
    """Delete empty .md files, then queue all tags without notes."""
    _cleanup_empty_notes()
    for ch in CHANNELS:
        for tag_name in get_tags_for_channel(ch):
            if not notes_exist(ch, tag_name):
                _generating[tag_name] = True
                _gen_queue.put((ch, tag_name))
    remaining = _gen_queue.qsize()
    if remaining:
        log.info('Queued %d tags for background generation', remaining)


# ---------------------------------------------------------------------------
# Startup — runs for both `flask run` and `python app.py`
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    datefmt='%H:%M:%S',
)

for _ch in CHANNELS:
    os.makedirs(os.path.join(APP_DIR, _ch), exist_ok=True)

for _i in range(_NUM_WORKERS):
    threading.Thread(target=_worker, daemon=True).start()
enqueue_missing()

if __name__ == '__main__':
    app.run(debug=True, port=6323, use_reloader=False)

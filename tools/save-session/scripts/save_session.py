#!/usr/bin/env python3
"""Create or update a Planet article for the current Codex thread."""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request


SKILL_DIR = Path(__file__).resolve().parent.parent
CONFIG_PATH = SKILL_DIR / "config.json"
CODEX_HOME = Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()
SESSION_INDEX_PATH = CODEX_HOME / "session_index.jsonl"


def fail(message: str) -> "None":
    print(message, file=sys.stderr)
    raise SystemExit(1)


def load_config() -> dict:
    with CONFIG_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def get_planet_id(config: dict, cwd: str) -> str | None:
    best_match = None
    best_length = -1
    normalized_cwd = os.path.abspath(cwd)

    for project_path, planet_id in config.get("planets", {}).items():
        normalized_project = os.path.abspath(project_path)
        if normalized_cwd == normalized_project or normalized_cwd.startswith(normalized_project + os.sep):
            if len(normalized_project) > best_length:
                best_length = len(normalized_project)
                best_match = planet_id

    return best_match


def parse_iso8601(value: str) -> dt.datetime:
    normalized = value.strip()
    if normalized.endswith("Z"):
        normalized = normalized[:-1] + "+00:00"
    return dt.datetime.fromisoformat(normalized)


def request_json(url: str, method: str = "GET", data: dict | None = None) -> dict | list:
    payload = None
    headers = {}
    if data is not None:
        payload = urllib.parse.urlencode(data).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    request = urllib.request.Request(url, data=payload, method=method, headers=headers)

    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace").strip()
        detail = f"{exc.code} {exc.reason}"
        if body:
            detail = f"{detail}: {body}"
        fail(f"Planet API request failed for {url}: {detail}")
    except urllib.error.URLError as exc:
        fail(f"Planet API request failed for {url}: {exc.reason}")


def list_articles(base_url: str, planet_id: str) -> list[dict]:
    response = request_json(f"{base_url}/v0/planets/my/{planet_id}/articles")
    if isinstance(response, list):
        return response
    fail("Planet API returned an unexpected response while listing articles.")


def get_article(base_url: str, planet_id: str, article_id: str) -> dict:
    response = request_json(f"{base_url}/v0/planets/my/{planet_id}/articles/{article_id}")
    if isinstance(response, dict):
        return response
    fail("Planet API returned an unexpected response while fetching an article.")


def create_article(base_url: str, planet_id: str, title: str, content: str, date: str | None) -> dict:
    data = {"title": title, "content": content}
    if date:
        data["date"] = date
    response = request_json(f"{base_url}/v0/planets/my/{planet_id}/articles", method="POST", data=data)
    if isinstance(response, dict):
        return response
    fail("Planet API returned an unexpected response while creating an article.")


def update_article(base_url: str, planet_id: str, article_id: str, title: str, content: str) -> dict:
    response = request_json(
        f"{base_url}/v0/planets/my/{planet_id}/articles/{article_id}",
        method="POST",
        data={"title": title, "content": content},
    )
    if isinstance(response, dict):
        return response
    fail("Planet API returned an unexpected response while updating an article.")


def get_thread_id() -> str:
    thread_id = os.environ.get("CODEX_THREAD_ID", "").strip()
    if not thread_id:
        fail("CODEX_THREAD_ID is not set. Run this from an active Codex session.")
    return thread_id


def get_thread_name(thread_id: str) -> str | None:
    if not SESSION_INDEX_PATH.exists():
        return None

    with SESSION_INDEX_PATH.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("id") == thread_id:
                thread_name = entry.get("thread_name")
                if isinstance(thread_name, str) and thread_name.strip():
                    return " ".join(thread_name.split())
                return None
    return None


def get_session_started_at(thread_id: str) -> dt.datetime | None:
    pattern = str(CODEX_HOME / "sessions" / "*" / "*" / "*" / f"rollout-*-{thread_id}.jsonl")
    for path in sorted(glob.glob(pattern)):
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if entry.get("type") != "session_meta":
                    continue
                payload = entry.get("payload", {})
                timestamp = payload.get("timestamp")
                if isinstance(timestamp, str) and timestamp.strip():
                    return parse_iso8601(timestamp)
    return None


def derive_title(started_at: dt.datetime | None, thread_name: str | None, cwd: str) -> str:
    if started_at is None:
        session_date = dt.datetime.now().astimezone().date().isoformat()
    else:
        session_date = started_at.astimezone().date().isoformat()

    subject = thread_name or Path(cwd).name or "Codex session"
    title = f"{session_date} Session: {subject}"
    return " ".join(title.split())[:160].rstrip()


def marker_for_thread(thread_id: str) -> str:
    return f"<!-- codex-save-session thread_id={thread_id} -->"


def build_content(thread_id: str, summary_html: str) -> str:
    cleaned = summary_html.strip()
    return f"{marker_for_thread(thread_id)}\n{cleaned}\n"


def find_existing_article(base_url: str, planet_id: str, thread_id: str, title: str) -> str | None:
    articles = list_articles(base_url, planet_id)
    marker = marker_for_thread(thread_id)
    fallback_title_id = None
    saw_inline_content = False

    for article in articles:
        article_id = article.get("id")
        article_title = article.get("title")
        article_content = article.get("content")

        if article_title == title and isinstance(article_id, str):
            fallback_title_id = article_id

        if isinstance(article_content, str):
            saw_inline_content = True
            if marker in article_content and isinstance(article_id, str):
                return article_id

    if not saw_inline_content:
        for article in articles:
            article_id = article.get("id")
            if not isinstance(article_id, str):
                continue
            full_article = get_article(base_url, planet_id, article_id)
            if marker in str(full_article.get("content", "")):
                return article_id

    return fallback_title_id


def resolve_saved_article_id(base_url: str, planet_id: str, thread_id: str, title: str) -> str | None:
    return find_existing_article(base_url, planet_id, thread_id, title)


def read_summary(content_file: str | None) -> str:
    if content_file:
        with open(content_file, encoding="utf-8") as handle:
            content = handle.read()
    else:
        content = sys.stdin.read()

    if not content.strip():
        fail("Session summary is empty. Pipe HTML into stdin or pass --content-file.")
    return content


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", help="Override the derived article title.")
    parser.add_argument("--date", help="Override the derived ISO 8601 article date.")
    parser.add_argument("--content-file", help="Read the session summary HTML from a file.")
    args = parser.parse_args()

    config = load_config()
    base_url = str(config.get("planet_server", "")).rstrip("/")
    if not base_url:
        fail(f"Missing planet_server in {CONFIG_PATH}.")

    cwd = os.getcwd()
    planet_id = get_planet_id(config, cwd)
    if not planet_id:
        fail(f"No Planet configured for {cwd}.")

    thread_id = get_thread_id()
    thread_name = get_thread_name(thread_id)
    started_at = get_session_started_at(thread_id)
    title = args.title or derive_title(started_at, thread_name, cwd)
    article_date = args.date
    if article_date is None and started_at is not None:
        article_date = started_at.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    summary_html = read_summary(args.content_file)
    content = build_content(thread_id, summary_html)

    article_id = find_existing_article(base_url, planet_id, thread_id, title)
    if article_id:
        update_article(base_url, planet_id, article_id, title, content)
        saved_article_id = resolve_saved_article_id(base_url, planet_id, thread_id, title) or article_id
        print(f"Updated: {title} (id: {saved_article_id})")
        return

    create_article(base_url, planet_id, title, content, article_date)
    saved_article_id = resolve_saved_article_id(base_url, planet_id, thread_id, title)
    if saved_article_id:
        print(f"Created: {title} (id: {saved_article_id})")
    else:
        print(f"Created: {title}")


if __name__ == "__main__":
    main()

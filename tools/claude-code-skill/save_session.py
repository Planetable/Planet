#!/usr/bin/env python3
"""Save a Claude Code session summary to Planet as an article."""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(SCRIPT_DIR, 'config.json')


def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)


def get_planet_id(config, cwd):
    """Find the planet ID for the given working directory."""
    for project_path, planet_id in config['planets'].items():
        if cwd.startswith(project_path):
            return planet_id
    return None


def api_get(url):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def api_post(url, data):
    encoded = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=encoded, method='POST')
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def article_exists(base_url, planet_id, title):
    """Check if an article with this title already exists in the planet."""
    url = f'{base_url}/v0/search?{urllib.parse.urlencode({"q": title})}'
    results = api_get(url)
    for a in results.get('articles', []):
        if a.get('title') == title and a.get('planetID') == planet_id:
            return True
    return False


def create_article(base_url, planet_id, title, content, date=None):
    """Create an article in the given planet."""
    url = f'{base_url}/v0/planets/my/{planet_id}/articles'
    data = {'title': title, 'content': content}
    if date:
        data['date'] = date
    return api_post(url, data)


def main():
    if len(sys.argv) < 3:
        print('Usage: save_session.py <title> <summary_html> [date]', file=sys.stderr)
        sys.exit(1)

    title = sys.argv[1]
    summary_html = sys.argv[2]
    date = sys.argv[3] if len(sys.argv) > 3 else None

    config = load_config()
    base_url = config['planet_server']
    cwd = os.getcwd()
    planet_id = get_planet_id(config, cwd)

    if not planet_id:
        print(f'No planet configured for {cwd}', file=sys.stderr)
        sys.exit(1)

    if article_exists(base_url, planet_id, title):
        print(f'Article already exists: {title}')
        return

    result = create_article(base_url, planet_id, title, summary_html, date)
    print(f'Created: {result.get("title")} (id: {result.get("id")})')


if __name__ == '__main__':
    main()

"""Minimal Python client for the Planet local API."""

import requests

DEFAULT_BASE = 'http://localhost:8086'


class PlanetClient:
    def __init__(self, base_url=DEFAULT_BASE):
        self.base = base_url.rstrip('/')
        self.session = requests.Session()

    def _url(self, path):
        return f'{self.base}{path}'

    # -- Planets --

    def list_planets(self):
        r = self.session.get(self._url('/v0/planets/my'))
        r.raise_for_status()
        return r.json()

    def get_planet(self, planet_id):
        r = self.session.get(self._url(f'/v0/planets/my/{planet_id}'))
        r.raise_for_status()
        return r.json()

    def create_planet(self, name, about=None, template=None, avatar_path=None):
        data = {'name': name}
        if about:
            data['about'] = about
        if template:
            data['template'] = template
        files = {}
        if avatar_path:
            files['avatar'] = open(avatar_path, 'rb')
        try:
            r = self.session.post(self._url('/v0/planets/my'), data=data, files=files or None)
            r.raise_for_status()
            return r.json()
        finally:
            for f in files.values():
                f.close()

    def update_planet(self, planet_id, name=None, about=None, template=None, avatar_path=None):
        data = {}
        if name:
            data['name'] = name
        if about:
            data['about'] = about
        if template:
            data['template'] = template
        files = {}
        if avatar_path:
            files['avatar'] = open(avatar_path, 'rb')
        try:
            r = self.session.post(self._url(f'/v0/planets/my/{planet_id}'), data=data, files=files or None)
            r.raise_for_status()
            return r.json()
        finally:
            for f in files.values():
                f.close()

    def delete_planet(self, planet_id):
        r = self.session.delete(self._url(f'/v0/planets/my/{planet_id}'))
        r.raise_for_status()
        return r.json()

    def publish_planet(self, planet_id):
        r = self.session.post(self._url(f'/v0/planets/my/{planet_id}/publish'))
        r.raise_for_status()
        return r.json()

    def get_planet_public(self, planet_id):
        r = self.session.get(self._url(f'/v0/planets/my/{planet_id}/public'))
        r.raise_for_status()
        return r.text

    # -- Articles --

    def list_articles(self, planet_id):
        r = self.session.get(self._url(f'/v0/planets/my/{planet_id}/articles'))
        r.raise_for_status()
        return r.json()

    def get_article(self, planet_id, article_id):
        r = self.session.get(self._url(f'/v0/planets/my/{planet_id}/articles/{article_id}'))
        r.raise_for_status()
        return r.json()

    def create_article(self, planet_id, title=None, content=None, date=None, attachment_paths=None):
        data = {}
        if title:
            data['title'] = title
        if content:
            data['content'] = content
        if date:
            data['date'] = date
        files = []
        if attachment_paths:
            for i, path in enumerate(attachment_paths):
                files.append((f'attachments[{i}]', open(path, 'rb')))
        try:
            r = self.session.post(
                self._url(f'/v0/planets/my/{planet_id}/articles'),
                data=data,
                files=files or None,
            )
            r.raise_for_status()
            return r.json()
        finally:
            for _, f in files:
                f.close()

    def update_article(self, planet_id, article_id, title=None, content=None, date=None, attachment_paths=None):
        data = {}
        if title:
            data['title'] = title
        if content:
            data['content'] = content
        if date:
            data['date'] = date
        files = []
        if attachment_paths:
            for i, path in enumerate(attachment_paths):
                files.append((f'attachments[{i}]', open(path, 'rb')))
        try:
            r = self.session.post(
                self._url(f'/v0/planets/my/{planet_id}/articles/{article_id}'),
                data=data,
                files=files or None,
            )
            r.raise_for_status()
            return r.json()
        finally:
            for _, f in files:
                f.close()

    def delete_article(self, planet_id, article_id):
        r = self.session.delete(self._url(f'/v0/planets/my/{planet_id}/articles/{article_id}'))
        r.raise_for_status()
        return r.json()

    # -- Search --

    def search(self, query):
        r = self.session.get(self._url('/v0/search'), params={'q': query})
        r.raise_for_status()
        return r.json()

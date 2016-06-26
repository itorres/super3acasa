#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
import logging
from os import makedirs, path

from bs4 import BeautifulSoup
import requests
import yaml

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)
logger.info("Starting")


class TV3Downloader:
    series = {}
    videos = {}
    _config = None

    def __init__(self, index='alacarta'):
        indexes = {
            'alacarta': {
                'path': '/tv3/alacarta/programes/',
                'selector': {
                    'index': '.R-abcProgrames > li > a',
                    'videos': '.F-info  a',
                },
                'tots': 'Tots'
            },
            'super3': {
                'path': '/tv3/super3/series/',
                'selector': {
                    'index': '.R-infoDestacat a',
                    'videos': 'a.media-object'
                },
                'tots': 'Vídeos'
            }
        }
        self.index = indexes[index]
        for d in self.config['dirs'].values():
            makedirs(d, exist_ok=True)
        self.list()

    @property
    def config(self):
        if self._config is None:
            with open('config.yaml') as f:
                self._config = yaml.load(f)
        return self._config

    def _super3(self):
        if self._series_super3:
            return self._series_super3
        self._series_super3 = []
        url = self._ccma_url(self.super3['path'])
        soup = self._soup(url)
        for serie in soup.select(self.super3['selector']):
            self._series_super3.append(serie.text.strip())

    def list(self):
        url = self._ccma_url(self.index['path'])
        soup = self._soup(url)
        for serie in soup.select(self.index['selector']['index']):
            nom = serie.text.strip()
            path = serie.get('href')
            self.series[nom] = {
                'url': self._ccma_url(path)
            }

    def _ccma_url(self, path):
        return 'http://www.ccma.cat/{}'.format(path)

    def _soup(self, url):
        r = requests.get(url)
        return BeautifulSoup(r.text, "lxml")

    def chapters(self, serie, tots_title='Tots'):
        logger.info('Getting chapters for {}'.format(serie))
        soup = self._soup(self.series[serie]['url'])
        try:
            tots = soup.select('a[title="{}"]'
                               .format(self.index['tots']))[0].get('href')
            soup = self._soup(self._ccma_url(tots))
        except IndexError:
            logger.error('No tag with title "{}" found'
                         .format(self.index['tots']))
            return
        self._get_videos(soup, serie)
        pages = self._get_pages(soup)
        for p in pages:
            page_url = tots + p
            soup = self._soup(self._ccma_url(page_url))
            self._get_videos(soup, serie)

    def _vid_info(self, vid):
        url = ('http://dinamics.ccma.cat/pvideo/media.jsp'
               '?media=video&version=0s&idint={}&profile=tv'
               .format(vid))
        r = requests.get(url)
        return r.json()

    def _dl_vid(self, vid):
        i = self._vid_info(vid)
        d = path.join(self.config['dirs']['download'], vid)
        if not path.exists(d):
                makedirs(d)

        json_file = path.join(d, '{}.json'.format(vid))
        with open(json_file, 'w') as f:
            json.dump(i, f, indent=2)
        for f in ['imatges', 'media', 'subtitols']:
            try:
                url = i[f]['url']
            except KeyError:
                continue
            except TypeError as exc:
                log.error('Error parsing {}: {} json: {}'.format(vid, exc, i))
                continue
            bn = path.basename(url)
            fn = path.join(d, bn)
            self._dl(url, fn)

    def _dl(self, url, filepath):
        r = requests.get(url, stream=True)
        try:
            size = int(r.headers['Content-Length'])/1024/1024
        except Exception:
            size = "Unknown"
        if  path.exists(filepath):
            logger.info('File Already exists {}'.format(filepath))
            return
        logger.info('Downloading {} ({}MB) to {}'.format(url, size, filepath))

        with open(filepath, 'wb') as fd:
            for chunk in r.iter_content(1024*256):
                fd.write(chunk)

    def _get_videos(self, soup, serie):
        for a in soup.select(self.index['selector']['videos']):
            path = a['href'].split('/')
            vid = path.pop()
            if vid == '':
                vid = path.pop()
            self.videos[vid] = {
                'url': self._ccma_url(a['href']),
                'title': a.text.strip()
            }

    def _get_pages(self, soup):
        r = []
        try:
            qs = soup.select('.R-final > a')[0].get('href')
        except IndexError:
            return r
        for kv in qs[1:].split('&'):
            k, v = kv.split('=')
            if k == 'pagina':
                last_page = int(v)
                break
        if last_page == 1:
            return r
        for p in range(2, last_page):
            r.append(qs.replace('pagina={}'.format(last_page),
                                'pagina={}'.format(p)))
        return r


if __name__ == '__main__':
    dl = TV3Downloader('super3')
    for s in dl.series:
        dl.chapters(s)
    for vid in dl.videos.keys():
        dl._dl_vid(vid)

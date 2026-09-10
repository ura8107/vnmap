"""Acquire complete public source lists, preserving unresolved rows.

Python 3 standard library + curl. Run from the repository root. Detail responses
are cached in tmp/; only factual location fields are retained in the snapshot.
The dated files are written only after all 391-or-more returned details succeed.
"""
import concurrent.futures
import csv
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
from html.parser import HTMLParser

ROOT = pathlib.Path('data-raw/source/industrial-park-evidence')
CACHE = pathlib.Path('tmp/industrial-park-acquisition')
TODAY = datetime.date.today().isoformat()


def fetch(url, name, payload=None):
    path = CACHE / name
    if path.exists():
        return path.read_text()
    command = ['curl', '-fLsS', '--retry', '2', '--max-time', '40', url]
    if payload is not None:
        command += ['-H', 'Content-Type: application/json; charset=utf-8', '--data', json.dumps(payload)]
    result = subprocess.run(command, capture_output=True, check=True)
    text = result.stdout.decode('utf-8-sig')
    if not text.strip():
        raise ValueError('Empty response: ' + url)
    path.write_text(text)
    return text


class LocationParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.depth = 0
        self.section = None
        self.item = None
        self.complete = False
        self.text = []

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            self.depth += 1
            cls = dict(attrs).get('class', '').split()
            if 'vitridialy' in cls:
                self.section = self.depth
            if self.section and 'item' in cls and not self.complete:
                self.item = self.depth

    def handle_endtag(self, tag):
        if tag == 'div':
            if self.depth == self.item:
                self.item = None
                self.complete = True
            if self.depth == self.section:
                self.section = None
            self.depth -= 1

    def handle_data(self, data):
        if self.item:
            self.text.append(data)


def write_csv(path, rows):
    temp = path.with_suffix('.tmp')
    with temp.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temp.replace(path)


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    endpoint = 'https://investvietnam.gov.vn/WebService/MapService.asmx/GetKcnJson2'
    response = fetch(endpoint, TODAY + '-feed.json', {'lang': 'vi', 'listProductId': ''})
    feed = json.loads(json.loads(response)['d'])
    assert feed and len({r['id'] for r in feed}) == len(feed)

    def detail(row):
        url = 'https://investvietnam.gov.vn' + row['link']
        html = fetch(url, TODAY + '-' + row['id'] + '.html')
        if 'ProductDetail' not in html:
            raise ValueError('Unexpected detail response: ' + url)
        parser = LocationParser()
        parser.feed(html)
        return {'source_id': row['id'], 'location_text': ' '.join(' '.join(parser.text).split())}

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        locations = list(pool.map(detail, feed))
    html = fetch('https://kcn-kkt.com/kcn', TODAY + '-discovery.html')
    flight = []
    for match in re.finditer(r'self\.__next_f\.push\((\[.*?\])\)</script>', html):
        part = json.loads(match[1])
        if len(part) > 1 and isinstance(part[1], str):
            flight.append(part[1])
    text = ''.join(flight)
    rows = json.JSONDecoder().raw_decode(text[text.index('"rows":') + 7:])[0]
    assert rows and len({r['slug'] for r in rows}) == len(rows)
    fields = ['slug', 'ten', 'tinhSlug', 'tinhTen', 'diaDiem', 'dienTichHa', 'isPlanningOnly', 'hasDtm', 'hasDocs']
    discovery = [{**{k: row[k] for k in fields},
                  'source_url': 'https://kcn-kkt.com/kcn/' + row['slug'],
                  'retrieved_on': TODAY} for row in rows]
    (ROOT / ('investvietnam-' + TODAY + '.json')).write_text(response)
    write_csv(ROOT / ('investvietnam-locations-' + TODAY + '.csv'), locations)
    write_csv(ROOT / ('kcn-kkt-' + TODAY + '.csv'), discovery)
    manifest = []
    for path in sorted(ROOT.iterdir()):
        if path.suffix not in ('.csv', '.json') or path.name == 'manifest.csv':
            continue
        manifest.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    write_csv(ROOT / 'manifest.csv', manifest)
    print({'investvietnam': len(feed), 'details': len(locations), 'discovery': len(rows)})


if __name__ == '__main__':
    main()

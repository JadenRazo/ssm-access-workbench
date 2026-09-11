#!/usr/bin/env python3
"""Credential-free documentation and public-hygiene checks (Python 3.10+)."""
from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
IGNORED_DIRS = {'.git', '.local', 'generated', '__pycache__', 'TestResults'}
EXAMPLE_ACCOUNTS = {'111122223333', '444455556666'}
EXAMPLE_INSTANCES = {'i-0123456789abcdef0'}
TEXT_SUFFIXES = {'.md', '.json', '.ps1', '.psm1', '.py', '.svg', '.yml', '.yaml'}
errors: list[str] = []
checks = 0


def require(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        errors.append(message)


def files():
    return sorted(p for p in ROOT.rglob('*') if p.is_file()
                  and not any(part in IGNORED_DIRS for part in p.relative_to(ROOT).parts))


def headings(text: str) -> set[str]:
    result, seen = set(), {}
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    for line in text.splitlines():
        match = re.match(r'^#{1,6}\s+(.+?)\s*#*$', line)
        if not match:
            continue
        slug = re.sub(r'[^\w\- ]', '', match[1].lower()).replace(' ', '-')
        number = seen.get(slug, 0)
        seen[slug] = number + 1
        result.add(f'{slug}-{number}' if number else slug)
    return result


for path in files():
    rel = path.relative_to(ROOT).as_posix()
    require(path.suffix.lower() not in {'.pem', '.ppk', '.key', '.pfx', '.p12', '.lnk'}, f'{rel}: private/local file type')
    require(not path.name.endswith('.local.json'), f'{rel}: deployment configuration must remain private')
    if path.suffix not in TEXT_SUFFIXES:
        continue
    text = path.read_text(encoding='utf-8')
    require(not re.search(r'(?<!\d)\d{12}(?!\d)', re.sub('|'.join(EXAMPLE_ACCOUNTS), '', text)), f'{rel}: non-example account-like identifier')
    for instance in re.findall(r'\bi-(?:[a-f0-9]{17}|[a-f0-9]{8})\b', text):
        require(instance in EXAMPLE_INSTANCES, f'{rel}: non-example EC2 identifier')
    require(not re.search(r'https://(?:d-[a-f0-9]{10}\.awsapps\.com|ssoins-[a-f0-9]+\.portal\.)', text), f'{rel}: actual-looking SSO portal URL')
    require(not re.search(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b', text), f'{rel}: AWS access-key pattern')
    require('-----BEGIN ' + 'PRIVATE KEY-----' not in text and '-----BEGIN ' + 'RSA PRIVATE KEY-----' not in text, f'{rel}: private key marker')

    if path.suffix == '.json':
        try:
            json.loads(text)
        except json.JSONDecodeError as exc:
            errors.append(f'{rel}: invalid JSON: {exc}')

    if path.suffix == '.md':
        without_code = re.sub(r'```.*?```', '', text, flags=re.S)
        links = re.findall(r'!?\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)', without_code)
        links += re.findall(r'(?:src|href)="([^"]+)"', without_code)
        for link in links:
            parts = urlsplit(link)
            if parts.scheme or parts.netloc:
                require(parts.scheme == 'https', f'{rel}: use HTTPS for external link {link}')
                continue
            target = (path.parent / unquote(parts.path)).resolve() if parts.path else path
            require(target.is_relative_to(ROOT), f'{rel}: link escapes repository: {link}')
            require(target.is_file(), f'{rel}: broken local link: {link}')
            if target.is_file() and parts.fragment and target.suffix == '.md':
                require(unquote(parts.fragment) in headings(target.read_text()), f'{rel}: missing anchor: {link}')

    if path.suffix == '.svg':
        try:
            svg = ET.fromstring(text)
            ns = '{http://www.w3.org/2000/svg}'
            require(svg.tag == ns + 'svg' and 'viewBox' in svg.attrib, f'{rel}: SVG root/viewBox required')
            require(svg.find(ns + 'title') is not None and svg.find(ns + 'desc') is not None, f'{rel}: accessible title/description required')
            for element in svg.iter():
                require(element.tag.rsplit('}', 1)[-1] not in {'script', 'foreignObject', 'image'}, f'{rel}: unsafe or externally dependent SVG element')
                for attr, value in element.attrib.items():
                    require(not attr.lower().startswith('on'), f'{rel}: event handler not allowed')
                    if attr.endswith('href'):
                        require(value.startswith('#'), f'{rel}: external reference not allowed')
        except ET.ParseError as exc:
            errors.append(f'{rel}: invalid SVG: {exc}')

policy = json.loads((ROOT / 'examples/permission-set.json').read_text())
statements = policy['Statement']
require(len({s['Sid'] for s in statements}) == len(statements), 'Policy statement Sids must be unique')
require({s['Action'] for s in statements} == {'ssm:StartSession', 'ssmmessages:OpenDataChannel', 'ssm:TerminateSession'}, 'Unexpected example policy action')
require(all('Resource' in s for s in statements), 'Each policy statement must include Resource')
require(statements[2]['Condition']['StringEquals']['ssm:resourceTag/aws:ssmmessages:session-id'] == '${aws:userid}', 'Federated owner IAM variable must remain literal')
workflow = (ROOT / '.github/workflows/verify.yml').read_text()
for action in re.findall(r'uses:\s*(\S+)', workflow):
    require(bool(re.fullmatch(r'[\w./-]+@[0-9a-f]{40}', action)), 'Actions must be pinned to immutable commits')
require('contents: read' in workflow and 'persist-credentials: false' in workflow, 'CI must use read-only permissions and discard checkout credentials')
require('secrets.' not in workflow and 'id-token: write' not in workflow, 'CI does not need cloud credentials')

if errors:
    print('\n'.join('FAIL  ' + error for error in errors))
    sys.exit(1)
print(f'PASS  {checks} repository assertions: links, anchors, JSON, SVG, public examples, and CI permissions.')
print('This is a targeted hygiene check, not a comprehensive secret scanner or external-link availability test.')

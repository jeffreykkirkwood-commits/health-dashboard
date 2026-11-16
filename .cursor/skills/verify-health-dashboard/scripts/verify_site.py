#!/usr/bin/env python3
"""Verification helper for health-dashboard's promotional website.

Starts an isolated `python3 -m http.server` on website/, then doctor / HTTP /
Playwright drives. Verification scaffolding only — never kill by process name;
only the PID recorded for this RUN_ID. Evidence stays outside the state dir.
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# scripts/ → verify-health-dashboard/ → skills/ → .cursor/ → repo root
ROOT = Path(__file__).resolve().parents[4]
STATE_ROOT = Path(os.environ.get('HEALTH_VERIFY_STATE_ROOT', '/tmp/health-dashboard-verify'))
WEBSITE = ROOT / 'website'


def run_dir(run_id: str) -> Path:
    return STATE_ROOT / run_id


def meta_path(run_id: str) -> Path:
    return run_dir(run_id) / 'meta.json'


def pid_path(run_id: str) -> Path:
    return run_dir(run_id) / 'server.pid'


def load_meta(run_id: str) -> dict:
    path = meta_path(run_id)
    if not path.is_file():
        raise SystemExit(f'no meta for run {run_id}: expected {path}')
    return json.loads(path.read_text())


def free_port() -> int:
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def wait_ready(base: str, timeout: float = 15.0) -> None:
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(base + '/', timeout=1) as r:
                body = r.read()
                if r.status == 200 and b'Health Dashboard' in body:
                    return
                last = f'status={r.status} bytes={len(body)}'
        except Exception as e:  # noqa: BLE001
            last = str(e)
        time.sleep(0.1)
    raise SystemExit(f'server not ready at {base}/: {last}')


def cmd_launch(args: argparse.Namespace) -> None:
    run_id = args.run_id
    d = run_dir(run_id)
    d.mkdir(parents=True, exist_ok=True)
    if pid_path(run_id).is_file():
        raise SystemExit(f'run {run_id} already has a pid file; cleanup first or pick a new RUN_ID')
    if not (WEBSITE / 'index.html').is_file():
        raise SystemExit(f'missing website at {WEBSITE}')
    port = args.port or free_port()
    base = f'http://127.0.0.1:{port}'
    log = d / 'server.log'
    proc = subprocess.Popen(
        [sys.executable, '-m', 'http.server', str(port), '--bind', '127.0.0.1', '--directory', str(WEBSITE)],
        cwd=str(ROOT),
        stdout=log.open('w'),
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    pid_path(run_id).write_text(str(proc.pid))
    try:
        wait_ready(base)
    except SystemExit:
        cmd_cleanup(argparse.Namespace(run_id=run_id))
        raise
    meta = {
        'run_id': run_id,
        'pid': proc.pid,
        'port': port,
        'base_url': base,
        'root': str(ROOT),
        'website': str(WEBSITE),
        'started_at': time.time(),
    }
    meta_path(run_id).write_text(json.dumps(meta, indent=2) + '\n')
    print(json.dumps({'ok': True, **meta}, indent=2))


def cmd_doctor(args: argparse.Namespace) -> None:
    meta = load_meta(args.run_id)
    pid = int(meta['pid'])
    base = meta['base_url']
    problems = []
    if not alive(pid):
        problems.append(f'pid {pid} is not running')
    try:
        with urllib.request.urlopen(base + '/', timeout=3) as r:
            body = r.read()
            home_ok = r.status == 200 and b'Health Dashboard' in body and b'Your health' in body
            if not home_ok:
                problems.append(f'GET / unexpected: status={r.status} len={len(body)}')
    except Exception as e:  # noqa: BLE001
        problems.append(f'GET / failed: {e}')
        body = b''
    for asset in ('/style.css', '/app.js'):
        try:
            with urllib.request.urlopen(base + asset, timeout=3) as r:
                if r.status != 200:
                    problems.append(f'{asset} status {r.status}')
        except Exception as e:  # noqa: BLE001
            problems.append(f'{asset} failed: {e}')
    out = {
        'ok': not problems,
        'run_id': args.run_id,
        'pid': pid,
        'pid_alive': alive(pid),
        'base_url': base,
        'problems': problems,
    }
    print(json.dumps(out, indent=2))
    if problems:
        raise SystemExit(1)


def http_get(base: str, path: str) -> tuple[int, dict, bytes]:
    req = urllib.request.Request(base + path)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, dict(r.headers), r.read()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read()


def cmd_http(args: argparse.Namespace) -> None:
    meta = load_meta(args.run_id)
    status, headers, body = http_get(meta['base_url'], args.path)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / 'status.txt').write_text(str(status) + '\n')
    (out_dir / 'headers.json').write_text(json.dumps(dict(headers), indent=2) + '\n')
    (out_dir / 'body.bin').write_bytes(body)
    try:
        (out_dir / 'body.txt').write_text(body.decode())
    except UnicodeDecodeError:
        (out_dir / 'body.txt').write_text(f'<binary {len(body)} bytes>\n')
    print(json.dumps({'ok': True, 'status': status, 'bytes': len(body), 'out': str(out_dir)}, indent=2))
    if args.expect_status is not None and status != args.expect_status:
        raise SystemExit(f'expected status {args.expect_status}, got {status}')
    if args.expect_contains:
        text = body.decode(errors='replace')
        for needle in args.expect_contains:
            if needle not in text:
                raise SystemExit(f'missing expected text {needle!r} in {args.path}')


def cmd_browser(args: argparse.Namespace) -> None:
    meta = load_meta(args.run_id)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as e:
        raise SystemExit('playwright is required for browser drives: pip install playwright && python3 -m playwright install chromium') from e

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={'width': 1280, 'height': 900})
        page = context.new_page()
        page.goto(meta['base_url'] + args.path, wait_until='networkidle', timeout=30_000)
        if args.click_tab:
            page.get_by_role('tab', name=args.click_tab).click()
            page.wait_for_timeout(300)
        if args.search is not None:
            # Library tab must be active for the search field.
            if page.locator('input[type="search"]').count() == 0:
                page.get_by_role('tab', name='Library').click()
                page.wait_for_timeout(300)
            page.get_by_role('searchbox', name='Search sample health metrics').fill(args.search)
            page.wait_for_timeout(200)
        if args.toggle_faq:
            page.locator('details').filter(has_text=args.toggle_faq).locator('summary').click()
            page.wait_for_timeout(200)
        aria = page.locator('body').aria_snapshot()
        (out_dir / 'aria.txt').write_text(aria if isinstance(aria, str) else str(aria))
        page.screenshot(path=str(out_dir / 'screenshot.png'), full_page=True)
        title = page.title()
        brand = page.locator('header .brand').inner_text() if page.locator('header .brand').count() else ''
        selected = None
        tabs = page.locator('[role="tab"][aria-selected="true"]')
        if tabs.count():
            selected = tabs.first.inner_text().strip()
        preview = page.locator('#preview').inner_text() if page.locator('#preview').count() else ''
        browser.close()

    summary = {
        'ok': True,
        'title': title,
        'brand': brand.strip(),
        'selected_tab': selected,
        'preview_excerpt': preview[:400],
        'out': str(out_dir),
    }
    (out_dir / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    if args.expect_title_contains and args.expect_title_contains not in title:
        raise SystemExit(f'title missing {args.expect_title_contains!r}: {title!r}')
    if args.expect_tab and (selected or '').lower() != args.expect_tab.lower():
        raise SystemExit(f'expected tab {args.expect_tab!r}, got {selected!r}')
    if args.expect_preview_contains:
        for needle in args.expect_preview_contains:
            if needle not in preview:
                raise SystemExit(f'preview missing {needle!r}')


def cmd_cleanup(args: argparse.Namespace) -> None:
    run_id = args.run_id
    d = run_dir(run_id)
    pid_file = pid_path(run_id)
    if pid_file.is_file():
        pid = int(pid_file.read_text().strip())
        if alive(pid):
            os.kill(pid, signal.SIGTERM)
            for _ in range(50):
                if not alive(pid):
                    break
                time.sleep(0.1)
            if alive(pid):
                os.kill(pid, signal.SIGKILL)
        pid_file.unlink(missing_ok=True)
    for name in ('meta.json', 'server.log', 'server.pid'):
        (d / name).unlink(missing_ok=True)
    if d.is_dir() and not any(d.iterdir()):
        d.rmdir()
    print(json.dumps({'ok': True, 'run_id': run_id, 'cleaned': True}, indent=2))


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog='verify_site.py')
    sub = p.add_subparsers(dest='cmd', required=True)

    launch = sub.add_parser('launch', help='start isolated website server')
    launch.add_argument('--run-id', required=True)
    launch.add_argument('--port', type=int, default=0)
    launch.set_defaults(func=cmd_launch)

    doctor = sub.add_parser('doctor', help='read-only health of a launched instance')
    doctor.add_argument('--run-id', required=True)
    doctor.set_defaults(func=cmd_doctor)

    http = sub.add_parser('http', help='GET a path from the launched site')
    http.add_argument('--run-id', required=True)
    http.add_argument('--path', required=True)
    http.add_argument('--out', required=True)
    http.add_argument('--expect-status', type=int, default=None)
    http.add_argument('--expect-contains', action='append', default=[])
    http.set_defaults(func=cmd_http)

    browser = sub.add_parser('browser', help='Playwright drive of the promotional site')
    browser.add_argument('--run-id', required=True)
    browser.add_argument('--path', default='/')
    browser.add_argument('--out', required=True)
    browser.add_argument('--click-tab', default=None, help='tab name: Today, Trends, or Library')
    browser.add_argument('--search', default=None, help='type into Library sample search')
    browser.add_argument('--toggle-faq', default=None, help='FAQ summary text to toggle')
    browser.add_argument('--expect-title-contains', default='Health Dashboard')
    browser.add_argument('--expect-tab', default=None)
    browser.add_argument('--expect-preview-contains', action='append', default=[])
    browser.set_defaults(func=cmd_browser)

    cleanup = sub.add_parser('cleanup', help='stop the instance started for this RUN_ID')
    cleanup.add_argument('--run-id', required=True)
    cleanup.set_defaults(func=cmd_cleanup)
    return p


def main(argv: list[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == '__main__':
    main()

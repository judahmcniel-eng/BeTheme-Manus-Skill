#!/usr/bin/env python3
"""
WordPress REST API Content Push Script
=======================================
Push HTML content to a WordPress page via the REST API.
Uses Application Passwords for authentication.

Usage:
    python3 wp-push-script.py

Configuration:
    Edit the variables below, or set environment variables:
    - WP_URL: WordPress site URL
    - WP_USER: WordPress username
    - WP_APP_PASS: Application Password (generate in WP Admin > Users > Profile)
    - WP_PAGE_ID: Target page ID
    - WP_CONTENT_FILE: Path to HTML file to push
"""

import os
import sys
import requests
import json

# Configuration (edit these or use environment variables)
WP_URL = os.environ.get("WP_URL", "https://your-site.com")
WP_USER = os.environ.get("WP_USER", "your-username")
WP_APP_PASS = os.environ.get("WP_APP_PASS", "xxxx xxxx xxxx xxxx xxxx xxxx")
PAGE_ID = int(os.environ.get("WP_PAGE_ID", "269"))
CONTENT_FILE = os.environ.get("WP_CONTENT_FILE", "wp-hero-page-content.html")


def push_content():
    """Push HTML content to WordPress page."""

    # Read the content file
    if not os.path.exists(CONTENT_FILE):
        print(f"Error: Content file not found: {CONTENT_FILE}")
        sys.exit(1)

    with open(CONTENT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    # Verify no && in script tags (WordPress will mangle these)
    if "&&" in content:
        # Check if it's inside a <script> tag
        import re
        scripts = re.findall(r"<script[^>]*>(.*?)</script>", content, re.DOTALL)
        for script in scripts:
            if "&&" in script:
                print("WARNING: Found && inside <script> tag!")
                print("WordPress will convert this to &#038;&#038; which breaks JS.")
                print("Replace with nested if() statements.")
                response = input("Continue anyway? (y/N): ")
                if response.lower() != "y":
                    sys.exit(1)

    # Push to WordPress
    endpoint = f"{WP_URL}/wp-json/wp/v2/pages/{PAGE_ID}"

    print(f"Pushing content to {endpoint}...")
    print(f"Content length: {len(content)} characters")

    response = requests.post(
        endpoint,
        auth=(WP_USER, WP_APP_PASS),
        json={"content": content},
        headers={"Content-Type": "application/json"},
    )

    if response.status_code == 200:
        data = response.json()
        print(f"Success! Page updated: {data.get('link', 'unknown URL')}")
        print(f"Modified: {data.get('modified', 'unknown')}")
    else:
        print(f"Error {response.status_code}: {response.text[:500]}")
        sys.exit(1)


def verify_deployment():
    """Verify the deployed page doesn't have mangled JavaScript."""
    import subprocess

    page_url = f"{WP_URL}/?p={PAGE_ID}"
    print(f"\nVerifying deployment at {page_url}...")

    # Fetch the page
    resp = requests.get(page_url)
    if resp.status_code != 200:
        print(f"Warning: Could not fetch page (status {resp.status_code})")
        return

    # Check for &#038; in script tags
    if "&#038;" in resp.text:
        import re
        scripts = re.findall(r"<script[^>]*>(.*?)</script>", resp.text, re.DOTALL)
        for script in scripts:
            if "&#038;" in script:
                print("CRITICAL: WordPress mangled && to &#038; in deployed script!")
                print("The JavaScript will have a syntax error.")
                sys.exit(1)

    print("Verification passed: no &#038; entities found in scripts.")


if __name__ == "__main__":
    push_content()
    verify_deployment()

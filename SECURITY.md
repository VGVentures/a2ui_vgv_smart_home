# Security Policy

The [Very Good Ventures][very_good_ventures_link] team takes the security of
A2UI VGV Smart Home seriously. This document describes which versions are
supported and how to report a vulnerability.

## Supported Versions

This repository is a demo. Only the latest commit on `main` receives security
updates. Older commits and forks are not supported.

| Version       | Supported          |
| ------------- | ------------------ |
| `main`        | :white_check_mark: |
| Older commits | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, please report it
privately by [opening a security advisory][security_advisory_link] on GitHub.

Please do **not** open a public GitHub issue, pull request, or discussion for
security reports.

When reporting a vulnerability, include as much of the following information as
possible:

- A description of the issue and its potential impact.
- Steps to reproduce the issue.
- The package(s) and commit affected, for example `home_backend` or the root
  app.
- Any suggested fixes or mitigations, if available.

We will acknowledge your report as soon as possible and work with you to
investigate the issue and coordinate a fix and disclosure.

## Your Gemini API key

The backend holds no API key. Each caller brings their own Gemini key, which
travels only in the request and is never logged. Never commit a key, a
`config.json` or a `.env` file.

[security_advisory_link]: https://github.com/VGVentures/a2ui_vgv_smart_home/security/advisories/new
[very_good_ventures_link]: https://verygood.ventures

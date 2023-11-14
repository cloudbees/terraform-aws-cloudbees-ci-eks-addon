# Contributing

This document provides guidelines for contributing to the module.

## Dependencies

Validate your changes inside the blueprint-agent described in [.Dockerfile](.docker/Dockerfile). It can be run `make dBuildAndRun`.

## Pre-commits: Linting, Formatting and Secrets Scanning

Many of the files in the repository can be linted or formatted to
maintain a standard of quality.

Additionally, secret leaks are watched via gitleaks and git-secrets.

When working with the repository for the first time run pre-commit

Run `pre-commit install`
Run `pre-commit run --all-files`

## Release Drafter

This repository uses [Release Drafter](https://github.com/release-drafter/release-drafter) thus it is recommended to use [Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716) to ease labelling your Pull Request accordingly.
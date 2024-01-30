# Contributing

This document provides guidelines for contributing to the module.

## Dependencies

Validate your changes inside the blueprint agent described in the [Dockerfile](.docker/Dockerfile).

> **_NOTE:_** The agent and dependecies can be automated via [Makefile](Makefile) at the root of the project under the target `dRun`.

## Pre-commits: Linting, Formatting and Secrets Scanning

Many of the files in the repository can be lined or formatted to maintain a standard of quality.

Additionally, secret leaks are watched via gitleaks and git-secrets.

When working with the repository for the first time run pre-commit

Run `pre-commit install`
Run `pre-commit run --all-files`

## CI Test

* CI Tests are deployed into CloudBees platform inside the PS Organization.

## Release Drafter

This repository uses [Release Drafter](https://github.com/release-drafter/release-drafter) do not forget to label Pull Request accordingly.

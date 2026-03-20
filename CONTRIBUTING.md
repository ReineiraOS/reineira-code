# Contributing to ReineiraOS Code

Thank you for your interest in contributing. This document explains how to contribute to `reineira-code`.

## Before You Start

By submitting a contribution, you agree to the [Contributor License Agreement](CLA.md).

## Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automatic versioning and changelog generation.

```
feat: add Chainlink price feed resolver template
fix: correct gas estimation in multi-sig resolver
docs: update deployment instructions
chore: bump hardhat to 2.26.1
test: add edge case for zero-amount escrow

BREAKING CHANGE: rename onConditionSet parameter from `config` to `data`
```

| Prefix             | Version bump          | When to use                              |
| ------------------ | --------------------- | ---------------------------------------- |
| `feat:`            | Minor (0.1.0 → 0.2.0) | New feature, new resolver/policy pattern |
| `fix:`             | Patch (0.1.0 → 0.1.1) | Bug fix, correction                      |
| `docs:`            | No bump               | Documentation only                       |
| `chore:`           | No bump               | Tooling, deps, CI                        |
| `test:`            | No bump               | Test changes only                        |
| `BREAKING CHANGE:` | Major (0.1.0 → 1.0.0) | Interface change, platform bump          |

## Development Workflow

```bash
# 1. Fork and clone
git clone https://github.com/YOUR_USERNAME/reineira-code.git
cd reineira-code
npm install --legacy-peer-deps

# 2. Create a branch
git checkout -b feat/my-resolver-template

# 3. Make changes
# Add contracts to contracts/resolvers/ or contracts/policies/
# Add tests to test/resolvers/ or test/policies/

# 4. Test
npm test

# 5. Lint
npm run lint
npm run format:check

# 6. Commit with conventional format
git commit -m "feat: add time-weighted average price resolver"

# 7. Push and open PR
git push origin feat/my-resolver-template
```

## Pull Request Process

1. Ensure all tests pass (`npm test`)
2. Ensure linting passes (`npm run lint`)
3. Update documentation if adding new patterns
4. Use conventional commit messages
5. Reference any related issues
6. One feature per PR — keep PRs focused

## What to Contribute

- New resolver patterns (contracts/resolvers/)
- New policy patterns (contracts/policies/)
- Test improvements
- Documentation fixes
- Bug fixes in existing templates
- Slash command improvements (.claude/commands/)

## Platform Compatibility

All contributions must be compatible with the platform version declared in `reineira.json`. If your change requires a newer interface, coordinate with the protocol team first.

## Questions?

- [Telegram](https://t.me/ReineiraOS)
- [Documentation](https://reineira.xyz/docs)

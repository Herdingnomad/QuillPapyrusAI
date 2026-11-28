# 0. Record Architecture Decisions

* **Status:** Accepted
* **Date:** 2026-11-26
* **Deciders:** Development Team, AI Engineering Agent
* **Tags:** governance, process

## Context & Problem Statement
We need to record significant architectural, boundary, and tooling decisions made in this repository so human contributors and AI agents preserve consistency and understand the trade-offs behind technical choices.

## Considered Options
* **Option 1:** Informal chat discussions and ephemeral PR comments.
* **Option 2:** Markdown-based Architecture Decision Records (ADRs) stored in version control under `docs/adr/`.

## Decision Outcome
* **Chosen Option:** Option 2. Store lightweight, immutable ADRs in `docs/adr/` using sequential zero-padded numbering (`NNNN-<slug>.md`) and maintain a master index in `docs/adr/README.md`.

### Positive Consequences
* Architectural rationale lives alongside source code in version control.
* Future contributors and AI agents can audit active decisions before introducing structural changes.

### Negative Consequences & Trade-offs
* Introducing major stack or boundary changes requires drafting and approving an ADR before implementation.

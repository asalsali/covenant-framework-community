---
name: memo
description: Compose a structured memo using the Structured Letter Format. Guides you through greeting, doctrinal grounding, practical content, edge cases, and benediction. Usage: /memo <recipient> <subject>
---

# Memo — Structured Message Composition

> "Paul, a servant of Christ Jesus, to all in Rome who are loved by God."

Compose a structured memo following the Structured Letter Format defined in
`memory/memos/PROTOCOL.md`.

## Steps

### 1. Identify sender and recipient

- Sender: the current agent (you)
- Recipient: `$ARGUMENTS` first word, or prompt for it
- Subject: `$ARGUMENTS` remainder, or prompt for it

### 2. Walk through the Structured Letter Format

For each section, compose:

1. **Greeting** — One line: who you are, what mandate you serve
2. **Doctrinal grounding** — Which Constitution sections apply to this content?
   If none are specifically relevant, omit this section.
3. **Practical content** — The distilled findings. Max 500 tokens.
   Apply input policy: no raw context dumps.
4. **Edge cases** — What are you uncertain about? What should the
   recipient verify? This section is mandatory for handoffs.
5. **Benediction** — How should this shape the recipient's work?

### 3. Write the memo

Save to `memory/memos/<your-id>-to-<recipient-id>-<subject-slug>.md`
with the full frontmatter (from, to, subject, priority, timestamp, read: false).

### 4. Confirm

```
EPISTLE WRITTEN
════════════════════════════════════════
From: <you>
To: <recipient>
Subject: <subject>
Priority: <priority>
Saved to: memory/memos/<filename>

The recipient will read this during their Genesis Phase.
════════════════════════════════════════
```

## Notes

- Edge cases are the most valuable section — they prevent the recipient
  from inheriting false certainty
- The benediction orients the recipient — without it, they have data
  but no direction
- For urgent messages, use `priority: urgent` — the Shepherd may
  surface these during briefings

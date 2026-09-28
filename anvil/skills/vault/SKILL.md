---
name: vault
description: "Show anvil vault status: counts, domain tree, drift, orphans, size, versions."
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
Run this exact command and show me the output, unedited:

    anvil status

This is read-only. After showing the output, comment only on what needs
action: drafts waiting (suggest `/anvil:inbox`), missing descriptions or
origins outside the rules (suggest `/anvil:backfill`), a schema behind the
package (suggest `anvil migrate`), drift, or orphans. The output already
shows the numbers; do not repeat them in prose.

$ARGUMENTS

# Live testing: {{ProjectName}} local lab details (gitignored, don't commit)

Never put passwords or secrets in this file. Record only *where* each credential is stored (CP/CCP App ID and object, a saved profile, Credential Manager target, etc.).
The tests themselves (labels, commands, pass criteria) are defined in
[Claude_Docs/Testing_Live-Test-Definitions.md](Claude_Docs/Testing_Live-Test-Definitions.md). This file only fills in its placeholders.

## <Environment name>
- Host / URL / tenant: <value>
- Credential source: <where the credential lives>
- Notes: <rate limits, required delays, known lab quirks>

| Placeholder | Value |
|---|---|
| `{Profile}` | <profile name> |
| `{Username}` | <account the tests sign in as> |
| `{OutputDir}` | <a scratch folder outside the repo> |

## Test fixtures
- <test accounts, safes, objects, hosts that tests use but that aren't placeholders>

## Tests to run

| Label | Environment | Status |
|---|---|---|
| LT-EXAMPLE-01 | <Environment name> | Not run |

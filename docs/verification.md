# Verification ledger

[← Project overview](../README.md)

This ledger separates what the original lab demonstrated, what the repository's tests exercise, and what a deployment owner must still verify. Example values are fictional. Private configuration and raw session evidence are intentionally excluded from the public repository.

## Source lab observations

Recorded from the source walkthrough on 2026-09-11; these are an implementation narrative, not a public reproducibility artifact or independent security attestation.

| Observation | Evidence available in the source walkthrough | Limit |
| :--- | :--- | :--- |
| Identity Center assignment | Read-only inspection found the intended user in the scoped group and the permission set assigned to the intended account | Other administrative assignments also existed; this did not prove exclusive access |
| Scoped SSO tunnel | Session Manager showed a connected custom-document session owned by the expected generated SSO role | A connected tunnel is not proof of host authorization, direct-SSH removal, or session timeout |
| MobaXterm connection | Operator reported a successful connection | No independent automated MobaXterm/SFTP test was captured |
| IAM policy validation | Access Analyzer validation returned no findings | Static validation does not prove effective authorization |
| Resource-scope simulation | Allowed intended target/document and denied alternate resources in simulation | Simulation context is not a substitute for real API denial cases |

The source walkthrough did **not** establish completion of direct-SSH removal, reduction of the instance role, individual Linux privilege review, durable audit configuration, phishing-resistant MFA enrollment, live cross-user termination denial, or recovery after loss of the normal agent path. These remain explicit acceptance work. Do not describe the source lab as a completed production hardening rollout.

## Automated checks

Run `pwsh -NoProfile -File tests/Run-Tests.ps1` and `python tests/check_repository.py` from the repository root. The [GitHub Actions workflow](../.github/workflows/verify.yml) uses Windows and Ubuntu runners with read-only repository permissions and no AWS credentials.

| Check | Execution method | What it proves |
| :--- | :--- | :--- |
| PowerShell parsing | Real parser across all `.ps1` / `.psm1` sources | Syntax is valid in the tested runtime |
| Config and identity failures | Real validation functions with deterministic fixtures | Invalid input, wrong accounts, administrator roles, role-prefix collisions, and changed pins are rejected |
| Connection orchestration | AWS/prerequisite adapters replaced by test doubles | Login retry behavior, refusal before `StartSession`, exact target/document arguments, and error propagation |
| Native executable adapter | Real local child PowerShell process | Array argument preservation, nonzero exit status, inherited output-handle state, and endpoint environment restoration; run in a real terminal to exercise an unredirected handle |
| File preservation | Real temporary files | Existing settings are not overwritten; spaced paths and incomplete configurations are handled |
| Occupied port | Real temporary loopback listener | A busy port is refused without terminating the listener |
| Windows shortcut | Real Windows COM `.lnk` creation, inspection, cleanup | Correct PowerShell target and quoted configuration path; overwrite refusal |
| Policy generation | Compare grant contract and literal variable to committed examples | Generator preserves the reviewed action/resource/condition shape; it does not simulate IAM |
| Documentation/public hygiene | Local links, anchors, JSON, SVG safety, identifier patterns, workflow invariants | Referenced files exist and obvious private deployment material is excluded; not a comprehensive secret scanner |

The Windows shortcut test is skipped on Linux. Browser authentication, the interactive SSO wizard, the Session Manager plugin's live transport, MobaXterm's UI, key handling, and SFTP require a real workstation and cloud lab. A passing CI run does not cover them.

## Repository review record

Before creating the remote repository on 2026-09-11:

- PowerShell 7.6.6 on Linux ARM64 passed 46 tests in a real terminal. AWS calls were mocked as described above; files, loopback listeners, native child processes, and package-generation prompts were exercised locally.
- A separate local terminal probe accepted input with unredirected child stdout. An interruption probe confirmed that its child process was gone after Ctrl+C. This verifies the local adapter mechanism, not the Windows AWS wizard or server-side session cleanup.
- An independent source review found an interactive-output redirection issue, an expected-failure exit-code issue in Windows tests, and incomplete execution-policy guidance. These were corrected; a focused follow-up found no remaining blocker before Windows CI.
- The README and original SVG assets were rendered at 375, 412, 430, 760, and 1280 pixels in light and dark modes. Checks found no page overflow, failed image load, or SVG text clipping, and desktop/mobile captures were visually inspected. This used a local GitHub-style Markdown preview, not GitHub's exact renderer.
- The exact Mermaid sequence source parsed and rendered successfully with Mermaid 11.4.1 and was visually inspected.
- All 34 external documentation/reference links resolved during the publication review. The automated repository check validates local links and anchors, JSON, SVG safety, example identifiers, and workflow permissions; it is not a complete secret scanner.

The [private-stage CI run on commit `8e1484c`](https://github.com/JadenRazo/ssm-access-workbench/actions/runs/34558307181) then passed **47 tests on Windows Server 2025** (including real COM shortcut creation/inspection) and **46 tests on Ubuntu 24.04**. Both jobs passed 711 repository assertions. Windows initially exposed locale-dependent text decoding in the documentation check; explicitly reading UTF-8 corrected it. The [current workflow history](https://github.com/JadenRazo/ssm-access-workbench/actions/workflows/verify.yml) records subsequent revisions. Live workstation/cloud acceptance remains in the matrix below.

## Manual lab acceptance

Run these with administrator approval in a dedicated test environment. For denial tests, use the real CLI directly as well as the launcher; the script must not be the only thing stopping the request. Prepare known existing test resources so a missing document or offline target cannot masquerade as an IAM denial. Never test terminating another person's production session.

| ID | Exercise | Expected result | Evidence to retain privately |
| :--- | :--- | :--- | :--- |
| A01 | Fresh Identity Center sign-in with the enrolled MFA policy | Intended MFA is required under the chosen policy | Time, identity, policy, observation |
| A02 | STS with the dedicated profile | Intended account and SSO permission set | Sanitized ARN / local private record |
| A03 | Start the approved instance/document | Tunnel opens on the agreed local port | Session ID, owner, target, document |
| A04 | Connect MobaXterm and transfer a harmless test file | Verified host key, intended non-root user, SFTP succeeds | Fingerprint source, username, file result |
| A05 | Same role requests another known online lab instance | `AccessDenied`, no session created | API error and administrator check |
| A06 | Same role requests a known shell or generic forwarding document | `AccessDenied`, no session created | Exact requested document and error |
| A07 | Omit the document name on `StartSession` | Default shell path is denied | Error plus effective default-document context |
| A08 | Try to change the fixed document's destination through request parameters | Rejected; no alternate destination | Error and document version |
| A09 | End an owned session with the scoped role | Session terminates and tunnel stops carrying traffic | Session state and client observation |
| A10 | Test identity B tries to end identity A's disposable session | `AccessDenied`; A's session remains active | Both identities and session state |
| A11 | Remove all direct SSH grants after verifying recovery | A new direct connection fails; a new SSM connection succeeds | Group/rule review and both client results |
| A12 | Inspect the live local tunnel listener | Loopback binding only; no unexpected LAN/wildcard exposure | `Get-NetTCPConnection` addresses and process |
| A13 | Let chosen sign-in, role, and custom session durations elapse | Observed behavior matches documented operational expectations | Independent timelines; explicit termination test |
| A14 | Exercise offboarding on a test identity | New access denied and active sessions explicitly ended | Assignment, credential, session, and host-key actions |
| A15 | Simulate loss of the normal access path in the lab | Authorized recovery works within the defined constraints | Recovery prerequisites, steps, result |
| A16 | Review instance role, Linux privileges, and alternate routes | No unexplained broad grant or bypass of the intended design | Administrator review and exceptions |
| A17 | Find start/end activity in the chosen audit store | Events are attributable and retained as required | Event location, retention setting, scope |

If a denial exercise unexpectedly succeeds, stop and inspect effective policies and assignments. If a session was created during a failed negative test, have the administrator terminate that known test session. Do not widen the operator policy just to make a diagnostic console screen load.

## Public claim rule

Update this ledger with dates and the exact scope of new evidence. Do not convert a recommendation into an accomplished result, a mocked AWS response into a cloud test, or a successful terminal into a least-privilege certification. Use the [case study](case-study.md) for the story and this ledger for its limits.

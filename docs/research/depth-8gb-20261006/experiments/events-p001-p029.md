# Events, 2026-10-06 to 2026-10-07 (P001-P029 range, notebook up to the P30 plan)

Non-experiment entries of the notebook (`C:\bonsai\8gb\DECISIONS.md`, copy `NOTEBOOK.md`): rig state, incidents, rig and
tooling changes, notes, PRs and comments, builds, decisions. In time order. Experiment-specific details stay in the P
files; this file names them and links back.

---

## 2026-10-06 (before 18:35) - Rig baseline at the start of the mission

What: the notebook header, "Rig (measured 2026-10-06)".
- RTX 2060 SUPER 8,192 MiB, driver 591.86, PCIe gen 3 x16; 31.9 GB RAM (21.8 free); 445 GB free disk.
- "The only display adapter Windows lists is the 2060 SUPER (3840 wide); explorer/shell hosts hold GPU contexts on it;
  idle used 783 MiB, free 7,224 MiB."
- "`nvidia-smi display_active` reports `Disabled` anyway, so the launcher's headless detection is wrong on this rig:
  every run pins `BONSAI_VRAM_MARGIN` explicitly."
Clocks: stock (memory 7000 MHz; 6,801 MHz under CUDA load, P2 state), power 175 W, fan auto. Afterburner profile slots
applied by scheduled tasks BonsaiAB_P1..P5 (admin, no prompt) and BonsaiAB_Install (scripts/afterburner/,
scripts/setup-afterburner-tasks.ps1, scripts/setup-afterburner-install-task.ps1).
What changed: every experiment pins N or the margin by hand (P001).

## 2026-10-06 ~19:31-19:48 - Incident: stacked servers (P005 arms A and A-r2 invalid)

What happened: stop.ps1 was called without `-ExecutionPolicy Bypass`. The machine's effective policy is Restricted, so
it never ran (output went to /dev/null). Arm A loaded on top of the still-releasing P001 server and hit a CUDA error;
arm A-r2 ran while arm B's server was still alive on port 8080 (~13 GB of servers on the 8 GB card).
Cause: execution policy + a stop call with no error check.
Fix: "stop.ps1 runs with Bypass, waits for llama-server to exit and throws if it does not; serve.ps1 refuses to start
while any llama-server runs; the arm script exits if stop/serve fail or VRAM is not under 1,500 MiB before a load."
Receipts: receipts/p5/INVALID-*. Details: P005.md.
What changed: every later arm script (p5_arm2.sh, p7..p29 scripts, run_arm.sh) has the stop check and the idle-VRAM wait.

## 2026-10-06 ~20:00 - Launcher floor blocks a sizing run (P005 deviation)

start-server.ps1 throws below 16,384 cells even when pinned; the P5 chain ignored the exit code and solved N from an
empty load (411,904). Stopped before that arm loaded. Details: P005.md.

## 2026-10-06 (log times 20:22-21:09) - Build: bin-turing (P008)

vendor/prism-llama branch turing-pt-onecol (c8b8993 + common.cuh one-column override for cc >= TURING), sm_75 only, pip
CUDA 13.4 wheels + nvidia-cuda-cccl 13.3.4 ("the recipe's pip line lacks cccl"), staged in bin-turing\. Build logs:
`logs/build-turing.log` (20:22), `build-turing-bat.log` (20:41), tests build `build-turing-tests.log` (21:09).

## 2026-10-06 (after the P8 result, before the 21:09 test run) - Incident: mixed-source test build killed (P008)

"The test-backend-ops build compiled from vendor/prism-llama while the working tree was switched to the PR branch
(PrismML prism 6bfcd79 + the fix): a mix of two source trees. Killed before any test ran; tree restored to
turing-pt-onecol (bc3e5aa); the PR branch claude/turing-pt-onecol (34a932b on prism 6bfcd79) now lives in a separate
worktree vendor/prism-pr. bin-turing (P8's binaries) came from the clean first build and is unaffected."
Rule: "never switch a checkout that a running build or server reads; one worktree per branch."

## 2026-10-06 (P006 run; receipt written 20:39) - Incident: a repo KL log overwritten and restored (P006)

A failed first invocation of kv_kl_sweep.ps1 overwrote one of the repo's 4070 logs in `artifacts\eval`; it was restored
by git. The 2060 SUPER logs use a unique tag (`-2060super`).

## 2026-10-06 - Note: why the launcher's headless detection fails here

"nvidia-smi (driver 591.86, WDDM) reports display_active Disabled AND display_attached No while Win32_VideoController
shows the 2060 SUPER as the only adapter at 3840 wide; display_mode returns "[Requested functionality has been
deprecated]". nvidia-smi's display fields are not reliable on Windows. Candidate launcher fix (bonsai-ada-surgery,
branch to prepare): treat the NVIDIA card as driving the display when Win32_VideoController reports a
CurrentHorizontalResolution for it (expected empty on the 4070 rig with the iGPU on the desktop - verify there)."

## 2026-10-06 ~21:05 - Rig change: desktop resolution 1280x1024

Cary dropped the display to 1280x1024 at ~21:05 (noted in the P8b result). Card total 599 MiB with test-backend-ops
(~127 MiB) running -> desktop ~470 MiB vs 561-608 MiB idle at 4K earlier that evening. P009 load: 791 MiB free vs 608 at
4K.

## 2026-10-06 21:24:42 - Decision: stock stays the clock baseline (P009)

+150 core / 215 W / fan 100% ran at 86 C (gate < 85 C). Slot 5 re-applied 21:24:42. "The limit is the cooler, not the
silicon; airflow/repaste is the lever if Cary wants the clocks." Details: P009.md.

## 2026-10-06 ~21:40 - Rig change: external desk fans

"external desk fans placed in front of the PC ~21:40 (Cary's sister); later thermal receipts name them" (P8c result).

## 2026-10-06 (between the P8c result and the 21:41 baseline entry) - PR: PrismML-Eng/llama.cpp#325 opened

https://github.com/PrismML-Eng/llama.cpp/pull/325 - "cuda: take the planar PTQ1_0 layout at one column on Turing as well
as Ampere". Head professorpalmer/llama.cpp-ada-ternary:claude/turing-pt-onecol (34a932b on prism 6bfcd79). Body:
pr-turing-pt-onecol.md (copy: drafts/pr-turing-pt-onecol.md; P7/P8/P8b/P8c receipts, credit to sudoingX #218).
"Mergeable, CI pending at open. Duplicate check done before opening (prism still gates Ampere only; no open PR touches
the gate)." Later check-ins (2026-10-08 to 2026-10-11) record no comments on #325.

## 2026-10-06 21:41 - Rig baseline change: slot 5 = stock clocks + fan fixed 100%; 1280x1024; desk fans

"Cary's request: fans at 100%. Slot 5 keeps PowerLimit 100 (175 W), core/memory 0 and the saved VF curve; FanMode=0,
FanSpeed=100. Applying slot 5 while Afterburner considered it active did not change the fan; applying slot 3 then slot 5
did (175 W, 100%). Install via BonsaiAB_Install took ~90 s this time (21:37:53 -> 21:39:24)."
"Clean idle VRAM at 1280x1024, no CUDA process: 323 MiB used (vs 561-608 MiB at 4K this evening) -> ~250-280 MiB
returned, ~15-17k more q4_0 positions in VRAM. Receipts from here name: stock clocks, fan 100%, desk fans, 1280x1024."
What changed: every arm script from P9b on applies slot 3 then slot 5 ("so slot 5 really applies"). P011 sized N from
the 323 MiB idle.

## 2026-10-06 ~21:52 - Build: bin-alpha (P010)

Worktree vendor/prism-alpha = turing-pt-onecol (bc3e5aa) + #314 e3d9df5 + #209 b989116 + 37fe656, sm_75; built after
P8c (scripts/p10_build.sh; `logs/build-alpha.log`).

## 2026-10-06 (P10 period) - Launcher fix on a local branch: display detection from Windows

"bonsai-ada-surgery worktree C:\bonsai\bas-display-detect, branch 8gb-display-detect, commit 4042bb3: after the
nvidia-smi check, if exactly one Win32_VideoController matches GPU 0's name and reports CurrentHorizontalResolution,
$Headless = false. Tested on this rig: nvidia-smi says headless, the check corrects it (1280 wide). Open before pushing:
verify on the 4070 rig (iGPU desktop) that its NVIDIA adapter reports no resolution, else that rig would lose 300 MiB of
positions." Later: part of branch 8gb-rig (P020 plan) and of PR #6 / bundle-20261007 ("display detection").

## 2026-10-06 ~22:00 - Note: access is Chrome Remote Desktop; its own GPU cost is ~8 MiB

"Cary reaches this rig through Chrome Remote Desktop (explains nvidia-smi display_attached No: no physical monitor).
GPU Process Memory counters during P10: remoting_desktop 8 MiB, remoting_host none; dwm 762 MiB "dedicated usage"
(counter includes evicted/committed memory; card idle total was 323 MiB). Moving CRD to software would not help; the
cost is the Windows compositor on the only GPU. Candidate experiment (Cary flips the setting): RDP session rendered in
software, measure idle before/after. Cary reported a further resolution reduction ~21:58 (Win32 still 1280x1024 at
22:00); P10 arms record idle per arm." (P10 idle per arm: 336-359 MiB.) The candidate experiment is not run in this
range.

## 2026-10-06 22:20 - Note: Cary off to bed; full auto overnight

From the P9b result: "Cary off to bed 22:20; running full auto overnight." From here the chains ran unattended
(p9b_p11_chain.sh, p12_prep.sh/p12_arms.sh, p11b.sh, p14_p13.sh and the 2026-10-07 scripts).

## 2026-10-06 ~23:13-23:31 - Build and model prep: bin-p12 and the Q4_0 head (P012)

p12_prep.sh (start 23:13:59): bin-p12 build (vendor/prism-p12 = turing-pt-onecol + #314 switch commit + #209 + Mirai
4bdc6587b shared pool) in parallel with the head requant ("866 tensors, 8 in blk.64.* requantized Q8_0 -> q4_0, saving
212 MB"; 6.186 GB). Strip proof: stripped file 5,946,648,928 bytes, sha256 53107f53...33ee3 == base. "STRIP PROOF OK",
"build-p12 exit 0" (`logs/p12-prep.log`, `logs/build-p12.log`).

## 2026-10-06 after 23:14 (end of the P010b run) - Upstream comment on PrismML #314 (P010b)

https://github.com/PrismML-Eng/llama.cpp/pull/314#issuecomment-6030785242 (copy: drafts/pr314-comment.md). Turing data:
the final commit's hardcoded 50% / 46 CTAs / 16 MiB is a loss on a 4 MB-L2 card (-2.4..-2.7%); MAX_KB=1024 gains
+0.6..+2.2%; proposal: a byte cap of a quarter of l2CacheSize. "Not adopting #314 into the 8 GB default build until its
final form handles small L2."

## 2026-10-06 ~23:50 - Note: Cary's floor = sudoingX's patch on this card

"Cary (going to bed): make our build better and faster than sudoingX's - treat his as the floor. His 8 GB recipe
(bonsai2-small-gpu serve/8gb.sh): -c 65536, q4_0 K/V, no MTP head, all in VRAM, branch sudoingX/llama.cpp bonsai2
(ff41412). His mmvq.cu:299 enables the PT path for PTQ1_0 on cc >= TURING for every column count, so on this card his
build already has what #325 gives the Prism fork: #325 is parity with his branch on Turing, not a lead over it."
What changed: the floor gate (P013) and every later floor comparison (P015, P020, P025-P028).

## 2026-10-07 ~00:26-00:41 - Build: bin-sudo (P013)

sudoingX/llama.cpp bonsai2 ff41412 from vendor/sudo-bonsai2, sm_75, CUDA 13.4 pip (`logs/build-sudo.log`, "build-sudo
exit 0"). P014b ran during this build (CPU loaded, GPU idle).

## 2026-10-07 ~00:30 - Tooling change: stock-apply retry in run_arm.sh (P014b)

Two P014b arms were refused because the card read 215 W after the slot apply ("guard worked"). run_arm.sh now retries
the apply up to four times (slot 3 then slot 5, waits 6/12/18/24 s) until power.limit reads 175 W, else refuses the arm.
Later (P021): under full CPU load four retries were not always enough (Afterburner unreliable).

## 2026-10-07 ~00:3x - Tooling change: BONSAI_UBATCH in the launcher test copy (P014b/P014c)

"start-server-bin.ps1 gained BONSAI_UBATCH (copy only, shipped launcher untouched)." Used by P014c, P022, P026-P028.

## 2026-10-07 02:15 - Builds: bin-rc and bin-p22 compile concurrently (P020, P022)

bin-rc (vendor/prism-pool, sm_75/86/89 + 89-virtual) and bin-p22 (vendor/prism-p22, sm_75 + tests) both compiled during
P021 ("Two builds were compiling concurrently"); both logs last written 03:04. Effect: full CPU load, Afterburner apply
refusals in P021, depressed decode in P021 replays.

## 2026-10-07 (P020 plan) - Repo branch 8gb-rig (local, not pushed)

"Repo branch 8gb-rig (local, not pushed): display detection 4042bb3, Q4 head tooling, docs/8GB.md draft - numbers in the
doc replaced with P20's before Cary decides to publish." P020 ran the branch's build/make_mtp_q4head.ps1 end to end
(byte-identical output). Later: PR #6 and pre-release bundle-20261007 (outside this range).

## 2026-10-07 ~02:57 - Handoff: one-token replay script to Cary (P021)

"Status: open, intermittent, reproducible with P13's sequence; drafted default stays tail 1 ... Handed to Cary with the
replay script." (scripts/p18.sh / p21.sh pattern.)

## 2026-10-07 ~04:04 and ~04:53 - Builds: bin-p22 rebuild (2a558c87f) and bin-p25 (c9a2a7dd0)

`logs/build-p22b.log` (04:04): bin-p22 with "speculative: keep the f16 KQ mask in the MTP draft context" (P022b).
`logs/build-p25.log` (04:53, "build-p25 exit 0"): release candidate + GGML_CUDA_FA_PREFILL_F16 (P025).

## 2026-10-07 (P22b) - Decision: packed KQ mask out of every 8 GB configuration

"Decision: packed mask out of every 8 GB configuration. Finding for Cary: the same two commits sit behind
--kq-mask-packed in llama.cpp-ada-mirai; whether Mirai corrupts at depth is unmeasured." P024 narrowed it ("candidate for
the long-context (no-head) mode only ... Cary's call; not in the RC"). Corrected 2026-10-09 by P082 (race in that build,
not the mask). Details: P022.md, P024.md.

## 2026-10-07 06:2x-06:45 - Build: bin-rc2

"RC2 build (sm_75/86/89 + PTX) from prism-p25 started 06:2x -> bin-rc2." `logs/build-rc2.log` last written 06:45
("build-rc2 exit 0"). Verified by P028.

## 2026-10-07 ~06:46 - Incident: a build-waiting chain stopped a GPU job (P029 r3)

"the RC2 build finished earlier than estimated and P28's first stop killed r3's server (its next request got "connection
refused"); r3's closing stop found no server, and P28's server (pid 6720, 06:46:23) was the only one when P28 measured -
no cross-contamination." Lesson: "a chain waiting on a build must also wait on any GPU job started meanwhile."
Details: P029.md, P028.md.

## 2026-10-07 (P26 + P27 result) - Decision: the two 8 GB modes for the release

"Long-context mode candidate: no head, N=53248, ub 1024, f16 prefill cap 65536 (window 131k; past ~53k decode reads the
host tail). Drafting mode keeps ub 512, f16 cap 32768: prefill -3.4..-3.7% below the floor at 4k-32k, decode
+39..+76%." Verified on RC2 in P028. Details: P027.md.

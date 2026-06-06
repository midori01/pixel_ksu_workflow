<div align="center">

# 🌀 GKI KSU Workflow

![Android](https://img.shields.io/badge/Android-GKI-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Kernel](https://img.shields.io/badge/Kernel-6.1_~_6.12-2F363D?style=for-the-badge&logo=linux&logoColor=white)
![Architecture](https://img.shields.io/badge/Arch-arm64-blue?style=for-the-badge)
![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)

*Automated GitHub Actions CI/CD pipeline for compiling and distributing GKI kernels.*

</div>

---

## 🚀 Overview

This repository implements a unified, config-driven build orchestration system that compiles multiple **KernelSU** variants across multiple kernel versions from a single workflow trigger. Each variant is encapsulated within its own isolated job, maximizing maintainability, simplifying fault isolation, and enabling seamless horizontal scaling for future variants and kernel versions.

---

## ⚙️ Configuration

All kernel version-specific settings are centralized in [`.github/config/kernel_versions.json`](.github/config/kernel_versions.json). A single `kernel_version` input at workflow dispatch drives the entire build matrix — including Kernel version, Sub-level, Compiler, Rust availability, and AnyKernel3 branch selection.

---

## 📦 Build Variants

| Variant | Source | SUSFS | Droidspaces | Hook Strategy |
| :--- | :--- | :--- | :--- | :--- |
| `MidoriSU` | [midori01/KernelSU](https://github.com/midori01/KernelSU) | ❌ | ❌ | Kprobes |
| `MidoriSU-DS` | [midori01/KernelSU](https://github.com/midori01/KernelSU) | ❌ | ✅ | Kprobes |
| `MidoriSU-SUSFS` | [midori01/KernelSU](https://github.com/midori01/KernelSU) | ✅ | ❌ | Inline |
| `MidoriSU-SUSFS-DS` | [midori01/KernelSU](https://github.com/midori01/KernelSU) | ✅ | ✅ | Inline |
| `MidoriXX` | [backslashxx/KernelSU](https://github.com/backslashxx/KernelSU) | ❌ | ❌ | Manual* |
| `MidoriXX-DS` | [backslashxx/KernelSU](https://github.com/backslashxx/KernelSU) | ❌ | ✅ | Manual* |
| `MidoriXX-SUSFS` | [backslashxx/KernelSU](https://github.com/backslashxx/KernelSU) | ✅ | ❌ | De-inlined* |
| `MidoriXX-SUSFS-DS` | [backslashxx/KernelSU](https://github.com/backslashxx/KernelSU) | ✅ | ✅ | De-inlined* |
| `MidoriRE` | [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) | ❌ | ❌ | Manual* |
| `MidoriRE-DS` | [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) | ❌ | ✅ | Manual* |
| `MidoriRE-SUSFS` | [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) | ✅ | ❌ | Inline* |
| `MidoriRE-SUSFS-DS` | [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) | ✅ | ✅ | Inline* |

> \* **MidoriXX & MidoriRE Hook Strategy:** Runtime-configurable via `hook_mode`.
> - `manual` — default for both variants
> - `hookless` — MidoriXX 6.12 only
> - `tracepoint` — MidoriRE only

> [!TIP]
> **Matrix Build Orchestration:** The matrix always produces exactly **1 artifact per variant** — the enabled features (Droidspaces and/or SUSFS) are applied to that single artifact. With all 3 variants selected, this yields **3 builds per kernel version**. Choosing `all` from the `kernel_version` dropdown compiles 6.1, 6.6 and 6.12 in parallel for a total of **9 concurrent jobs**.

---

## 🔧 Hook Strategy Reference

| Strategy | Mechanism | Characteristics |
| :--- | :--- | :--- |
| **Kprobes** | KernelSU native kprobe-based dynamic instrumentation. | Minimal kernel footprint. Broad kernel version compatibility. Default for MidoriSU (non-SUSFS). |
| **Inline** | Compile-time static injection via `#ifdef CONFIG_KSU_SUSFS` blocks embedded directly into kernel subsystem source. Uses `static_key` branches for runtime toggling. | No reliance on kprobes or LSM hooks. SUSFS logic is hardwired into core paths including VFS (`exec`, `open`, `stat`, `readdir`, `statfs`), SELinux (`avc`, `hooks`, `services`), input, mounts, and procfs. Used by MidoriSU-SUSFS and MidoriRE-SUSFS. |
| **De-inlined** | SUSFS hooks applied via kernel source patching rather than inline `#ifdef` blocks. | Cleaner separation of SUSFS logic from core kernel subsystems. Used by MidoriXX-SUSFS variants. |
| **Manual** | Static kernel source patching. | Custom hooks injected at compile time into core kernel subsystems. Used by MidoriRE (non-SUSFS) and MidoriXX (default). |
| **Hookless** | Pure KernelSU built-in mechanisms. Enables `CONFIG_KSU_HACK_ARM64_BRANCH_LINK`. | Zero kernel source modification. Relies entirely on KernelSU's internal hooking infrastructure. Available for MidoriXX via `hook_mode: hookless`. |
| **Tracepoint** | KernelSU tracepoint-based hooking via `CONFIG_KSU_TRACEPOINT_HOOK`. | Zero kernel source modification. Relies on tracepoint infrastructure. Available for MidoriRE via `hook_mode: tracepoint`. |

---

## 🧩 Additional Features

| Feature | Description |
| :--- | :--- |
| **Kernel Version** | Select `6.1`, `6.6`, `6.12`, or `all` to compile one or all kernel versions. Sub-level, revision, compiler, and Rust settings are auto-resolved from the centralized config. |
| **Source Mirror** | Choose between Google's official AOSP mirror or a self-hosted mirror for kernel source and toolchain downloads. |
| **eBPF Scene Hider** | Optionally compiles and packages [Scene Port Hider by eBPF](https://github.com/Andrea-lyz/Scene-Port-Hider-by-eBPF) alongside kernel artifacts. Spins up as soon as the first kernel build completes, independent of the remaining matrix jobs. |
| **SUSFS Module** | When SUSFS is enabled, automatically fetches the latest [susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) and attaches it to the release. A single `susfs_commit` input controls SUSFS versions across variants. |
| **KSU Toolkit** | Automatically fetches the latest [ksu_toolkit](https://github.com/backslashxx/ksu_toolkit) module from nightly.link and attaches it to the release. |
| **Droidspaces** | Container support via [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) — SYSVIPC, IPC_NS, PID_NS, DEVTMPFS, NTSync, and networking. Enabled per-variant through the `use_droidspaces` toggle. |
| **ReKernel** | Integrated [Re:Kernel](https://github.com/Sakion-Team/Re-Kernel) module compiled directly into the kernel. Provides tombstone freeze recovery and optional network-triggered unfreeze. Toggled via `use_rekernel` switch. |
| **Ccache** | Compiler cache integration with a 60-second wait guard for dependency installation, ensuring robust accelerated incremental rebuilds across workflow runs. |
| **Spoofed Build Metadata** | Customizable `kernel name`, `build timestamp`, `user`, and `host` strings for the compiled image. |

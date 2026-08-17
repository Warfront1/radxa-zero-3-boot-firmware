# radxa-zero-3-boot-firmware

Deterministic, source-auditable boot firmware for the Radxa ZERO 3E and ZERO 3W
(both `rk3566`) — mainline U-Boot + open-source TF-A BL31.

## Comparing boot firmware options

| Option | <abbr title="The boot loader for embedded boards — does what a PC's BIOS and GRUB do together: initialize hardware, then load the Linux kernel.">U-Boot</abbr> | <abbr title="Boot Loader stage 3-1 — ARM runtime firmware at EL3 that handles power management and stays resident alongside the OS">BL31</abbr> |
| --- | :---: | :---: |
| [Radxa vendor](https://github.com/radxa/u-boot/tree/next-dev-v2024.10) | [⚠](https://github.com/radxa/u-boot/tree/next-dev-v2024.10 "Vendor fork, not mainline U-Boot") | [❌](https://github.com/radxa/u-boot/blob/3a6d3179b16dfc65a81c883c3ad1ba45a5e082ed/make.sh#L551-L554 "Precompiled binary from rockchip-linux/rkbin — compiled from Rockchip's internal unpublished source") |
| [Armbian](https://github.com/armbian/build/blob/main/config/boards/radxa-zero3.conf) | [✅](https://github.com/armbian/build/blob/main/config/boards/radxa-zero3.conf "Mainline U-Boot v2025.10") | [❌](https://github.com/armbian/build/blob/aabb6c5121b5314b9579ebde285010574f19022d/config/boards/radxa-zero3.conf#L36 "Precompiled binary from rockchip-linux/rkbin — compiled from Rockchip's internal unpublished source") |
| [DietPi](https://github.com/MichaIng/DietPi) | [✅](https://github.com/MichaIng/DietPi "Mainline U-Boot (inherits Armbian build)") | [❌](https://github.com/MichaIng/DietPi/blob/e231129f99a38d6c6a4ec4b8c9024f27f42708b2/.build/images/dietpi-installer#L1298 "Precompiled binary from rockchip-linux/rkbin — compiled from Rockchip's internal unpublished source") |
| **[This repo](https://github.com/u-boot/u-boot/blob/v2026.07/configs/radxa-zero-3-rk3566_defconfig)** | [✅](https://github.com/u-boot/u-boot/blob/v2026.07/configs/radxa-zero-3-rk3566_defconfig "Mainline U-Boot v2026.07") | [✅](https://github.com/ARM-software/arm-trusted-firmware/blob/master/docs/plat/rockchip.rst "Open-source TF-A, built from source with PLAT=rk3568") |

*✅ = upstream open source, ⚠ = open-source vendor fork, ❌ = closed-source blob.  
All options use a closed rkbin DDR blob — no open alternative exists for RK3566.*

<details>
<summary><b>Anatomy of this Repo's Bootloader</b></summary>

`u-boot-rockchip.bin` is the single flashable file. Here's what's in it (in boot order):
1. **RKNS header (0x0)** — the Rockchip BootROM's table of contents: where TPL and SPL live, plus their hashes. The BootROM reads this first on power-up.
2. **TPL (0x1000)** — the proprietary `rk3566_ddr_1056MHz_v1.25.bin` from rkbin. The one closed piece. Its only job: initialize DDR RAM so anything else can run. No open-source replacement exists for RK3566.
3. **SPL (0x8000)** — U-Boot's Secondary Program Loader. Runs once DRAM is up. Loads the FIT from flash, places each node at the right physical address, then jumps to BL31 → U-Boot proper.

   *(BL31 = "Boot Loader stage 3-1" — ARM runtime firmware at the highest privilege level, EL3. It stays resident in memory after boot, and the OS calls into it for power management — suspend/resume, shutdown, reboot. Most other builds ship a closed-source Rockchip BL31; this build uses the open-source TF-A BL31 instead.)*
4. **SPL DTB (0x30200)** — a small device tree SPL itself uses (to find the FIT, serial UART config, etc.) — separate from the main board DTBs in the FIT.
5. **FIT (0x7F8000)** — the payload:
   - **U-Boot proper** — the U-Boot you interact with at the serial prompt, and that loads your Linux kernel.
   - **BL31 (TF-A)** — the open-source TF-A `bl31.elf` (lts-v2.14.6, `PLAT=rk3568`). This replaces the closed rkbin BL31 that vendor images ship.
   - **rk3566-radxa-zero-3e.dtb & -3w.dtb** — the two board device trees. SPL picks one at runtime via ADC board-id reading.

</details>

## Build

```
docker build -t radxa-zero3-boot-firmware .
mkdir -p out
docker run --rm -v "$PWD/out:/out" -e BUILD_DIR=/build -e OUT_DIR=/out radxa-zero3-boot-firmware
```

See [BUILD_VERIFICATION.md](BUILD_VERIFICATION.md) for artifact verification.
<details>
<summary><b>Manually Flashing to the Boot Device</b></summary>

> **Not an operating system.** This repo produces only the boot firmware — the code that initializes the board and loads your OS. You still need a Linux distribution (e.g., Debian, DietPi, Ubuntu) to run on it.

Write the single image to the raw device at sector 64 (offset `0x8000`).
**Not** to a partition. Replace `/dev/sdX` with your device.

```
sudo dd if=out/u-boot-rockchip.bin of=/dev/sdX seek=64 bs=512 conv=notrunc
sync
```

</details>
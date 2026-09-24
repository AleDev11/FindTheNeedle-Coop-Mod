# Nexus Mods — manual file review request

Send to **support@nexusmods.com** (keep the subject line, it helps them route it).
Update the version, SHA256 and mod link if you upload a newer file.

---

**Subject:** Quarantined file — manual review request — Find The Needle Co-op Multiplayer (AleDev11)

Hello,

My mod's download has been quarantined and I would like to request a manual
review. I believe the flags come from the installer script and the two DLLs the
mod needs, so here is exactly what is in the archive and where each binary comes
from.

**Mod page:** https://www.nexusmods.com/games/10302/mods/1
**Mod:** Find The Needle Co-op Multiplayer
**Author:** AleDev11
**File:** FindTheNeedle_Multiplayer_v0.4.0.zip (1.4 MB)
**SHA256:** 487F24E4342CA55F79F546868E6370A60AB6F369BA89A781844D80723F7EEBBC

The mod is fully open source, so every file in the archive can be checked
against the repository, which also has the complete history:
https://github.com/AleDev11/FindTheNeedle-Coop-Mod

**What the archive contains**

- `mp.gd`, `mp_ui.gd`, `mp_world.gd`, `mp_avatar.gd`, `mp_steam.gd` — plain-text
  GDScript, the mod itself. The game (a Godot 4 title) loads them at startup.
- `INSTALL.bat` / `UNINSTALL.bat` (and the two Spanish one-line wrappers) — the
  installer. It is short and readable on purpose: it adds one line to the game's
  `override.cfg` so Godot loads the mod, and the uninstaller removes it. It
  downloads nothing, needs no admin rights, touches no registry key, makes no
  network call and copies no files. Earlier versions called PowerShell; I removed
  that in v0.4.0 precisely so the installer is easy to audit.
- `steam/win64/libgodotsteam.windows.template_release.x86_64.dll` — GodotSteam,
  the open-source (MIT) Steamworks plug-in for Godot. This is the official
  prebuilt release, unmodified:
  https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.22.1-gde
- `steam/win64/steam_api64.dll` — Valve's Steamworks SDK redistributable, as
  shipped inside that same GodotSteam package.
- `godotsteam.gdextension`, `README.txt`, `LEEME.txt` — text files.

**Why the DLLs are needed**

The mod adds co-op multiplayer to the game's demo. The demo ships without the
Steam API, so the mod loads GodotSteam at runtime to use Steam's relay network
for the connection. That is what lets players invite each other from the Steam
friends list instead of forwarding a port or exchanging IP addresses.

**One related note:** the game itself, *Find The Needle* (free demo on Steam),
was not in your catalogue, so I submitted it as a suggested game when I created
the page. The mod is currently "awaiting approval" for that reason. If both can
be looked at together, all the better.

I am happy to answer any question or to split the download differently if that
helps, for example shipping the mod without the GodotSteam files and asking users
to download them from the official GodotSteam release themselves.

Thank you for your time,
AleDev11

# Changelog

## v0.3.0

- **Streamer safety:** the panel no longer prints IP addresses, Steam IDs or
  lobby codes. Local addresses only appear after pressing *Show my IPs*, which
  lives in the advanced section.
- **Clearer panel:** numbered steps (create game → invite friends → start
  playing) with the current one highlighted, and the IP mode folded away as an
  advanced option.
- English installer scripts (`INSTALL.bat` / `UNINSTALL.bat`) beside the
  Spanish ones.

## v0.2.0

- **Steam networking.** Hosting, invites and joining now go through Steam's
  relay: no port forwarding, no IPs, no VPN. The mod loads the GodotSteam
  GDExtension at runtime and initialises Steam under the demo's app id.
- Invite from the Steam overlay, from the friends list, or by accepting an
  invite while the game is closed.
- Player names come from Steam.
- Loose needles are shared: uncovered needles show up for everyone and can only
  be handed in once.
- Clients spawn at the game's normal starting spot.
- Remote players got arms and hold their tool properly.
- Panel rebuilt: centred, dimmed background, no more broken labels.

## v0.1.0

- First working co-op build over direct IP (ENet).
- Shared haystack, buildings, economy and tech tree.
- The host's world is handed to joining players through the game's own save
  format; clients never write to their own saves.
- Remote player avatars with name tags, chat (`Y`), resync (`F8`).

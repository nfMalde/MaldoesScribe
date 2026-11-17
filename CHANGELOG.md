# Changelog

All notable changes to Maldö's Scribe. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The release workflow takes the `## [x.y.z]` section of the version being released as the release notes and
refuses to release a version that has none, so move the `## [Unreleased]` entries into a version section first.

## [Unreleased]

## [1.0.0] - 2026-11-16

### Added

- Copy window in the Maldö look: movable, resizable, text highlighted on open, variants (Text, Name, ID,
  Wowhead) as a row of buttons, Select all, Refresh, Escape closes.
- Chat: a quill button in the corner of every chat window copies its history as plain text; web addresses in
  chat are clickable and open the window with the address.
- Copy buttons beside the quest window, the quest log, NPC dialogues, books and plaques, the guild window and
  the tooltip of a chat link.
- Guild: message of the day, guild information and the member list (tab-separated).
- Mail: the open letter (sender, subject, text, money, attachments), its body, the draft being written and
  the inbox as a table; macros: the open macro's text; the party or raid as names or a table.
- Player and NPC names: "Copy name" in the right-click menus of portraits, targets, party and raid members,
  guild members and names in chat; Alt+click on a name in chat. Forever's "First Last" names come whole,
  with the first name and the surname as extra variants.
- Tooltips: a key binding copies the tooltip under the mouse (name, full text, id, Wowhead); an optional
  hint line in item tooltips shows the key.
- Key bindings: copy what is open, copy the tooltip, copy the chat.
- Commands `/scribe` (alias `/copy`), options page, error report (`/scribe log`), `/scribe mouse`.
- English and German.

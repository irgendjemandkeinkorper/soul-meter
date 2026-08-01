# Localization smoke test

**Scope:** Godot PO loading, item-key fallback, and the two-template boundary.

- In the editor, open **Project Settings → Localization → Template Generation**. Confirm the
  configured `.dialogue` and quest `.tres` sources are present, then choose **Generate** and
  write the engine-owned output to `locale/project.pot`.
- Confirm `locale/project.pot` contains at least one dialogue string from
  `dialogue/marshal_coiljaw.dialogue` and one quest string, while item keys remain in
  `data/generated/items.pot`.
- Start a fresh game, open Inventory, and confirm every item has a non-blank name and
  description. With no Spanish `msgstr` values, the UI must show the Pandora English fallback.
- Add a temporary Spanish `msgstr` for one `ITEM_*_NAME` entry, switch the locale to `es`, and
  reopen Inventory. Confirm the translated item uses the Spanish text and untranslated items
  retain the fallback. The Settings screen exposes this as **Language → Español**.
- Switch back to **English**, quit and relaunch, then confirm Settings retains the selected
  locale and the item returns to its English source text.
- Change an English item source in Pandora, regenerate, and confirm the corresponding Spanish
  row is retained and marked `#, fuzzy` in `locale/es.po`.

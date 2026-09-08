# Field verbs — manual smoke test

Covers the F4 field verbs (#284, `docs/game-identity.md` ruling 7: *"Skill checks on
objects, lockpicking, stealing, barter, loot. Stats matter outside combat."*).

The automated suites (`test_skill_locked_containers.gd`, `test_pickpocket.gd`,
`test_vendor_pricing.gd`) cover the resolution logic. **This checklist covers what they
cannot: that the verb is reachable at all** — prompt visible, key bound, consequence
legible to a player who is not reading the flag store.

Each verb resolves ONE committed check. Once you have run a case, that target is spent
for the save — start a fresh game to re-run it, or the second pass proves nothing.

---

## 1. Skill-locked container (#414)

**Target:** `CampCache` on Dorthkor Road. Rolls `strain`.

- [ ] Walk to the cache. The interact prompt appears.
- [ ] Press **E**. Exactly one of two things happens, and it is obvious which:
      the cache opens, or the failure message shows and it does not.
- [ ] Press **E** again. The outcome does **not** change and no new roll happens.
      A cache that opens on the second press is the bug this mechanic exists to prevent.
- [ ] Leave the scene, come back, press **E**. Still unchanged.
- [ ] Save, reload, press **E**. Still unchanged. *(The outcome rides the flag store,
      so a reload that re-rolls means the flag is not being persisted.)*

## 2. Pickpocket (#284, this PR)

**Target:** Toma Reedhand, Dom. Rolls `slip`. Purse is 9 gp, no item, no faction.

- [ ] Walk into range. The prompt reads **`E — Talk    F — Steal`**.
- [ ] Press **E** first. Dialogue opens normally — the steal verb has not
      displaced talking to him.
- [ ] Close the dialogue. Press **F**.
- [ ] On success: silver goes up by 9. Check the purse, not the log.
- [ ] On failure: silver is unchanged, and the Standing screen shows infamy
      has risen. *(Infamy only — this NPC deliberately ships with no
      `pocket_faction`, so no faction standing should move.)*
- [ ] The prompt loses its `F — Steal` half. The pocket is spent either way.
- [ ] Press **F** again. Nothing happens — no roll, no silver, no infamy.
- [ ] Save, reload, press **F**. Still nothing.

## 3. Barter (#415)

**Target:** any vendor. Reads the protagonist's `sway`.

- [ ] Open a shop. Note the listed price of one item.
- [ ] Buy it. **The silver deducted equals the price displayed.** This is the
      guarantee worth checking by hand — a mismatch here is invisible in code
      review and obvious at the till.
- [ ] Sell something. Same check in the other direction.
- [ ] Reorder the party so the protagonist is not first, reopen the shop.
      **Prices are unchanged.** *(Barter reads the protagonist, not `party[0]`.)*
- [ ] With a Virtuous Karma standing, prices are slightly better than at
      Uncertain. *(Sway carries a `karma_direction`, RFC-0007 §6 — this is the
      Karma ledger reaching the economy.)*

---

## What is deliberately not covered here

**Loot tables** — verb 4 of 4, not yet built.

**Loom-sensitive degradation in Hush/Waning zones** — moved to #349 (AccordZone) by the
2026-09-08 ruling. `SkillCheck.loom_penalty()` is a live hook returning 0; none of the
three verbs above roll a Loom-sensitive skill today (`strain`, `slip` and `sway` are all
`LoomSensitivity.NONE`), so there is nothing to observe until #349 lands.

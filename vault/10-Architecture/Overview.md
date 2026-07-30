---
type: architecture
updated: 2026-07-21
---

# Architecture: Soul Meter — System Overview

> **TL;DR:** Offline single-player Godot 4.7 CRPG. Mostly *designed*, barely implemented — the design doc is the spec. No scripts or main scene exist yet.

## The shape

```mermaid
flowchart LR
  DOC["design doc<br/>source of truth"]:::artifact
  subgraph G["Godot 4.7 — single-player, local"]
    P["project.godot<br/>no main scene set"]:::planned
    SC["node_2d.tscn<br/>empty placeholder"]:::planned
    GS["game-state singleton<br/>dialogue · flags · Soul Meter"]:::planned
    B["battle scene<br/>turn-based"]:::planned
  end
  P --> SC
  DOC -.->|defines| GS
  GS -.->|planned| B
  classDef client fill:#16324f,stroke:#4a9eff,color:#dbeafe;
  classDef server fill:#16371f,stroke:#4ade80,color:#dcfce7;
  classDef data fill:#3a2f14,stroke:#fbbf24,color:#fef3c7;
  classDef external fill:#3a1630,stroke:#f472b6,color:#fce7f3;
  classDef artifact fill:#2a2440,stroke:#a78bfa,color:#ede9fe;
  classDef planned fill:#1a1f2b,stroke:#64748b,color:#94a3b8,stroke-dasharray:4 3;
```

## Scope & surface
- **Trust boundary:** none — offline desktop game, no network or backend.
- Almost everything is **planned**: no `.gd` scripts, no `run/main_scene`, one empty `node_2d.tscn`.
- Per design §9, global state (dialogue engine + flag store + Soul Meter) should be one serialized autoload singleton, built chassis-agnostic first.

## Where things live
See `CLAUDE.md` (L0 map) and `soul-meter-crpg-design-doc.md` (the authoritative design). Read the relevant design-doc section before adding any mechanic.

## Related
- [[00-Index/Home]]

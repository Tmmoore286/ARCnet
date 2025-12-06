# Data Feeds & Org Import — Guide

MVP uses multiple inputs:
- Authoritative org structure from the USMC Org Pack (not synthetic) imported via `USMCOrgImporter`.
- Commander inputs (MissionContext) and doctrinal references (by billet/MOS) linked from Ref‑Packs (not synthetic) and persisted/linked before use.
- Synthetic JSON data feeds for dynamic metrics read by `SyntheticDataGateway` and ingested by `FeedImporter` when connectors are disabled.

Files (planned — synthetic feeds only)
- `readiness.json` — DRRS‑like readiness snapshots per unit
- `funds.json` — DAI‑like funds control snapshots
- `comms.json` — network health status
- `missions.json` — canned missions for synthetic mode flows

Shapes (indicative — dynamic only)
```json
// units.json (array)
[{
  "id": "I-MEF",
  "name": "I MEF",
  "type": "MEF",
  "parentId": null,
  "children": ["1stMARDIV", "3dMAW", "1stMLG"]
}]

// readiness.json (map by unitId)
{
  "1stMARDIV": { "overall": 0.82, "personnel": 0.88, "equipment": 0.77, "date": "2025-01-15" }
}

// funds.json (map by unitId)
{
  "1stMLG": { "obligationsPct": 0.61, "burnRate": 0.07, "fiscalMonth": 4 }
}

// comms.json (map by unitId)
{
  "3dMAW": { "netHealth": "GREEN", "latencyMs": 42, "emcon": false }
}

// missions.json (array)
[{ "id": "synthetic-01", "missionStatement": "Conduct HA/DR in coastal AO...", "acceptanceCriteria": ["stability in AO"], "constraints": ["no kinetic ops"], "endState": "civ relief established" }]
```

USMC Org Import (authoritative)
- Location: `Ref-Packs/USMC_Org_Pack/Services/org_templates/*.json` (see schema in the same folder).
- Importer: `USMCOrgImporter` reads templates, persists units/billets to CoreData, and stores provenance.
- User selects “My Unit”; the app scopes views to that subtree.

Notes
- Keep synthetic feed values plausible but fictional; avoid real PII or operational data.
- Include a `version` field at the root of each synthetic feed for future migrations.
- All sources are materialized into CoreData first (SSOT) before UI reads.

# Ref-Packs Download Report (ARCnet)

Date: 2025-10-19

Summary
- Executed reference download scripts under `Ref-Packs/`.
- Many official `marines.mil` endpoints returned HTTP 403 (forbidden) to curl even with browser user-agent and referer headers.
- Non-DoD/public endpoints succeeded (e.g., TNSR, CNAS, some Boyd papers).
- Created helper script `Ref-Packs/download_all_from_manifests.sh` to pull from ARCnet CSV manifests; it also encountered 403 on most `marines.mil` links.

What ran
- Project_CENTAUR_Ref_Pack_2: `download_references.sh` (patched to use UA/Referer). Output dir: `Ref-Packs/Project_CENTAUR_Ref_Pack_2/refs/`.
- Project_CENTAUR_Support_Pack: `download_support_refs.sh` (patched UA/Referer). Output dir: `Ref-Packs/Project_CENTAUR_Support_Pack/support_refs/` (403 blocked; dir may not exist if first fetch failed).
- Project_CENTAUR_Ref_Package: `download_sources.sh` (stub; created directory only). Output dir: `Ref-Packs/Project_CENTAUR_Ref_Package/docs/`.
- Unified: `Ref-Packs/download_all_from_manifests.sh all_refs` → output dir: `Ref-Packs/all_refs/`.

Successful downloads (examples)
- `Ref-Packs/all_refs/Robert_Work_–_Marine_Force_Design__Changes_Overdue_(TNSR).html`
- `Ref-Packs/all_refs/CNAS_–_Force_Design_Commentary_(mirror).html`
- `Ref-Packs/all_refs/Boyd_–_Destruction_and_Creation_(1976).pdf`

Common failures
- Most `https://www.marines.mil/Portals/1/Publications/...` PDF links (403)
- `https://www.cmc.marines.mil/FRAGO-01-2024/` (403)
- `https://www.cdi.marines.mil/News/Article/...` (403)

Why 403 happens
- These domains often enforce anti-bot protections and require an interactive browser session (cookies/JS) or specific network conditions.

Remediation options
- Run downloads locally in a desktop browser session, saving files into the corresponding `refs/` folders.
- Use a headless browser (e.g., Playwright) to fetch PDFs with proper cookies; I can add a tooling script if desired.
- Identify alternate mirrors (DTIC, public university mirrors) where available; update manifests to mirror URLs.
- If you prefer command-line only, I can try a cURL + cookie-jar flow tailored per host, but success is not guaranteed.

Next steps (proposed)
- Confirm whether to add a Playwright-based fetcher and/or mirror URLs.
- If provided with a VPN or whitelisted IP, re-run `download_all_from_manifests.sh` to populate missing files.
- Once sources are collected, I’ll add a README index and hash manifest for integrity.


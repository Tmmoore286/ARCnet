# ARCnet References

A clean, unified reference pack for ARCnet organized by manifests (sources) and downloads (artifacts).

- manifests/
  - core_doctrine_manifest.csv — Core doctrine, policy, and T&R publications
  - modernization_manifest.csv — Force Design 2030 and related modernization sources
  - support_manifest.csv — Engineer, Aviation, Recon, HSS/Medical, TAOC, etc.
- downloads/
  - core/ — Files fetched from core_doctrine_manifest.csv
  - modernization/ — Files fetched from modernization_manifest.csv
  - support/ — Files fetched from support_manifest.csv
- scripts/
  - download_all_with_playwright.mjs — Headless browser downloader (Chromium)
  - download_all_from_manifests.sh — cURL helper (works for many public mirrors)
- docs/
  - Arcnet_Architecture_v3.md, Arcnet_Architecture_v4.md — Architecture notes
  - Download_Report.md — Last run summary and notes

Usage
- Install (first time):
  - cd Ref-Packs
  - npm install (already set up with Playwright)
  - npx playwright install --with-deps chromium
- Download all:
  - npm run download

Notes
- Some sources return HTML landing pages by design (no direct PDF).
- For any broken URLs, update the corresponding manifest. Checksums and index can be added on request.

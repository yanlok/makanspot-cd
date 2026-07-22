Put your Apify TikTok scraper JSON export(s) in THIS folder, then run
run_pipeline.cmd (in the project root) or:  node scripts/run_pipeline.mjs

- The script automatically picks the NEWEST *.json file here.
- To use a specific file instead:  node scripts/run_pipeline.mjs "path\to\file.json"
- Re-running is safe: already-ingested posts are skipped (dedup on video URL).

These *.json exports are git-ignored so large datasets are never committed.

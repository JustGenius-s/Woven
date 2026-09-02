# NOTICE — Vocabulary sources

The bundled vocabulary files keep JMdict identifiers and the existing Chinese
glosses. Pitch accent was merged from the open sources below. See
`docs/VOCABULARY_SCHEMA.md` for the field layout.

If you use this data, credit the upstream projects and keep ShareAlike terms.

## Sources

| Source | Used for | License | Link |
|---|---|---|---|
| **JMdict / EDICT** — EDRDG | Word IDs, writings, readings, commonness and newspaper/ichi priority used to grade extras | CC BY-SA 4.0 | https://www.edrdg.org/ |
| **jmdict-simplified** — scriptin | Machine-readable JMdict common subset used to build extra-daily/general/supplement | CC BY-SA 4.0 | https://github.com/scriptin/jmdict-simplified |
| **Jonathan Waller's JLPT Resources** | Unofficial N5–N1 level tags | CC BY | https://www.tanos.co.uk/jlpt/ |
| **WadokuJT** — Wadoku e.V. | Primary Tokyo pitch accent | CC BY-SA 3.0 | https://github.com/WaDoku/WaDokuJT-Data |
| **Kanjium** — Uros O. | Pitch fallback when Wadoku has no exact match | CC BY-SA 4.0 (author claim) | https://github.com/mifunetoshiro/kanjium |

Kanjium is used only as a gap fill. Its pitch file is widely reused, but parts
of it are believed to reflect commercial accent dictionaries. Prefer Wadoku
when the two sources disagree.

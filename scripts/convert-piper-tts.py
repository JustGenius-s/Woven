#!/usr/bin/env python3
"""Add sherpa-onnx Piper metadata and emit tokens.txt."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def generate_tokens(config: dict, dest: Path) -> None:
    id_map = config["phoneme_id_map"]
    lines: list[str] = []
    for symbol, value in id_map.items():
        # sherpa-onnx ReadTokens() requires one Unicode scalar per line and
        # calls SHERPA_ONNX_EXIT(-1) otherwise. Piper also maps diphthongs
        # such as aɪ / oʊ; skip those plus the newline placeholder.
        if symbol in ("\n", "") or len(symbol) != 1:
            continue
        token_id = value[0] if isinstance(value, list) else value
        if symbol == " ":
            lines.append(str(token_id))
        else:
            lines.append(f"{symbol} {token_id}")
    dest.write_text("\n".join(lines) + "\n", encoding="utf-8")


def add_meta_data(model_path: Path, meta_data: dict[str, object]) -> None:
    import onnx

    model = onnx.load(str(model_path))
    while len(model.metadata_props):
        model.metadata_props.pop()
    for key, value in meta_data.items():
        item = model.metadata_props.add()
        item.key = key
        item.value = str(value)
    onnx.save(model, str(model_path))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--onnx", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--tokens", required=True, type=Path)
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
    generate_tokens(config, args.tokens)

    sample_rate = config["audio"]["sample_rate"]
    if sample_rate == 22500:
        sample_rate = 22050
    voice = config.get("lang_code")
    if not voice:
        voice = config.get("espeak", {}).get("voice", "ja")
    if voice == "ja_JA":
        voice = "ja"

    add_meta_data(
        args.onnx,
        {
            "model_type": "vits",
            "comment": "piper",
            "language": "Japanese",
            "voice": voice,
            "version": 1,
            "has_espeak": 1,
            "has_g2pw": 0,
            "n_speakers": config.get("num_speakers", 1),
            "sample_rate": sample_rate,
        },
    )


if __name__ == "__main__":
    main()

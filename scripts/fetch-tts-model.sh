#!/bin/sh
# Download the official Piper Japanese voice and pack it for sherpa-onnx.
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dest_dir="$project_dir/entry/src/main/resources/rawfile/tts/vits-piper-ja"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

onnx_url='https://huggingface.co/rhasspy/piper-voices/resolve/main/ja/ja_JA/hi_fi_captain/medium/ja_JA-hi_fi_captain-medium.onnx'
config_url='https://huggingface.co/rhasspy/piper-voices/resolve/main/ja/ja_JA/hi_fi_captain/medium/ja_JA-hi_fi_captain-medium.onnx.json'
espeak_url='https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/espeak-ng-data.tar.bz2'

mkdir -p "$dest_dir"
echo "Downloading Piper ja_JA-hi_fi_captain-medium..."
curl -L --fail -o "$work_dir/model.onnx" "$onnx_url"
curl -L --fail -o "$work_dir/model.onnx.json" "$config_url"

python3 -m pip install --quiet --user 'onnx>=1.16'
python3 "$project_dir/scripts/convert-piper-tts.py" \
  --onnx "$work_dir/model.onnx" \
  --config "$work_dir/model.onnx.json" \
  --tokens "$work_dir/tokens.txt"

echo "Downloading espeak-ng-data..."
curl -L --fail -o "$work_dir/espeak-ng-data.tar.bz2" "$espeak_url"
tar -xjf "$work_dir/espeak-ng-data.tar.bz2" -C "$work_dir"

rm -rf "$dest_dir/espeak-ng-data"
cp "$work_dir/model.onnx" "$dest_dir/model.onnx"
cp "$work_dir/tokens.txt" "$dest_dir/tokens.txt"
cp -R "$work_dir/espeak-ng-data" "$dest_dir/espeak-ng-data"

echo "Installed TTS model to $dest_dir"
echo "Next: in the entry module run  ohpm install"

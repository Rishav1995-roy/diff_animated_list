#!/bin/sh
# Regenerates doc/demo.gif and the screenshots. Needs fvm + ffmpeg.
set -e
cd "$(dirname "$0")/.."
rm -rf build/demo_frames
fvm spawn 3.47.7 test --run-skipped -t demo tool/make_demo_test.dart
ffmpeg -y -loglevel error -framerate 15 -i build/demo_frames/f%04d.png \
  -vf "scale=360:-1:flags=lanczos,palettegen=max_colors=128:stats_mode=diff" build/palette.png
ffmpeg -y -loglevel error -framerate 15 -t 10 -i build/demo_frames/f%04d.png -i build/palette.png \
  -lavfi "scale=360:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" doc/demo.gif
ls -l doc

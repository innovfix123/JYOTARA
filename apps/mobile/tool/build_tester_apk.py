#!/usr/bin/env python3
"""Build the restricted Android tester APK with matching visible version metadata."""
import argparse, re, subprocess
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('build_number',type=int)
parser.add_argument('--flutter',default='flutter')
args=parser.parse_args()
if args.build_number<1:parser.error('Positive build number required')
root=Path(__file__).resolve().parents[1]
match=re.search(r'^version:\s*([^+\s]+)',(root/'pubspec.yaml').read_text(),re.M)
if not match:raise SystemExit('Package version not found')
label=f'{match.group(1)}+{args.build_number}'
subprocess.run([args.flutter,'build','apk','--debug',f'--build-number={args.build_number}',
 '--dart-define=JYOTARA_API_BASE_URL=https://168.144.64.47',
 '--dart-define=JYOTARA_REQUIRE_TESTER_ACCESS=true',f'--dart-define=JYOTARA_BUILD_LABEL={label}'],cwd=root,check=True)
print('Built internal candidate '+label+'. Preserve the established QA signing identity before distribution.')

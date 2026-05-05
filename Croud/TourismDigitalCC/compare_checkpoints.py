"""Compare YOLO checkpoints by running validation and printing metrics.

Usage:
  python compare_checkpoints.py --models best-2.pt best_final.pt [--data path/to/data.yaml]

If --data is not provided the script will try to discover a `data:` entry
from `runs/detect/*/args.yaml` files created during training.
"""
import argparse
import json
import os
import re
from pathlib import Path

try:
    from ultralytics import YOLO
except Exception as e:
    raise RuntimeError('ultralytics package required. Activate venv and install ultralytics')


def discover_data_yaml():
    # look for runs/detect/*/args.yaml and extract data: line
    base = Path(__file__).parent / 'runs' / 'detect'
    if not base.exists():
        return None
    args_files = sorted(base.rglob('args.yaml'), key=lambda p: p.stat().st_mtime, reverse=True)
    for p in args_files:
        try:
            text = p.read_text(encoding='utf-8')
            m = re.search(r'^data:\s*(.+)$', text, flags=re.MULTILINE)
            if m:
                candidate = m.group(1).strip()
                # expand user and env
                candidate = os.path.expandvars(os.path.expanduser(candidate))
                if Path(candidate).exists():
                    return candidate
                # sometimes the path in args.yaml is absolute to other machine; try relative to repo
                alt = Path(__file__).parent / Path(candidate).name
                if alt.exists():
                    return str(alt)
                return candidate
        except Exception:
            continue
    return None


def run_val(model_path: str, data: str | None):
    print(f"\n== Evaluating {model_path} ==")
    if not Path(model_path).exists():
        print(f"Model not found: {model_path}")
        return None

    model = YOLO(model_path)

    # Run validation
    try:
        if data:
            print(f"Using data config: {data}")
            metrics = model.val(data=data)
        else:
            print("No data config provided — running model.val() with default/embedded config")
            metrics = model.val()
    except Exception as e:
        print(f"Validation failed for {model_path}: {e}")
        return None

    # metrics may be an object with results_dict or a list/dict
    results = None
    try:
        if hasattr(metrics, 'results_dict'):
            results = metrics.results_dict
        elif isinstance(metrics, dict):
            results = metrics
        else:
            # try to convert to dict
            results = getattr(metrics, '__dict__', None) or dict()
    except Exception:
        results = None

    # normalize common fields
    out = {
        'model': model_path,
        'mAP50': None,
        'mAP50-95': None,
        'precision': None,
        'recall': None,
        'raw': results,
    }

    if results:
        # ultralytics uses keys like 'metrics/mAP50(B)' in some outputs; try several common keys
        def getk(d, *keys):
            for k in keys:
                if k in d:
                    return d[k]
            return None

        out['mAP50'] = getk(results, 'metrics/mAP50(B)', 'metrics/mAP50', 'map50', 'mAP50')
        out['mAP50-95'] = getk(results, 'metrics/mAP50-95(B)', 'metrics/mAP50-95', 'map50_95')
        out['precision'] = getk(results, 'metrics/precision(B)', 'precision')
        out['recall'] = getk(results, 'metrics/recall(B)', 'recall')

    print("Results summary:")
    print(f"  mAP@0.5      : {out['mAP50']}")
    print(f"  mAP@0.5:0.95 : {out['mAP50-95']}")
    print(f"  Precision    : {out['precision']}")
    print(f"  Recall       : {out['recall']}")

    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--models', '-m', nargs='+', required=True, help='One or more checkpoint files to evaluate')
    parser.add_argument('--data', '-d', help='Path to data yaml used for validation (optional)')
    parser.add_argument('--out', '-o', help='Path to write JSON summary (optional)')
    args = parser.parse_args()

    data = args.data
    if not data:
        discovered = discover_data_yaml()
        if discovered:
            print(f"Discovered data config: {discovered}")
            data = discovered
        else:
            print("No data config discovered. Provide --data to run a labeled validation set.")

    results = []
    for m in args.models:
        res = run_val(m, data)
        results.append(res)

    # Print comparison table
    print('\n=== Comparison Table ===')
    header = f"{'model':40} {'mAP@0.5':>10} {'mAP@0.5:0.95':>14} {'prec':>8} {'recall':>8}"
    print(header)
    print('-' * len(header))
    for r in results:
        if not r:
            print(f"{str(r)}")
            continue
        print(f"{r['model'][:40]:40} {str(r['mAP50'])[:10]:>10} {str(r['mAP50-95'])[:14]:>14} {str(r['precision'])[:8]:>8} {str(r['recall'])[:8]:>8}")

    if args.out:
        Path(args.out).write_text(json.dumps(results, default=str, indent=2), encoding='utf-8')
        print(f"Wrote JSON summary to {args.out}")


if __name__ == '__main__':
    main()

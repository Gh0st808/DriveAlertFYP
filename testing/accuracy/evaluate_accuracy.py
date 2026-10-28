"""Evaluate observed DriveAlert trials; never generates trial data."""
import argparse
import csv
import hashlib
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

FIELDS = ['trial_id', 'ground_truth', 'prediction', 'lighting', 'evidence_file', 'notes']


def read_trials(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames is None or set(FIELDS) - set(reader.fieldnames):
            raise ValueError('CSV must contain: ' + ', '.join(FIELDS))
        rows, seen = [], set()
        for line, raw in enumerate(reader, 2):
            if None in raw:
                raise ValueError(f'Line {line}: extra CSV fields; quote notes containing commas.')
            if not any((value or '').strip() for value in raw.values()):
                continue
            row = {key: (raw.get(key) or '').strip() for key in FIELDS}
            if not row['trial_id'] or row['trial_id'] in seen:
                raise ValueError(f'Line {line}: trial_id must be nonempty and unique.')
            if row['ground_truth'] not in ('0', '1'):
                raise ValueError(f'Line {line}: ground_truth must be 0 or 1.')
            if row['prediction'] not in ('0', '1', 'no_prediction'):
                raise ValueError(f'Line {line}: prediction must be 0, 1 or no_prediction.')
            if not row['lighting']:
                raise ValueError(f'Line {line}: record a lighting condition.')
            seen.add(row['trial_id'])
            row['classification'] = ('NO_PREDICTION' if row['prediction'] == 'no_prediction'
                else {('0', '0'): 'TN', ('0', '1'): 'FP', ('1', '0'): 'FN', ('1', '1'): 'TP'}[
                    row['ground_truth'], row['prediction']])
            rows.append(row)
    if not rows:
        raise ValueError('No trials recorded. Fill trials.csv with real observations first. No results generated.')
    return rows


def evaluate(rows):
    from sklearn.metrics import accuracy_score, confusion_matrix, precision_recall_fscore_support
    valid = [r for r in rows if r['prediction'] in ('0', '1')]
    actual = [int(r['ground_truth']) for r in valid]
    predicted = [int(r['prediction']) for r in valid]
    matrix = confusion_matrix(actual, predicted, labels=[0, 1]) if valid else [[0, 0], [0, 0]]
    tn, fp, fn, tp = [int(matrix[i][j]) for i in range(2) for j in range(2)]
    if valid:
        precision, recall, f1, _ = precision_recall_fscore_support(
            actual, predicted, average='binary', pos_label=1, zero_division=0)
        accuracy = float(accuracy_score(actual, predicted))
        # Explicitly preserve undefined denominators rather than displaying misleading zeroes.
        precision = float(precision) if tp + fp else None
        recall = float(recall) if tp + fn else None
        f1 = float(f1) if 2 * tp + fp + fn else None
    else:
        accuracy = precision = recall = f1 = None
    return {'total_trials': len(rows), 'classified_trials': len(valid),
        'no_prediction_trials': len(rows) - len(valid),
        'no_prediction_positive': sum(r['prediction'] == 'no_prediction' and r['ground_truth'] == '1' for r in rows),
        'no_prediction_negative': sum(r['prediction'] == 'no_prediction' and r['ground_truth'] == '0' for r in rows),
        'prediction_coverage': len(valid) / len(rows),
        'TN': tn, 'FP': fp, 'FN': fn, 'TP': tp,
        'accuracy': accuracy, 'precision': precision, 'recall': recall, 'f1_score': f1,
        'note': 'Metrics use classified trials only. Report no-prediction counts and coverage alongside them. '
                'Positive means intentional prolonged closure, not medically confirmed microsleep.'}


def percent(value):
    return 'Undefined' if value is None else f'{value * 100:.2f}%'


def write_outputs(rows, source, output):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import sklearn
    summary = evaluate(rows)
    groups = {'All trials': summary}
    groups.update({f'Lighting: {light}': evaluate([r for r in rows if r['lighting'] == light])
        for light in sorted({r['lighting'] for r in rows})})
    output.mkdir(parents=True, exist_ok=False)
    report = {'generated_utc': datetime.now(timezone.utc).isoformat(),
        'input_file': str(source.resolve()), 'input_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'python_version': sys.version.split()[0], 'scikit_learn_version': sklearn.__version__,
        'matplotlib_version': matplotlib.__version__, 'results': groups}
    (output / 'results.json').write_text(json.dumps(report, indent=2, allow_nan=False), encoding='utf-8')
    with (output / 'classified_trials.csv').open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS + ['classification'])
        writer.writeheader()
        writer.writerows(rows)
    columns = ['group'] + list(summary.keys())[:-1]
    with (output / 'metrics.csv').open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, extrasaction='ignore')
        writer.writeheader()
        for group, result in groups.items():
            writer.writerow({'group': group, **result})
    fig, axes = plt.subplots(len(groups), 1, figsize=(7.4, 5.0 * len(groups)), squeeze=False)
    for ax, (group, result) in zip(axes[:, 0], groups.items()):
        matrix = [[result['TN'], result['FP']], [result['FN'], result['TP']]]
        ax.imshow(matrix, cmap='Blues', vmin=0, vmax=max(1, *(v for row in matrix for v in row)))
        for i in range(2):
            for j in range(2):
                ax.text(j, i, f"{[['TN', 'FP'], ['FN', 'TP']][i][j]}\n{matrix[i][j]}",
                    ha='center', va='center', fontsize=16,
                    color='white' if matrix[i][j] > max(1, *(v for row in matrix for v in row)) / 2 else 'black')
        ax.set_xticks([0, 1], ['Negative', 'Positive'])
        ax.set_yticks([0, 1], ['Negative', 'Positive'])
        ax.set_xlabel('DriveAlert prediction')
        ax.set_ylabel('Ground truth')
        ax.set_title(f"{group}: classified trials only\nN={result['total_trials']}, classified={result['classified_trials']}, "
                     f"no prediction={result['no_prediction_trials']}, coverage={percent(result['prediction_coverage'])}")
    fig.suptitle('DriveAlert - simulated prolonged-closure evaluation', fontsize=14)
    fig.tight_layout(rect=(0, 0, 1, 0.98))
    fig.savefig(output / 'confusion_matrix.png', dpi=180)
    plt.close(fig)
    labels = ['Accuracy', 'Precision', 'Recall', 'F1-score', 'Prediction coverage']
    keys = ['accuracy', 'precision', 'recall', 'f1_score', 'prediction_coverage']
    table_rows = [[group] + [percent(result[k]) for k in keys] +
                  [str(result['no_prediction_trials'])] for group, result in groups.items()]
    fig, ax = plt.subplots(figsize=(14, max(3.7, 2.5 + len(groups) * 0.55)))
    ax.axis('off')
    table = ax.table(cellText=table_rows, colLabels=['Trial group'] + labels + ['No prediction'],
                     cellLoc='center', loc='center')
    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 1.8)
    ax.set_title('DriveAlert evaluation results - classification metrics use classified trials only', pad=16)
    fig.text(0.5, 0.04, 'Undefined = zero denominator. Report coverage and no-prediction counts with all metrics.\n'
             'Positive = intentional prolonged closure; negative = eyes open / brief blink.', ha='center', fontsize=10)
    fig.tight_layout(rect=(0, 0.12, 1, 1))
    fig.savefig(output / 'metrics_summary.png', dpi=180)
    plt.close(fig)
    return groups


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv_file', nargs='?', type=Path, default=Path(__file__).with_name('trials.csv'))
    parser.add_argument('--output', type=Path, help='New output directory; existing directories are never overwritten.')
    args = parser.parse_args()
    try:
        rows = read_trials(args.csv_file)
        output = args.output or Path(__file__).parent / ('results_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
        results = write_outputs(rows, args.csv_file, output)
    except (OSError, ValueError, ImportError) as error:
        print(f'Cannot evaluate: {error}', file=sys.stderr)
        if isinstance(error, ImportError):
            print('Install dependencies: python -m pip install -r requirements.txt', file=sys.stderr)
        return 1
    for group, result in results.items():
        print(f"\n{group}: {result['total_trials']} trials; {result['classified_trials']} classified; "
              f"{result['no_prediction_trials']} without prediction")
        print('  ' + '  '.join(f'{key}={result[key]}' for key in ['TP', 'TN', 'FP', 'FN']))
        print('  ' + '  '.join(f'{key}={percent(result[key])}' for key in
                              ['accuracy', 'precision', 'recall', 'f1_score', 'prediction_coverage']))
    print(f'\nResults saved: {output.resolve()}')
    print('Classification metrics exclude no-prediction trials. Include coverage and failures in the report.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

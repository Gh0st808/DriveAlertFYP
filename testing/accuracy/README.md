# Detection accuracy evaluation

[← Testing guide](../../docs/testing/VALIDATION.md)

Evaluate recorded DriveAlert trial observations using scikit-learn and Matplotlib. The input template contains no trial data.

## Install

From the repository root on Windows:

```powershell
cd testing/accuracy
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Python and internet access are needed for dependency installation. Evaluation then runs locally.

## Record trials

Add one row per observed trial to trials.csv:

| Field | Values |
| --- | --- |
| trial_id | Unique trial identifier |
| ground_truth | 1 = intentional prolonged closure; 0 = eyes open or brief blink |
| prediction | 1 = microsleep indication; 0 = valid monitoring without a microsleep indication; no_prediction = no usable observation |
| lighting | Consistent condition label, such as normal or poor |
| evidence_file | Optional screenshot, video or log reference |
| notes | Optional duration, anonymous participant code and observations |

Define closure duration, observation window, sensitivity, camera position and calibration procedure before collecting data. Record ground truth independently of the app's output. Use stationary trials, reset between closures and count each trial once. Include unsuccessful and missing-prediction trials.

## Run

```powershell
.\.venv\Scripts\python.exe evaluate_accuracy.py trials.csv
```

A new timestamped results directory is created. Existing output folders are not overwritten. Empty inputs are rejected.

## Output

| File | Contents |
| --- | --- |
| confusion_matrix.png | Overall and per-lighting matrices |
| metrics_summary.png | Metric percentages, coverage and missing-prediction counts |
| metrics.csv | Counts and metric fractions |
| classified_trials.csv | Input records with TP, TN, FP, FN or NO_PREDICTION labels |
| results.json | Counts, metric fractions, input hash and tool versions |

Rows in each matrix are ground truth; columns are predictions. Label order is negative (0), positive (1), giving [[TN, FP], [FN, TP]].

## Interpretation

Classification metrics use trials with a valid binary prediction. Missing predictions are recorded separately by ground-truth class. Always report total trials, prediction coverage and missing-prediction counts alongside the metrics, including separate lighting results.

A missing observation is not a correct negative. Classified-trial accuracy alone does not represent full-system performance when some trials have no prediction. Metrics with a zero denominator are shown as Undefined (null in JSON). CSV metrics are fractions from 0 to 1; images display percentages.

Intentional prolonged closure is a simulated detection condition, not medical confirmation of microsleep. The generated figures support Chapter 5.4 but do not replace setup, calibration or trial evidence.

## References

- https://scikit-learn.org/stable/modules/generated/sklearn.metrics.confusion_matrix.html
- https://scikit-learn.org/stable/modules/generated/sklearn.metrics.precision_recall_fscore_support.html
- https://scikit-learn.org/stable/modules/generated/sklearn.metrics.accuracy_score.html

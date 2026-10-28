# DriveAlert: Chapter 5.4 evaluation

This evaluates recorded trial observations, not the camera itself. It does not connect to the Pi, detect eyes, download a dataset, create observations or edit DriveAlert. The trial template is intentionally empty. No real accuracy result exists until you enter collected observations.

## Install and run on your Windows laptop

Open PowerShell in the repository root, then run:

```powershell
cd testing/accuracy
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Open trials.csv in Excel or a text editor. Add one row per real trial, save as CSV, then run:

```powershell
.\.venv\Scripts\python.exe evaluate_accuracy.py trials.csv
```

The environment is isolated; no activation or PowerShell policy change is needed. Python must already be installed. Dependency installation needs internet access; evaluation then runs locally.

## Record the observations

- trial_id: unique identifier for each trial.
- ground_truth: 1 = intentional prolonged closure; 0 = eyes open or normal brief blink. Record independently of DriveAlert's indication.
- prediction: 1 = DriveAlert reports microsleep; 0 = valid monitoring continues without a microsleep prediction; no_prediction = no usable observation, such as failed face detection or unavailable camera. Do not call a missing observation a correct negative.
- lighting: a consistent description such as normal or poor. The script creates separate summaries for each distinct value.
- evidence_file: optional screenshot/video/log filename. This is a reference, not verification of the evidence.
- notes: duration, participant code, position, issues or other context; optional. Quote values containing commas.

Do stationary trials only. Before collection, choose and record the positive closure duration according to the deployed detection settings, the observation window, sensitivity, camera position and calibration procedure. Freeze those choices for the evaluation and retain all attempted trials. Do not derive ground truth from the app's own EAR or alert.

Reset to an open-eyed state between trials. Record one outcome per independent trial; multiple frames or screenshots of the same closure are not independent trials. Use anonymous participant codes, not names. Labelled intentional closure is a simulation, not physiological confirmation of microsleep. Include both positive and negative trials and identify lighting conditions. Do not invent counts or change unsuccessful observations to improve scores.

## No usable prediction

This evaluator treats no_prediction as an abstention and reports it separately for positive and negative ground truth. Confusion-matrix metrics apply ONLY to trials with a valid binary prediction. Total trials, classified trials, no-prediction counts and prediction coverage are always included, overall and per lighting condition. Do not present classified-trial accuracy as full-system accuracy, especially if poor-lighting trials have no predictions. If an assessment requires no-prediction trials to be treated as operational failures, define that analysis separately before collecting data. Never silently omit them.

## Files produced

- confusion_matrix.png: overall matrix and matrices for each lighting condition. Rows are ground truth; columns are predictions. Order is negative (0), positive (1): [[TN, FP], [FN, TP]].
- metrics_summary.png: screenshot-ready metric summary, coverage and no-prediction counts.
- metrics.csv: counts and metric fractions from 0 to 1. Blank metrics are undefined.
- classified_trials.csv: all input rows with TP/TN/FP/FN or NO_PREDICTION assigned.
- results.json: complete counts, metric fractions, input hash and tool versions.

Results go to a new timestamped folder. Existing output folders are never overwritten. Percentages on the images are rounded to two decimals; JSON retains precision. A zero denominator is reported as Undefined (null in JSON), not a misleading 0%.

For Section 5.4 capture the setup, completed calibration and relevant trial evidence, then use the generated PNGs for the confusion matrix and metrics figures. Keep the CSV and JSON as supporting records. These files do not replace UAT responses or functional-test evidence.

## Method references

- https://scikit-learn.org/stable/modules/generated/sklearn.metrics.confusion_matrix.html
- https://scikit-learn.org/stable/modules/generated/sklearn.metrics.precision_recall_fscore_support.html
- https://scikit-learn.org/stable/modules/generated/sklearn.metrics.accuracy_score.html

No sample observations or calculated results are included in this package.

import json
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, f1_score, precision_score, recall_score, roc_auc_score

def train_and_evaluate():
    df = pd.read_parquet('work/extracted_features.parquet')
    
    feature_cols = [
        'total_clicks_60d',
        'total_impressions_60d',
        'avg_position_60d',
        'avg_ctr_60d',
        'pos_volatility_60d',
        'click_velocity_pct',
        'impression_velocity_pct',
        'position_drift_delta'
    ]
    target_col = 'is_decaying_target'
    
    X = df[feature_cols]
    y = df[target_col]
    
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.25, random_state=42, stratify=y
    )
    
    baseline_preds = (X_val['click_velocity_pct'] <= -0.15).astype(int)
    
    baseline_metrics = {
        'precision': round(float(precision_score(y_val, baseline_preds)), 4),
        'recall': round(float(recall_score(y_val, baseline_preds)), 4),
        'f1_score': round(float(f1_score(y_val, baseline_preds)), 4),
        'roc_auc': round(float(roc_auc_score(y_val, baseline_preds)), 4)
    }
    
    model = RandomForestClassifier(n_estimators=200, max_depth=8, random_state=42)
    model.fit(X_train, y_train)
    
    rf_preds = model.predict(X_val)
    rf_probs = model.predict_proba(X_val)[:, 1]
    
    model_metrics = {
        'precision': round(float(precision_score(y_val, rf_preds)), 4),
        'recall': round(float(recall_score(y_val, rf_preds)), 4),
        'f1_score': round(float(f1_score(y_val, rf_preds)), 4),
        'roc_auc': round(float(roc_auc_score(y_val, rf_probs)), 4)
    }
    
    
    metrics_payload = {
        'base_rate': base_rate,
        'baseline_momentum_rule': baseline_metrics,
        'random_forest_model': model_metrics,
        'feature_importances': dict(zip(feature_cols, [round(float(x), 4) for x in model.feature_importances_]))
    }
    
    with open('work/evaluation_metrics.json', 'w') as f:
        json.dump(metrics_payload, f, indent=4)
        
    print("Model Training & Evaluation Complete.")
    print(json.dumps(metrics_payload, indent=2))

if __name__ == '__main__':
    train_and_evaluate()
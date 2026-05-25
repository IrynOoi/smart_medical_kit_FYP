# analytics.py
import json
import datetime
import numpy as np
from flask import Blueprint, request, jsonify
from services.ai_predictor import compute_prediction_for_patient, get_models
from models.analytics_model import get_all_active_patients_for_batch, batch_upsert_predictions

analytics_bp = Blueprint('analytics', __name__)


@analytics_bp.route('/predict_and_save', methods=['POST'])
def predict_and_save():
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        
        # 调用逻辑
        new_pred = compute_prediction_for_patient(patient_id)
        
        # 关键修改：处理 compute_prediction_for_patient 返回 None 的情况
        if new_pred is None:
            return jsonify({
                "success": False, 
                "message": "No adherence data found. Please take medication to generate insights."
            }), 200 # 返回 200 OK，但 success 为 False
            
        return jsonify({
            "success": True,
            "message": "Prediction generated and saved",
            "data": new_pred
        })
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@analytics_bp.route('/run_ai_analytics_job', methods=['POST'])
def run_ai_analytics_job():
    try:
        patients = get_all_active_patients_for_batch()
        inserted_count = 0
        for pat in patients:
            if pat and isinstance(pat, dict) and 'patient_id' in pat:
                # 获取预测结果
                result = compute_prediction_for_patient(pat['patient_id'])
                
                # 关键修复：检查 result 是否为 None
                if result is not None:
                    inserted_count += 1
                else:
                    print(f"Skipping prediction for patient {pat['patient_id']}: No history data.")
            else:
                print(f"Skipping invalid patient data: {pat}")
                
        return jsonify({"success": True, "message": f"Successfully updated AI predictions for {inserted_count} patients."})
    except Exception as e:
        print(f"Batch AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

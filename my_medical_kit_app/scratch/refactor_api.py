import os
import re

lib_dir = r"c:\Users\xienx\Desktop\UTEM\SEM 6\FYP\FYP_CODES\my_medical_kit_app\lib"

# Define replacement mappings for the UI files
method_mappings = {
    r'ApiService\(\)\.login\(': 'AuthService().login(',
    r'ApiService\(\)\.register\(': 'AuthService().register(',
    r'ApiService\(\)\.resetPassword\(': 'AuthService().resetPassword(',

    r'ApiService\(\)\.getPatient\(': 'PatientService().getPatient(',
    r'ApiService\(\)\.getAdherenceLogs\(': 'PatientService().getAdherenceLogs(',
    r'ApiService\(\)\.getAdherenceStats\(': 'PatientService().getAdherenceStats(',
    r'ApiService\(\)\.getNotifications\(': 'PatientService().getNotifications(',
    r'ApiService\(\)\.createNotification\(': 'PatientService().createNotification(',
    r'ApiService\(\)\.markNotificationRead\(': 'PatientService().markNotificationRead(',
    r'ApiService\(\)\.updatePatient\(': 'PatientService().updatePatient(',
    r'ApiService\(\)\.addPatient\(': 'PatientService().addPatient(',
    r'ApiService\(\)\.deletePatient\(': 'PatientService().deletePatient(',

    r'ApiService\(\)\.getCaregiverProfile\(': 'CaregiverService().getCaregiverProfile(',
    r'ApiService\(\)\.getCaregiverOverview\(': 'CaregiverService().getCaregiverOverview(',
    r'ApiService\(\)\.getAllRecentLogs\(': 'CaregiverService().getAllRecentLogs(',
    r'ApiService\(\)\.getCaregiverPatients\(': 'CaregiverService().getCaregiverPatients(',
    r'ApiService\(\)\.getCaregiverAlerts\(': 'CaregiverService().getCaregiverAlerts(',
    r'ApiService\(\)\.getChartData\(': 'CaregiverService().getChartData(',
    r'ApiService\(\)\.getAnalyticsOverview\(': 'CaregiverService().getAnalyticsOverview(',

    r'ApiService\(\)\.getPatientMedications\(': 'MedicationService().getPatientMedications(',
    r'ApiService\(\)\.getPatientPrescriptions\(': 'MedicationService().getPatientPrescriptions(',
    r'ApiService\(\)\.recordMedicationTaken\(': 'MedicationService().recordMedicationTaken(',
    r'ApiService\(\)\.restockMedication\(': 'MedicationService().restockMedication(',

    r'ApiService\(\)\.getPatientDevice\(': 'DeviceService().getPatientDevice(',
    r'ApiService\(\)\.controlLed\(': 'DeviceService().controlLed(',
    r'ApiService\(\)\.controlBuzzer\(': 'DeviceService().controlBuzzer(',
    r'ApiService\(\)\.controlDisplay\(': 'DeviceService().controlDisplay(',
    r'ApiService\(\)\.controlStepper\(': 'DeviceService().controlStepper(',

    r'ApiService\(\)\.getAIPrediction\(': 'PredictionService().getAIPrediction(',
    r'ApiService\(\)\.recalculatePrediction\(': 'PredictionService().recalculatePrediction(',
    r'ApiService\(\)\.predictAndSaveForPatient\(': 'PredictionService().predictAndSaveForPatient(',
    r'ApiService\(\)\.predictAndSave\(': 'PredictionService().predictAndSave(',
    r'ApiService\(\)\.runBatchPrediction\(': 'PredictionService().runBatchPrediction(',
}

new_imports = """import 'package:my_medical_kit_app/services/api/auth_service.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/services/api/device_service.dart';
import 'package:my_medical_kit_app/services/api/prediction_service.dart';"""

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            file_path = os.path.join(root, file)
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            new_content = content
            
            # Replace absolute imports
            new_content = re.sub(r"import\s+['\"]package:my_medical_kit_app/services/api_service\.dart['\"];", new_imports, new_content)
            
            # Replace relative imports
            new_content = re.sub(r"import\s+['\"](?:\.\./)*services/api_service\.dart['\"];", new_imports, new_content)

            # Apply method replacements
            for pattern, repl in method_mappings.items():
                new_content = re.sub(pattern, repl, new_content)
                
            # Replace _apiService variable calls
            new_content = new_content.replace('_apiService.login(', 'AuthService().login(')
            new_content = new_content.replace('_apiService.register(', 'AuthService().register(')
            new_content = new_content.replace('_apiService.resetPassword(', 'AuthService().resetPassword(')
            new_content = new_content.replace('_apiService.getPatient(', 'PatientService().getPatient(')
            new_content = new_content.replace('_apiService.getAdherenceLogs(', 'PatientService().getAdherenceLogs(')
            new_content = new_content.replace('_apiService.getAdherenceStats(', 'PatientService().getAdherenceStats(')
            new_content = new_content.replace('_apiService.getNotifications(', 'PatientService().getNotifications(')
            new_content = new_content.replace('_apiService.createNotification(', 'PatientService().createNotification(')
            new_content = new_content.replace('_apiService.markNotificationRead(', 'PatientService().markNotificationRead(')
            new_content = new_content.replace('_apiService.updatePatient(', 'PatientService().updatePatient(')
            new_content = new_content.replace('_apiService.addPatient(', 'PatientService().addPatient(')
            new_content = new_content.replace('_apiService.deletePatient(', 'PatientService().deletePatient(')
            new_content = new_content.replace('_apiService.getCaregiverProfile(', 'CaregiverService().getCaregiverProfile(')
            new_content = new_content.replace('_apiService.getCaregiverOverview(', 'CaregiverService().getCaregiverOverview(')
            new_content = new_content.replace('_apiService.getAllRecentLogs(', 'CaregiverService().getAllRecentLogs(')
            new_content = new_content.replace('_apiService.getCaregiverPatients(', 'CaregiverService().getCaregiverPatients(')
            new_content = new_content.replace('_apiService.getCaregiverAlerts(', 'CaregiverService().getCaregiverAlerts(')
            new_content = new_content.replace('_apiService.getChartData(', 'CaregiverService().getChartData(')
            new_content = new_content.replace('_apiService.getAnalyticsOverview(', 'CaregiverService().getAnalyticsOverview(')
            new_content = new_content.replace('_apiService.getPatientMedications(', 'MedicationService().getPatientMedications(')
            new_content = new_content.replace('_apiService.getPatientPrescriptions(', 'MedicationService().getPatientPrescriptions(')
            new_content = new_content.replace('_apiService.recordMedicationTaken(', 'MedicationService().recordMedicationTaken(')
            new_content = new_content.replace('_apiService.restockMedication(', 'MedicationService().restockMedication(')
            new_content = new_content.replace('_apiService.getPatientDevice(', 'DeviceService().getPatientDevice(')
            new_content = new_content.replace('_apiService.controlLed(', 'DeviceService().controlLed(')
            new_content = new_content.replace('_apiService.controlBuzzer(', 'DeviceService().controlBuzzer(')
            new_content = new_content.replace('_apiService.controlDisplay(', 'DeviceService().controlDisplay(')
            new_content = new_content.replace('_apiService.controlStepper(', 'DeviceService().controlStepper(')
            new_content = new_content.replace('_apiService.getAIPrediction(', 'PredictionService().getAIPrediction(')
            new_content = new_content.replace('_apiService.recalculatePrediction(', 'PredictionService().recalculatePrediction(')
            new_content = new_content.replace('_apiService.predictAndSaveForPatient(', 'PredictionService().predictAndSaveForPatient(')
            new_content = new_content.replace('_apiService.predictAndSave(', 'PredictionService().predictAndSave(')
            new_content = new_content.replace('_apiService.runBatchPrediction(', 'PredictionService().runBatchPrediction(')
            
            # Remove the old variable declaration
            new_content = re.sub(r'final\s+ApiService\s+_apiService\s*=\s*ApiService\(\);', '', new_content)
            new_content = re.sub(r'ApiService\s+_apiService\s*=\s*ApiService\(\);', '', new_content)

            if new_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Refactored: {file_path}")

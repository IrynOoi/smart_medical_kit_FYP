import os
import re

lib_dir = r"c:\Users\xienx\Desktop\UTEM\SEM 6\FYP\FYP_CODES\my_medical_kit_app\lib"

# 1. Update ApiService.baseUrl to ApiClient.baseUrl
for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            file_path = os.path.join(root, file)
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            new_content = content.replace('ApiService.baseUrl', 'ApiClient.baseUrl')
            
            # If ApiClient.baseUrl is used, we need to import api_client.dart
            if 'ApiClient.baseUrl' in new_content and 'package:my_medical_kit_app/services/api/api_client.dart' not in new_content:
                new_content = "import 'package:my_medical_kit_app/services/api/api_client.dart';\n" + new_content

            if new_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Updated ApiService.baseUrl in: {file_path}")

# 2. Fix reminder_service.dart manually
reminder_path = os.path.join(lib_dir, 'services', 'reminder_service.dart')
with open(reminder_path, 'r', encoding='utf-8') as f:
    reminder_content = f.read()

reminder_content = reminder_content.replace('final api = ApiService();', '')
reminder_content = reminder_content.replace('api.getPatientMedications(', 'MedicationService().getPatientMedications(')
reminder_content = reminder_content.replace('api.createNotification(', 'PatientService().createNotification(')
reminder_content = reminder_content.replace("import 'api_service.dart';", "import 'package:my_medical_kit_app/services/api/medication_service.dart';\nimport 'package:my_medical_kit_app/services/api/patient_service.dart';")

with open(reminder_path, 'w', encoding='utf-8') as f:
    f.write(reminder_content)
print("Fixed reminder_service.dart")

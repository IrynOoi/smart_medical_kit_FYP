"""
cleanup_imports.py – Strip unused service imports & fix duplicate imports in service files.
"""
import os, re

lib_dir = r"c:\Users\xienx\Desktop\UTEM\SEM 6\FYP\FYP_CODES\my_medical_kit_app\lib"

# ── service import lines we may have added in bulk ──────────────────────────
SERVICE_IMPORTS = {
    'auth':       "import 'package:my_medical_kit_app/services/api/auth_service.dart';",
    'patient':    "import 'package:my_medical_kit_app/services/api/patient_service.dart';",
    'caregiver':  "import 'package:my_medical_kit_app/services/api/caregiver_service.dart';",
    'medication': "import 'package:my_medical_kit_app/services/api/medication_service.dart';",
    'device':     "import 'package:my_medical_kit_app/services/api/device_service.dart';",
    'prediction': "import 'package:my_medical_kit_app/services/api/prediction_service.dart';",
    'api_client': "import 'package:my_medical_kit_app/services/api/api_client.dart';",
}

# tokens that indicate a service is actually used in the file
USAGE_TOKENS = {
    'auth':       ['AuthService()'],
    'patient':    ['PatientService()'],
    'caregiver':  ['CaregiverService()'],
    'medication': ['MedicationService()'],
    'device':     ['DeviceService()'],
    'prediction': ['PredictionService()'],
    'api_client': ['ApiClient.'],
}

def strip_unused_imports(content: str, filepath: str) -> str:
    for key, import_line in SERVICE_IMPORTS.items():
        if import_line not in content:
            continue  # not present, skip
        tokens = USAGE_TOKENS[key]
        used = any(t in content for t in tokens)
        if not used:
            # Remove the import line (and trailing newline)
            content = content.replace(import_line + '\n', '')
            content = content.replace(import_line, '')
    return content


def fix_duplicate_imports(content: str) -> str:
    """Remove truly duplicate import lines."""
    seen = set()
    lines = content.split('\n')
    out = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("import '") and stripped in seen:
            continue  # skip duplicate
        if stripped.startswith("import '"):
            seen.add(stripped)
        out.append(line)
    return '\n'.join(out)


def fix_service_file_imports(content: str, filepath: str) -> str:
    """Fix issues inside the new service files themselves."""
    filename = os.path.basename(filepath)

    # Remove duplicate api_client.dart import added by fix_remaining_api.py
    if 'api_client.dart' in filepath or 'auth_service.dart' in filepath or 'patient_service.dart' in filepath:
        content = fix_duplicate_imports(content)

    # Remove unused foundation.dart from service files
    if filepath.startswith(os.path.join(lib_dir, 'services', 'api')):
        content = content.replace("import 'package:flutter/foundation.dart';\n", '')

    return content


changed = 0
for root, _, files in os.walk(lib_dir):
    for fname in files:
        if not fname.endswith('.dart'):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, 'r', encoding='utf-8') as f:
            original = f.read()

        updated = strip_unused_imports(original, fpath)
        updated = fix_service_file_imports(updated, fpath)

        if updated != original:
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(updated)
            changed += 1
            print(f'  cleaned: {os.path.relpath(fpath, lib_dir)}')

print(f'\nDone – {changed} files updated.')

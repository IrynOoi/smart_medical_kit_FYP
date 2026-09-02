# MedSmart (Smart Medical Kit System)

MedSmart is an IoT-based medication adherence platform that combines:
- a **Flutter mobile application** (patient + caregiver),
- an updated **React caregiver/admin web portal**,
- a **Python Flask backend API with scheduler and AI services**,
- and an **ESP32 smart dispenser**.

The system is designed to reduce missed doses, improve remote monitoring, and provide early risk insight for non-adherence.

---

## 1) Core Problem Addressed

Medication non-adherence is common in elderly and chronic-care patients due to forgetfulness, complex schedules, and weak monitoring.  
MedSmart addresses this by linking reminders, physical dispensing, adherence logging, stock tracking, and caregiver alerts in one integrated flow.

---

## 2) What Is Included in This Repository

```text
smart_medical_kit_FYP/
├── caregiver_admin_web/     # React + Vite caregiver/admin website
├── my_medical_kit_app/      # Flutter mobile app (patient + caregiver)
├── python_backend/          # Flask API, scheduler, AI prediction services
├── iot_codes/               # ESP32 firmware for smart dispenser device
├── db/                      # SQL dumps and schema snapshots
└── testing_app/             # Flutter-based device testing app
```

---

## 3) MedSmart Architecture

### A. Flutter Mobile App (`my_medical_kit_app`)
- Role-based experience for **patient** and **caregiver**
- Authentication + profile management
- Smart reminders and medication history
- Inventory views and restock interactions
- AI prediction and adherence insight pages
- Background reminder initialization via `ReminderService`

### B. React Caregiver Website (`caregiver_admin_web`) — Updated
Built with React 19 + Vite and connected to the same Flask backend API.

Main web modules:
- **Login & caregiver registration** (with forgot-password OTP flow)
- **Dashboard**: adherence metrics, chart, at-risk patients, recent logs
- **Patient Directory**: enroll, edit, activate/deactivate, unlink, delete
- **Prescriptions**: create/update schedules, dosage and timing management
- **Medications Catalog**: centralized medicine records and edits
- **AI Analytics**: patient risk overview + per-patient prediction + batch run
- **Smart Kit Devices**: register devices, monitor status, control power/LED/buzzer/display/stepper, refill stock, technician ticket submission
- **Profile**: caregiver account update and account actions

### C. Backend API (`python_backend`)
- Flask app with modular blueprints:
  - `auth.py`
  - `patient.py`
  - `caregiver.py`
  - `medication.py`
  - `device.py`
  - `analytics.py`
  - `notification.py`
- MySQL connection pooling
- File upload support for profile photos (`static/profiles`)
- Malaysia timezone handling (`UTC+8`) for medication schedule consistency

### D. Scheduler Service
`scheduler_service.py` runs every minute and:
1. Creates reminder notifications **2–10 minutes before** scheduled time.
2. Creates adherence logs in `PENDING` state at dose time (±1 minute tolerance) for ESP32 polling.
3. Synchronizes stock notifications.

### E. AI Prediction Layer
- Uses `smart_pill_lstm_model.h5` and `smart_pill_rf_model.pkl`
- Supports:
  - single patient prediction (`/predict_and_save`)
  - batch prediction job (`/run_ai_analytics_job`)
- Enforces minimum adherence history before reliable prediction.

### F. ESP32 Smart Dispenser (`iot_codes/testing_iot/SmartMedicalKit`)
- WiFi setup with captive portal
- Polls backend for pending doses (`/device/<serial>/pending_dose`)
- Controls motor slots for dispensing
- Buzzer + display alerts
- Posts dispense outcomes:
  - success (`/device/dispense_success`)
  - missed (`/device/dispense_missed`)
- Sends periodic heartbeat (`/device/heartbeat`) with power/network/battery metadata

---

## 4) End-to-End System Flow (Detailed)

1. **Caregiver configures patient, medication, and prescription schedule** through mobile/web.
2. **Backend scheduler** checks active prescriptions every minute.
3. Upcoming doses generate **in-app reminders**.
4. Due doses generate **`PENDING` adherence logs**.
5. **ESP32 polls pending endpoint**, receives due dose data, alerts patient, rotates motor slot.
6. ESP32 sends **taken/missed result** back to backend.
7. Backend updates adherence records + inventory quantities.
8. Low stock/out-of-stock triggers caregiver-side alerts.
9. AI endpoints read adherence history and persist prediction results.
10. Mobile app + React portal display updated insights, trends, alerts, and patient/device status.

---

## 5) Key Data States and Logic

- **Adherence status lifecycle**: `PENDING` → `TAKEN` or `MISSED`
- **Reminder timing window**: 2–10 minutes before scheduled dose time
- **Schedule tolerance**: ±1 minute at dose trigger time
- **Stock awareness**: inventory changes can trigger low-stock/out-of-stock alerts
- **Role guard on web portal**: patient role is blocked from caregiver/admin web login

---

## 6) Backend API Domain Overview

### Auth
- `/login`, `/register`
- `/forgot_password`, `/verify_otp`, `/verify_otp_and_reset`, `/reset_password`

### Caregiver
- overview stats, chart data, recent logs, at-risk list
- patient linking/unlinking, available patient listing
- profile read/update, deactivate/delete account

### Patient
- profile, prescriptions, adherence stats/logs, AI prediction
- update/reactivate/delete operations

### Medication & Prescription
- medication catalog CRUD
- prescription CRUD
- manual restock/log operations
- retake support for missed doses

### Device
- IoT device CRUD and assignment data
- pending dose polling, dispense success/missed callbacks
- heartbeat, power status/control
- remote LED/buzzer/display/stepper controls
- technician ticket submission

### Notifications
- patient reminders
- caregiver stock and general notifications
- mark single/all read APIs

---

## 7) Setup and Run Guide

### Prerequisites
- Python 3.10+
- Node.js 18+
- Flutter SDK 3.x
- MySQL server
- Arduino IDE / PlatformIO for ESP32 firmware upload

### 7.1 Backend (Flask)
Path: `/home/runner/work/smart_medical_kit_FYP/smart_medical_kit_FYP/python_backend`

1. Create environment variables:
   - copy `.env.example` to `.env`
   - configure MySQL and Mailtrap values
2. Install dependencies (example):
   ```bash
   pip install flask flask-cors python-dotenv mysql-connector-python apscheduler numpy tensorflow scikit-learn joblib requests werkzeug psycopg2-binary
   ```
3. Run server:
   ```bash
   python server.py
   ```
4. Verify health:
   - `GET /health`

### 7.2 Caregiver React Website
Path: `/home/runner/work/smart_medical_kit_FYP/smart_medical_kit_FYP/caregiver_admin_web`

1. Copy `.env.example` to `.env`
2. Set `VITE_API_BASE_URL` to your backend/ngrok URL
3. Install and start:
   ```bash
   npm install
   npm run dev
   ```
4. Other scripts:
   ```bash
   npm run build
   npm run lint
   npm run preview
   ```

### 7.3 Flutter Mobile App
Path: `/home/runner/work/smart_medical_kit_FYP/smart_medical_kit_FYP/my_medical_kit_app`

1. Copy `.env.example` to `.env`
2. Set `API_BASE_URL`
3. Run:
   ```bash
   flutter pub get
   flutter run
   ```

### 7.4 ESP32 Firmware
Path: `/home/runner/work/smart_medical_kit_FYP/smart_medical_kit_FYP/iot_codes/testing_iot/SmartMedicalKit`

1. Rename `secrets.h.example` → `secrets.h`
2. Fill WiFi SSID/password
3. Set backend tunnel URL in firmware config (`serverBase`)
4. Flash to ESP32 and monitor serial output

---

## 8) Notes for Development and Integration

- React and Flutter clients both use the same Flask API.
- Many API calls include `ngrok-skip-browser-warning` header for tunnel compatibility.
- Keep backend timezone behavior in mind when validating reminder schedule timing.
- AI model files are expected to exist in `python_backend/` root.

---

## 9) Project Objectives

1. Improve medication adherence with real-time reminders and smart dispensing.
2. Give caregivers full remote visibility into patient medication activity.
3. Automate inventory tracking and low-stock alerting.
4. Use AI to flag high-risk adherence behavior early for intervention.

---

## 10) Hardware and UI Photos

### Smart Medical Kit Hardware
<img width="960" height="1280" alt="Smart Medical Kit hardware 1" src="https://github.com/user-attachments/assets/36cacc00-a2f3-4351-abad-ccc257eb5f57" />

<br><br>
<img width="1280" height="960" alt="Smart Medical Kit hardware 2" src="https://github.com/user-attachments/assets/c8c3b15d-bb33-4be2-9bc7-b4943e81ef9e" />

### Website UI (Caregiver Portal)
<img width="1873" height="890" alt="MedSmart caregiver portal UI" src="https://github.com/user-attachments/assets/535e3e21-2291-45b8-8828-140417c24477" />

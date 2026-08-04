# Smart Medical Kit System

## Introduction
The **Smart Medical Kit** is an IoT-based medication management system designed to help elderly patients and people with chronic conditions follow their medication schedule more consistently.  
It combines a **Flutter mobile app**, a **Python Flask backend**, and an **ESP32 smart dispenser** to automate reminders, dispensing, adherence tracking, and caregiver monitoring.

This system reduces common medication-management problems such as:
- missed doses due to forgetfulness,
- delayed caregiver awareness,
- and poor visibility of medicine stock levels.

By linking software + hardware + AI prediction, the platform supports safer and more proactive daily medication care.

## Key Features
- **Real-time adherence tracking**: logs each scheduled dose as taken or missed.
- **Automated smart dispensing**: hardware dispenser triggers when a scheduled dose is due.
- **Predictive analytics**: AI models estimate missed-dose/forget risk from adherence history.
- **Caregiver monitoring dashboard**: view patient status, alerts, and recent medication events.
- **Low-stock notifications**: automatically warns caregivers when medicine quantity is low.
- **Reminder automation**: in-app reminders are generated before scheduled dose time.

## System Architecture (High Level)
1. **Mobile App (Flutter)**  
   Patient and caregiver interfaces for authentication, reminders, dashboards, medication history, inventory, and profile management.

2. **Backend API (Flask + MySQL)**  
   Central logic for users, medications, prescriptions, adherence logs, notifications, devices, and analytics endpoints.

3. **Background Scheduler (APScheduler)**  
   Runs every minute to:
   - create upcoming reminder notifications (2–10 minutes before dose time),
   - insert `PENDING` adherence logs when dose time arrives (used by IoT device polling),
   - sync stock-related notifications.

4. **IoT Device (ESP32 Firmware)**  
   Polls backend for pending doses, controls motors/buzzer/display, dispenses medication, and posts dispense success/missed status back to the server.

5. **AI Prediction Layer (LSTM + Random Forest)**  
   Uses historical adherence data to generate risk insights and support proactive intervention.

## Detailed Summary: How the System Works

### 1) User and profile setup
- Patient/caregiver accounts are created and authenticated via backend auth APIs.
- Caregivers can link patients, register/manage devices, and configure prescriptions.

### 2) Prescription and schedule configuration
- Caregiver defines medication details (name, dosage, stock, linked device slot).
- Caregiver sets dose schedules (time and optional day-of-week rules).
- Backend stores this in prescription + schedule tables.

### 3) Continuous scheduler processing
- A background scheduler in the backend checks active prescriptions every minute.
- If a dose is approaching (2–10 minutes), a reminder notification is inserted for the patient.
- If a dose is due (with ±1 minute tolerance), backend inserts a `PENDING` adherence log entry.

### 4) IoT polling and physical dispensing
- ESP32 device periodically calls the backend pending-dose endpoint.
- When pending dose exists:
  - device alerts user (OLED + buzzer),
  - motor rotates correct slot to dispense medicine,
  - stock and adherence state are updated through backend APIs.
- Device sends:
  - **dispense success** → mark dose as taken,
  - **timeout/no confirmation** → mark dose as missed.

### 5) Adherence logging and history
- Every scheduled medication event is captured as adherence logs (`PENDING`, `TAKEN`, `MISSED` flow).
- Patient and caregiver dashboards fetch these logs for daily status, trend charts, and detailed history views.

### 6) AI analytics and risk prediction
- Backend AI services use historical adherence patterns to estimate future forget/miss probability.
- Prediction output is shown in analytics views to support early intervention for at-risk patients.

### 7) Inventory and caregiver alerts
- Medication quantities are updated after dose events/restock operations.
- When stock drops below threshold, caregiver notifications are generated automatically.
- Caregivers can monitor multiple patients and prioritize follow-up using alerts and overview stats.

## Problem Statement
1. High rates of medication non-adherence and forgetfulness.
2. Lack of predictive monitoring and proactive decision-making.
3. Inefficient inventory monitoring and limited remote caregiver access.

## Objectives
1. Analyze existing medication non-adherence issues and IoT pill dispenser limitations.
2. Develop an automated IoT pill dispenser with multi-channel reminder support.
3. Implement real-time medication monitoring and inventory tracking.
4. Integrate machine learning for missed-dose probability prediction using adherence time-series data.



## PHOTO OF MY SMART MEDICAL KIT 

<img width="960" height="1280" alt="image" src="https://github.com/user-attachments/assets/36cacc00-a2f3-4351-abad-ccc257eb5f57" />


<br><br>
<img width="1280" height="960" alt="image" src="https://github.com/user-attachments/assets/c8c3b15d-bb33-4be2-9bc7-b4943e81ef9e" />

# Website ui view
1)
<img width="1873" height="890" alt="image" src="https://github.com/user-attachments/assets/535e3e21-2291-45b8-8828-140417c24477" />

2)






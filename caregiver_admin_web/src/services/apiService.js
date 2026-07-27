// Central API Service for Caregiver & Admin Portal
// Communicates with the Flask backend API shared with the Flutter Mobile App

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://reluctant-scrambled-badge.ngrok-free.dev';

const getHeaders = (hasBody = true) => {
  const headers = {
    'ngrok-skip-browser-warning': 'true',
  };
  if (hasBody) {
    headers['Content-Type'] = 'application/json';
  }
  return headers;
};

export const apiService = {
  // ==========================================
  // 🔐 AUTHENTICATION
  // ==========================================
  async login(email, password) {
    try {
      const response = await fetch(`${BASE_URL}/login`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ email, password }),
      });
      const data = await response.json();
      return data;
    } catch (err) {
      console.error('Login request failed:', err);
      return { success: false, error: 'Network error or server unreachable. Please check backend connection.' };
    }
  },

  async register(userData) {
    try {
      const response = await fetch(`${BASE_URL}/register`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify(userData),
      });
      return await response.json();
    } catch (err) {
      console.error('Register request failed:', err);
      return { success: false, error: err.message };
    }
  },

  async resetPassword(email, newPassword) {
    try {
      const response = await fetch(`${BASE_URL}/reset_password`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ email, new_password: newPassword }),
      });
      return await response.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  // ==========================================
  // 📊 CAREGIVER DASHBOARD & STATS
  // ==========================================
  async getCaregiverProfile(caregiverId) {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}`, {
        headers: getHeaders(false),
      });
      return await response.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  async getCaregiverOverview(caregiverId) {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}/overview_stats`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return {
        taken_count: 0,
        missed_count: 0,
        pending_count: 0,
        total_patients: 0,
        low_stock_count: 0,
      };
    } catch (err) {
      console.error('Error fetching caregiver overview:', err);
      return {
        taken_count: 0,
        missed_count: 0,
        pending_count: 0,
        total_patients: 0,
        low_stock_count: 0,
      };
    }
  },

  async getChartData(caregiverId, period = 'Week') {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}/chart_data?period=${period}`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) {
        return json.data;
      }
      return { taken: [0, 0, 0, 0, 0, 0, 0], missed: [0, 0, 0, 0, 0, 0, 0] };
    } catch (err) {
      console.error('Error fetching chart data:', err);
      return { taken: [0, 0, 0, 0, 0, 0, 0], missed: [0, 0, 0, 0, 0, 0, 0] };
    }
  },

  async getAllRecentLogs(caregiverId, limit = 20) {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}/all_recent_logs?limit=${limit}`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return [];
    } catch (err) {
      console.error('Error fetching recent logs:', err);
      return [];
    }
  },

  async getCaregiverAlerts(caregiverId) {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}/recent_alerts`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return [];
    } catch (err) {
      console.error('Error fetching caregiver alerts:', err);
      return [];
    }
  },

  // ==========================================
  // 👥 PATIENT MANAGEMENT
  // ==========================================
  async getCaregiverPatients(caregiverId) {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}/patients`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return [];
    } catch (err) {
      console.error('Error fetching caregiver patients:', err);
      return [];
    }
  },

  async getPatient(patientId) {
    try {
      const response = await fetch(`${BASE_URL}/patient/${patientId}`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return null;
    } catch (err) {
      console.error('Error fetching patient:', err);
      return null;
    }
  },

  async addPatient(patientData) {
    try {
      const response = await fetch(`${BASE_URL}/register`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ ...patientData, role: 'patient' }),
      });
      return await response.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  async updatePatient(patientId, formData) {
    try {
      const response = await fetch(`${BASE_URL}/update_patient/${patientId}`, {
        method: 'PUT',
        headers: getHeaders(true),
        body: JSON.stringify(formData),
      });
      return await response.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  async deletePatient(patientId) {
    try {
      const response = await fetch(`${BASE_URL}/patient/${patientId}`, {
        method: 'DELETE',
        headers: getHeaders(false),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      console.error('Error deleting patient:', err);
      return false;
    }
  },

  // ==========================================
  // 💊 PRESCRIPTIONS & INVENTORY
  // ==========================================
  async getPatientMedications(patientId) {
    try {
      const response = await fetch(`${BASE_URL}/patient/${patientId}/prescriptions`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return [];
    } catch (err) {
      console.error('Error fetching patient medications:', err);
      return [];
    }
  },

  async getMedicationsCatalog() {
    try {
      const response = await fetch(`${BASE_URL}/medications`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return [];
    } catch (err) {
      console.error('Error fetching master medications catalog:', err);
      return [];
    }
  },

  async addPrescription(prescriptionData) {
    try {
      const response = await fetch(`${BASE_URL}/add_prescription`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify(prescriptionData),
      });
      return await response.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  async updatePrescription(prescriptionId, data) {
    try {
      const response = await fetch(`${BASE_URL}/prescription/${prescriptionId}`, {
        method: 'PUT',
        headers: getHeaders(true),
        body: JSON.stringify(data),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async deletePrescription(prescriptionId) {
    try {
      const response = await fetch(`${BASE_URL}/prescription/${prescriptionId}`, {
        method: 'DELETE',
        headers: getHeaders(false),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async restockMedication(prescriptionId, quantity) {
    try {
      const response = await fetch(`${BASE_URL}/restock_medication`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ prescription_id: prescriptionId, quantity }),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      console.error('Error restocking medication:', err);
      return false;
    }
  },

  // ==========================================
  // 🤖 AI ANALYTICS & PREDICTIONS
  // ==========================================
  async getAnalyticsOverview(caregiverId) {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}/analytics_overview`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return {
        overall_adherence_prediction: 0.0,
        high_risk_patients: 0,
        medium_risk_patients: 0,
        total_analyzed: 0,
      };
    } catch (err) {
      return {
        overall_adherence_prediction: 0.0,
        high_risk_patients: 0,
        medium_risk_patients: 0,
        total_analyzed: 0,
      };
    }
  },

  async getAtRiskPatients(caregiverId) {
    try {
      const response = await fetch(`${BASE_URL}/caregiver/${caregiverId}/at_risk_patients`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return [];
    } catch (err) {
      return [];
    }
  },

  async getAIPrediction(patientId) {
    try {
      const response = await fetch(`${BASE_URL}/patient/${patientId}/ai_prediction`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return null;
    } catch (err) {
      return null;
    }
  },

  async recalculatePrediction(patientId) {
    try {
      const response = await fetch(`${BASE_URL}/predict_and_save`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ patient_id: patientId }),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return null;
    } catch (err) {
      return null;
    }
  },

  async runBatchPrediction() {
    try {
      const response = await fetch(`${BASE_URL}/run_ai_analytics_job`, {
        method: 'POST',
        headers: getHeaders(true),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  // ==========================================
  // 📟 HARDWARE / IOT DEVICES & CONTROLS
  // ==========================================
  async getDevices() {
    try {
      const response = await fetch(`${BASE_URL}/devices`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return [];
    } catch (err) {
      return [];
    }
  },

  async getDevice(deviceId) {
    try {
      const response = await fetch(`${BASE_URL}/device/${deviceId}`, {
        headers: getHeaders(false),
      });
      const json = await response.json();
      if (json.success) return json.data;
      return null;
    } catch (err) {
      return null;
    }
  },

  async controlLed(patientId, turnOn) {
    try {
      const response = await fetch(`${BASE_URL}/device/control/led`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ patient_id: patientId, action: turnOn ? 'on' : 'off' }),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async controlBuzzer(patientId, turnOn) {
    try {
      const response = await fetch(`${BASE_URL}/device/control/buzzer`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ patient_id: patientId, action: turnOn ? 'on' : 'off' }),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async controlDisplay(patientId, command) {
    try {
      const response = await fetch(`${BASE_URL}/device/control/display`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ patient_id: patientId, command }),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async controlStepper(patientId, motor, action) {
    try {
      const response = await fetch(`${BASE_URL}/device/control/stepper`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ patient_id: patientId, motor, action }),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async addDevice(serial, ip = '', battery = 100) {
    try {
      const response = await fetch(`${BASE_URL}/iot_device`, {
        method: 'POST',
        headers: getHeaders(true),
        body: JSON.stringify({ device_serial: serial, last_known_ip: ip, battery }),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async updateDevice(deviceId, serial) {
    try {
      const response = await fetch(`${BASE_URL}/iot_device/${deviceId}`, {
        method: 'PUT',
        headers: getHeaders(true),
        body: JSON.stringify({ device_serial: serial }),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },

  async deleteDevice(deviceId) {
    try {
      const response = await fetch(`${BASE_URL}/iot_device/${deviceId}`, {
        method: 'DELETE',
        headers: getHeaders(false),
      });
      const json = await response.json();
      return json.success === true;
    } catch (err) {
      return false;
    }
  },
};

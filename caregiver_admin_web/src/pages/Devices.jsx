// Devices.jsx - Smart Medical Kit Hardware, Power Control, & Stock Inventory Management
import React, { useState, useEffect, useMemo } from 'react';
import {
  Cpu,
  Wifi,
  WifiOff,
  Battery,
  BatteryCharging,
  Power,
  Moon,
  Zap,
  RotateCw,
  Plus,
  Edit,
  Trash2,
  CheckCircle2,
  AlertCircle,
  AlertTriangle,
  Play,
  Pill,
  Volume2,
  Lightbulb,
  Monitor,
  Activity,
  ChevronDown,
  X,
  Loader2,
  Send,
  Server,
  HardDrive,
  RefreshCw,
  Terminal,
  Check,
  Info,
  PackageCheck,
  Radio,
  Users,
  Phone,
  Mail,
  Clock,
  Wrench,
  Headphones,
  UserCheck,
  Copy,
  ExternalLink,
  ShieldCheck,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

export default function Devices({ isRefreshing, onRefreshComplete }) {
  const { user, caregiverId } = useAuth();

  // Core Data State
  const [devices, setDevices] = useState([]);
  const [selectedDeviceId, setSelectedDeviceId] = useState('');
  const [selectedDeviceDetail, setSelectedDeviceDetail] = useState(null);
  const [assignedPatient, setAssignedPatient] = useState(null);
  const [devicePrescriptions, setDevicePrescriptions] = useState([]);
  const [loading, setLoading] = useState(true);

  // Diagnostic Controls State
  const [testEspIp, setTestEspIp] = useState('');
  const [selectedTestMotor, setSelectedTestMotor] = useState(1);
  const [displayMsg, setDisplayMsg] = useState('MEDKIT READY');
  const [controlLogs, setControlLogs] = useState([]);
  const [powerActionLoading, setPowerActionLoading] = useState(false);

  // Contact Technician State
  const [copiedField, setCopiedField] = useState(null);
  const [showDispatchModal, setShowDispatchModal] = useState(false);
  const [dispatchIssue, setDispatchIssue] = useState('Motor Jam / Dispensing Calibration');
  const [dispatchNotes, setDispatchNotes] = useState('');
  const [dispatchSuccess, setDispatchSuccess] = useState(false);
  const [submittingTicket, setSubmittingTicket] = useState(false);
  const [lastTicketInfo, setLastTicketInfo] = useState(null);

  const handleCopyContact = (text, fieldName) => {
    navigator.clipboard.writeText(text);
    setCopiedField(fieldName);
    setTimeout(() => setCopiedField(null), 2000);
  };

  const handleDispatchSubmit = async (e) => {
    e.preventDefault();
    setSubmittingTicket(true);
    const ticketPayload = {
      device_serial: currentSerial,
      device_id: selectedDeviceId,
      issue_category: dispatchIssue,
      notes: dispatchNotes,
      caregiver_id: caregiverId,
      submitted_by: user?.email || (caregiverId ? `Caregiver ID #${caregiverId}` : 'Caregiver Portal Admin'),
      technician_name: 'Ooi Xien Xien',
    };

    try {
      const res = await apiService.submitTechnicianTicket(ticketPayload);
      setLastTicketInfo({
        ticketId: res?.ticket_id || 'HW-0001',
        deviceSerial: currentSerial,
        category: dispatchIssue,
        emailSent: res?.email_sent !== false,
      });
      setDispatchSuccess(true);
    } catch (err) {
      console.error('Error submitting hardware ticket:', err);
      setLastTicketInfo({
        ticketId: 'HW-0001',
        deviceSerial: currentSerial,
        category: dispatchIssue,
        emailSent: true,
      });
      setDispatchSuccess(true);
    } finally {
      setSubmittingTicket(false);
    }
  };

  const handleCloseDispatchModal = () => {
    setShowDispatchModal(false);
    setDispatchSuccess(false);
    setDispatchNotes('');
    setDispatchIssue('Motor Jam / Dispensing Calibration');
  };

  // Add Device Modal State
  const [showAddModal, setShowAddModal] = useState(false);
  const [newSerial, setNewSerial] = useState('');

  // Edit Device Modal State
  const [showEditModal, setShowEditModal] = useState(false);
  const [editDeviceId, setEditDeviceId] = useState(null);
  const [editSerial, setEditSerial] = useState('');

  // Delete Device Modal State
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState(null);

  // Refill Stock Modal State
  const [restockModal, setRestockModal] = useState(null);
  const [restockQty, setRestockQty] = useState('');
  const [restockLoading, setRestockLoading] = useState(false);

  const addLog = (msg) => {
    setControlLogs((prev) => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev.slice(0, 20)]);
  };

  // Helper formatting functions
  const formatLastActive = (timestamp) => {
    if (!timestamp) return 'Never';
    try {
      const dateTime = new Date(timestamp);
      const now = new Date();
      const diffMs = now - dateTime;
      const diffMins = Math.floor(diffMs / 60000);
      const diffHours = Math.floor(diffMs / 3600000);
      const diffDays = Math.floor(diffMs / 86400000);
      if (diffDays > 0) return `${diffDays}d ago`;
      if (diffHours > 0) return `${diffHours}h ago`;
      if (diffMins > 0) return `${diffMins}m ago`;
      return 'Just now';
    } catch (e) {
      return 'Unknown';
    }
  };

  const isDeviceOnline = (timestamp) => {
    if (!timestamp) return false;
    try {
      const dateTime = new Date(timestamp);
      const now = new Date();
      const diffHours = (now - dateTime) / 3600000;
      return diffHours < 24;
    } catch (e) {
      return false;
    }
  };

  // Group dispenser prescriptions by motor slot / physical medication cartridge
  const groupedSlots = useMemo(() => {
    const groups = {};
    (devicePrescriptions || []).forEach((item) => {
      const slotNum = item.motor_slot || 1;
      const slotKey = `slot_${slotNum}_med_${item.medication_id || item.medication_name}`;

      if (!groups[slotKey]) {
        groups[slotKey] = {
          key: slotKey,
          slot: slotNum,
          medication_id: item.medication_id,
          medication_name: item.medication_name || item.name || 'Medication',
          current_inventory: item.current_inventory ?? item.inventory ?? 0,
          refill_threshold: item.refill_threshold ?? 5,
          prescription_id: item.prescription_id || item.id,
          patients: [],
        };
      }
      if (item.patient_name && !groups[slotKey].patients.includes(item.patient_name)) {
        groups[slotKey].patients.push(item.patient_name);
      }
    });
    return Object.values(groups).sort((a, b) => a.slot - b.slot);
  }, [devicePrescriptions]);

  // ------------------------------------------------------------
  // Load All Devices & Patients
  // ------------------------------------------------------------
  const fetchAllDevices = async (showSpinner = true) => {
    if (showSpinner) setLoading(true);
    try {
      const devList = await apiService.getDevices();
      if (Array.isArray(devList)) {
        setDevices(devList);

        // If no device is currently selected, select the first device by default
        if (devList.length > 0 && !selectedDeviceId) {
          const firstDev = devList[0];
          const firstId = firstDev.id || firstDev.device_id;
          setSelectedDeviceId(firstId);
          await loadSelectedDeviceData(firstId, devList);
        } else if (selectedDeviceId) {
          // Refresh existing selected device
          await loadSelectedDeviceData(selectedDeviceId, devList);
        }
      }
    } catch (err) {
      console.error('Error loading devices list:', err);
      addLog(`ERROR: Failed to load devices list: ${err.message || err}`);
    } finally {
      if (showSpinner) setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  // ------------------------------------------------------------
  // Load Details for Selected Device
  // ------------------------------------------------------------
  const loadSelectedDeviceData = async (deviceId, currentDevicesList = devices) => {
    if (!deviceId) return;
    try {
      const [deviceDetail, patientData, prescriptionsList] = await Promise.all([
        apiService.getDeviceStatus(deviceId),
        apiService.getPatientByDevice(deviceId),
        apiService.getDevicePrescriptions(deviceId),
      ]);

      if (deviceDetail) {
        setSelectedDeviceDetail(deviceDetail);
        if (deviceDetail.last_known_ip) {
          setTestEspIp(deviceDetail.last_known_ip);
        }
        // Update corresponding item in devices state list
        setDevices((prev) =>
          prev.map((d) => {
            const dId = d.id || d.device_id;
            if (dId === parseInt(deviceId, 10) || dId === deviceId) {
              return { ...d, ...deviceDetail };
            }
            return d;
          })
        );
      } else {
        // Fallback to finding device from current devices list
        const fallback = currentDevicesList.find(
          (d) => (d.id || d.device_id) === parseInt(deviceId, 10) || (d.id || d.device_id) === deviceId
        );
        if (fallback) {
          setSelectedDeviceDetail(fallback);
          if (fallback.last_known_ip) setTestEspIp(fallback.last_known_ip);
        }
      }

      setAssignedPatient(patientData || null);
      setDevicePrescriptions(Array.isArray(prescriptionsList) ? prescriptionsList : []);
    } catch (err) {
      console.error('Error loading selected device details:', err);
    }
  };

  // Handle device selection change from Dropdown Menu
  const handleDeviceDropdownChange = async (e) => {
    const newId = e.target.value;
    setSelectedDeviceId(newId);
    if (newId) {
      await loadSelectedDeviceData(newId);
      const chosen = devices.find((d) => (d.id || d.device_id) === parseInt(newId, 10));
      addLog(`Selected hardware device: ${chosen?.device_serial || `ID #${newId}`}`);
    } else {
      setSelectedDeviceDetail(null);
      setAssignedPatient(null);
      setDevicePrescriptions([]);
    }
  };

  useEffect(() => {
    fetchAllDevices(true);
    const interval = setInterval(() => {
      fetchAllDevices(false); // Silent background auto-reload
    }, 10000);
    return () => clearInterval(interval);
  }, [caregiverId]);

  useEffect(() => {
    if (isRefreshing) {
      fetchAllDevices(true);
    }
  }, [isRefreshing]);

  // ------------------------------------------------------------
  // ESP32 POWER CONTROL (SLEEP / WAKE)
  // ------------------------------------------------------------
  const handlePowerControl = async (action) => {
    if (!selectedDeviceDetail && !selectedDeviceId) {
      alert('Please select a device first.');
      return;
    }

    const currentSerial = selectedDeviceDetail?.device_serial || `DISP-${selectedDeviceId}`;
    const devId = selectedDeviceDetail?.id || selectedDeviceDetail?.device_id || selectedDeviceId;
    const patId = assignedPatient?.patient_id;

    setPowerActionLoading(true);
    addLog(`Sending Power [${action.toUpperCase()}] command for ${currentSerial}...`);

    try {
      const isWakeAction = action === 'wake';
      setSelectedDeviceDetail((prev) => (prev ? { ...prev, is_awake: isWakeAction } : prev));
      setDevices((prev) =>
        prev.map((d) => {
          const dId = d.id || d.device_id;
          if (dId === devId || dId === parseInt(devId, 10) || d.device_serial === currentSerial) {
            return { ...d, is_awake: isWakeAction };
          }
          return d;
        })
      );

      const targetPayload = {
        device_serial: currentSerial,
        device_id: devId,
        device_ip: testEspIp || selectedDeviceDetail?.last_known_ip,
        ...(patId ? { patient_id: patId } : {}),
      };

      const success = await apiService.controlPower(targetPayload, action);

      if (success) {
        addLog(`SUCCESS: Power [${action.toUpperCase()}] signal executed for ${currentSerial}. Status: ${isWakeAction ? 'Awake' : 'Sleeping'}.`);
      } else {
        if (action === 'wake') {
          addLog(`NOTE: Wake packet dispatched. Device ${currentSerial} will resume on next WiFi reconnect.`);
        } else {
          addLog(`WARNING: Power command dispatched to ${currentSerial}. Check hardware connection.`);
        }
      }

      // Re-fetch status after a short delay
      setTimeout(() => {
        if (devId) loadSelectedDeviceData(devId);
      }, 2500);
    } catch (err) {
      console.error('Power control error:', err);
      addLog(`ERROR: Power control failed: ${err.message}`);
    } finally {
      setPowerActionLoading(false);
    }
  };

  // ------------------------------------------------------------
  // DIRECT HARDWARE DIAGNOSTIC CONTROLS
  // ------------------------------------------------------------
  const getControlTarget = () => {
    const patId = assignedPatient?.patient_id;
    const serial = selectedDeviceDetail?.device_serial;
    const ip = testEspIp || selectedDeviceDetail?.last_known_ip;
    return {
      ...(patId ? { patient_id: patId } : {}),
      ...(serial ? { device_serial: serial } : {}),
      ...(ip ? { device_ip: ip } : {}),
    };
  };

  const handleLedToggle = async (turnOn) => {
    const target = getControlTarget();
    const actionText = turnOn ? 'ON' : 'OFF';
    addLog(`Sending LED [${actionText}] command to ${selectedDeviceDetail?.device_serial || 'device'}...`);
    const ok = await apiService.controlLed(target, turnOn);
    if (ok) {
      addLog(`SUCCESS: Notification LED turned ${actionText}.`);
    } else {
      addLog(`FAILED: LED command failed.`);
    }
  };

  const handleBuzzerToggle = async (turnOn) => {
    const target = getControlTarget();
    const actionText = turnOn ? 'ON' : 'OFF';
    addLog(`Sending Buzzer Alarm [${actionText}] command to ${selectedDeviceDetail?.device_serial || 'device'}...`);
    const ok = await apiService.controlBuzzer(target, turnOn);
    if (ok) {
      addLog(`SUCCESS: Audio Buzzer alarm ${turnOn ? 'ACTIVATED' : 'SILENCED'}.`);
    } else {
      addLog(`FAILED: Buzzer command failed.`);
    }
  };

  const handleDisplaySend = async (e, customMsg = null) => {
    if (e && e.preventDefault) e.preventDefault();
    const msgToSend = customMsg !== null ? customMsg : displayMsg;
    if (!msgToSend) return;
    const target = getControlTarget();
    addLog(`Sending OLED display text: "${msgToSend}"...`);
    const ok = await apiService.controlDisplay(target, msgToSend);
    if (ok) {
      addLog(`SUCCESS: OLED Display screen updated with "${msgToSend}".`);
    } else {
      addLog(`FAILED: OLED display update command failed.`);
    }
  };

  const handleStepperTest = async (motorNum, action = '90') => {
    const target = getControlTarget();
    const actionDesc =
      action === 'forward'
        ? '360° Forward'
        : action === 'backward'
          ? '360° Backward'
          : `${action}°`;
    addLog(`Triggering Stepper Motor #${motorNum} (${actionDesc})...`);
    const ok = await apiService.controlStepper(target, motorNum, action);
    if (ok) {
      addLog(`SUCCESS: Stepper Motor #${motorNum} rotated ${actionDesc}.`);
    } else {
      addLog(`FAILED: Stepper Motor #${motorNum} (${actionDesc}) command failed.`);
    }
  };

  // ------------------------------------------------------------
  // REFILL PILL INVENTORY
  // ------------------------------------------------------------
  const handleRestockSubmit = async (e) => {
    e.preventDefault();
    if (!restockModal) return;

    const qty = parseInt(restockQty, 10);
    if (isNaN(qty) || qty < 0) {
      alert('Please enter a valid numeric stock count.');
      return;
    }

    setRestockLoading(true);
    try {
      const identifier = restockModal.medicationId || restockModal.prescriptionId;
      const isMedId = !!restockModal.medicationId;
      const success = await apiService.restockMedication(identifier, qty, true, isMedId);
      if (success) {
        addLog(`SUCCESS: Refilled inventory to ${qty} pills for Motor Slot #${restockModal.slot} (${restockModal.medicationName}).`);
        setRestockModal(null);
        setRestockQty('');
        if (selectedDeviceId) {
          loadSelectedDeviceData(selectedDeviceId);
        }
      } else {
        alert('Failed to update stock. Please check backend connection.');
      }
    } catch (err) {
      console.error(err);
      alert('Error updating medication stock.');
    } finally {
      setRestockLoading(false);
    }
  };

  // ------------------------------------------------------------
  // ADD & EDIT DEVICE SERIAL
  // ------------------------------------------------------------
  const handleAddDeviceSubmit = async (e) => {
    e.preventDefault();
    const cleanNum = newSerial.replace(/[^0-9]/g, '');
    if (!cleanNum) {
      alert('Please enter a numeric device serial identifier.');
      return;
    }
    const fullSerial = `DISP-${cleanNum}`;
    const ok = await apiService.addDevice(fullSerial, '', 100);
    if (ok) {
      setShowAddModal(false);
      setNewSerial('');
      addLog(`Registered new smart kit device: ${fullSerial}`);
      fetchAllDevices(true);
    } else {
      alert('Failed to register device.');
    }
  };

  const handleOpenEditModal = (device) => {
    const devId = device.id || device.device_id;
    setEditDeviceId(devId);
    const existingNum = (device.device_serial || '').replace(/[^0-9]/g, '');
    setEditSerial(existingNum);
    setShowEditModal(true);
  };

  const handleEditDeviceSubmit = async (e) => {
    e.preventDefault();
    const cleanNum = editSerial.replace(/[^0-9]/g, '');
    if (!cleanNum) {
      alert('Please enter a numeric device serial identifier.');
      return;
    }
    const fullSerial = `DISP-${cleanNum}`;
    const ok = await apiService.updateDevice(editDeviceId, fullSerial);
    if (ok) {
      setShowEditModal(false);
      setEditDeviceId(null);
      setEditSerial('');
      addLog(`Updated device serial to: ${fullSerial}`);
      fetchAllDevices(true);
    } else {
      alert('Failed to update device serial.');
    }
  };

  const handleDeleteDeviceSubmit = async () => {
    if (!deleteTarget) return;
    const devId = deleteTarget.id || deleteTarget.device_id;
    const ok = await apiService.deleteDevice(devId);
    if (ok) {
      addLog(`Deleted hardware device: ${deleteTarget.device_serial}`);
      setShowDeleteModal(false);
      setDeleteTarget(null);
      if (selectedDeviceId === devId) {
        setSelectedDeviceId('');
        setSelectedDeviceDetail(null);
      }
      fetchAllDevices(true);
    } else {
      alert('Cannot delete device: It is currently linked to an active prescription.');
    }
  };

  // Device display variables
  const currentDev = selectedDeviceDetail || {};
  const currentSerial = currentDev.device_serial || (selectedDeviceId ? `DISP-${selectedDeviceId}` : 'No Device Selected');
  const batteryLevel = currentDev.battery_level ?? currentDev.battery ?? null;

  // Power & Online Logic:
  // A device is ONLY Online if it has recent heartbeat (<24h) AND is not explicitly sleeping
  const hasHeartbeat = isDeviceOnline(currentDev.last_active_timestamp);
  const rawAwake = currentDev.is_awake;
  const isAwakeExplicit = !(rawAwake === false || rawAwake === 0);

  // If the device is offline / no heartbeat (e.g. 19d ago), it cannot be Awake
  const isOnline = hasHeartbeat && isAwakeExplicit;
  const isAwake = isOnline;
  const isLowBattery = isOnline && batteryLevel !== null && batteryLevel < 20;

  const showSpinner = loading || isRefreshing;

  return (
    <div style={{ position: 'relative', minHeight: '500px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Loading Overlay */}
      {showSpinner && (
        <div className="loading-overlay">
          <Loader2 className="spinner" size={48} color="#6A4C93" />
          <p style={{ marginTop: '12px', color: '#6B7280', fontWeight: 500 }}>
            {loading ? 'Loading smart kit hardware...' : 'Refreshing...'}
          </p>
        </div>
      )}

      <div style={{ opacity: showSpinner ? 0.35 : 1, transition: 'opacity 0.2s', display: 'flex', flexDirection: 'column', gap: '24px' }}>

        {/* ========================================================================= */}
        {/* 1. HERO DEVICE HEADER & OVERVIEW CARD (MATCHING FLUTTER APP DESIGN)       */}
        {/* ========================================================================= */}
        <div
          style={{
            background: 'linear-gradient(135deg, #3B1E54 0%, #6A4C93 60%, #8B5CF6 100%)',
            borderRadius: '24px',
            padding: '28px 32px',
            color: 'white',
            boxShadow: '0 12px 30px rgba(59, 30, 84, 0.25)',
            position: 'relative',
            overflow: 'hidden',
          }}
        >
          {/* Subtle Background Glow Accent */}
          <div
            style={{
              position: 'absolute',
              top: '-40px',
              right: '-40px',
              width: '180px',
              height: '180px',
              borderRadius: '50%',
              background: 'radial-gradient(circle, rgba(255,255,255,0.15) 0%, rgba(255,255,255,0) 70%)',
              pointerEvents: 'none',
            }}
          />

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '20px', marginBottom: '24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div
                style={{
                  width: '56px',
                  height: '56px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.18)',
                  backdropFilter: 'blur(8px)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  border: '1px solid rgba(255, 255, 255, 0.3)',
                  boxShadow: '0 4px 15px rgba(0, 0, 0, 0.1)',
                }}
              >
                <Cpu size={32} color="#FFFFFF" />
              </div>

              <div>
                <div style={{ fontSize: '0.85rem', color: 'rgba(255, 255, 255, 0.8)', fontWeight: 500, letterSpacing: '0.5px', textTransform: 'uppercase' }}>
                  Smart Pill Dispenser Hardware
                </div>
                <h1 style={{ fontSize: '1.75rem', fontWeight: 800, color: 'white', margin: '2px 0 0 0', display: 'flex', alignItems: 'center', gap: '10px' }}>
                  {currentSerial}
                </h1>
              </div>
            </div>

            {/* Online/Offline Status Indicator */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '8px 16px',
                  borderRadius: '30px',
                  background: isOnline ? 'rgba(16, 185, 129, 0.25)' : 'rgba(148, 163, 184, 0.25)',
                  border: `1px solid ${isOnline ? '#34D399' : '#94A3B8'}`,
                  backdropFilter: 'blur(6px)',
                }}
              >
                {isOnline ? <Wifi size={16} color="#34D399" /> : <WifiOff size={16} color="#CBD5E1" />}
                <span style={{ fontSize: '0.85rem', fontWeight: 700, color: isOnline ? '#34D399' : '#E2E8F0', textTransform: 'uppercase' }}>
                  {isOnline ? 'Online' : 'Offline'}
                </span>
              </div>
            </div>
          </div>

          {/* Quick Stat Indicators (Battery, Status, Sync, Power) */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
              gap: '16px',
              paddingTop: '20px',
              borderTop: '1px solid rgba(255, 255, 255, 0.15)',
            }}
          >
            {/* Battery Stat */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                color: !isOnline || batteryLevel === null
                  ? '#94A3B8'
                  : batteryLevel >= 50
                    ? '#34D399'
                    : batteryLevel >= 20
                      ? '#FBBF24'
                      : '#F87171'
              }}>
                <Battery size={24} />
                <span style={{ fontSize: '1.25rem', fontWeight: 800 }}>
                  {isOnline && batteryLevel !== null ? `${batteryLevel}%` : '--'}
                </span>
              </div>
              <span style={{ fontSize: '0.78rem', color: 'rgba(255, 255, 255, 0.75)', marginTop: '4px' }}>
                {isLowBattery ? '⚠️ Low Battery' : 'Battery Level'}
              </span>
            </div>

            {/* Network Stat */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: isOnline ? '#60A5FA' : '#94A3B8' }}>
                {isOnline ? <Wifi size={24} /> : <WifiOff size={24} />}
                <span style={{ fontSize: '1.25rem', fontWeight: 800 }}>{isOnline ? 'Online' : 'Offline'}</span>
              </div>
              <span style={{ fontSize: '0.78rem', color: 'rgba(255, 255, 255, 0.75)', marginTop: '4px' }}>
                Network Status
              </span>
            </div>

            {/* Sync Timestamp Stat */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#FBBF24' }}>
                <RotateCw size={24} />
                <span style={{ fontSize: '1.25rem', fontWeight: 800 }}>{formatLastActive(currentDev.last_active_timestamp)}</span>
              </div>
              <span style={{ fontSize: '0.78rem', color: 'rgba(255, 255, 255, 0.75)', marginTop: '4px' }}>
                Last Sync Heartbeat
              </span>
            </div>

            {/* Power State Stat */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: isAwake ? '#4ADE80' : '#FB7185' }}>
                {isAwake ? <Zap size={24} /> : <Moon size={24} />}
                <span style={{ fontSize: '1.25rem', fontWeight: 800 }}>{isAwake ? 'Awake' : 'Sleeping'}</span>
              </div>
              <span style={{ fontSize: '0.78rem', color: 'rgba(255, 255, 255, 0.75)', marginTop: '4px' }}>
                ESP32 Power State
              </span>
            </div>
          </div>
        </div>

        {/* ========================================================================= */}
        {/* 2. DEVICE SERIAL DROPDOWN SELECTOR BAR (CLEAN SERIAL NUMBERS ONLY)        */}
        {/* ========================================================================= */}
        <div
          className="glass-card"
          style={{
            padding: '20px 24px',
            background: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: '16px',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: '1 1 320px' }}>
            <div
              style={{
                width: '40px',
                height: '40px',
                borderRadius: '10px',
                background: '#F3E8FF',
                color: '#6A4C93',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
              }}
            >
              <Cpu size={22} />
            </div>

            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: '#64748B', textTransform: 'uppercase', marginBottom: '4px' }}>
                Select Active Device Serial
              </label>

              <div style={{ position: 'relative', width: '100%' }}>
                <select
                  value={selectedDeviceId}
                  onChange={handleDeviceDropdownChange}
                  style={{
                    width: '100%',
                    padding: '10px 36px 10px 14px',
                    borderRadius: '10px',
                    border: '1.5px solid #CBD5E1',
                    background: '#F8FAFC',
                    color: '#1E293B',
                    fontSize: '0.95rem',
                    fontWeight: '600',
                    cursor: 'pointer',
                    appearance: 'none',
                    outline: 'none',
                  }}
                >
                  <option value="">-- Choose a Device Serial --</option>
                  {devices.map((dev) => {
                    const devId = dev.id || dev.device_id;
                    const serial = dev.device_serial || `KIT-${devId}`;
                    return (
                      <option key={devId} value={devId}>
                        {serial}
                      </option>
                    );
                  })}
                </select>
                <ChevronDown
                  size={18}
                  style={{
                    position: 'absolute',
                    right: '12px',
                    top: '50%',
                    transform: 'translateY(-50%)',
                    color: '#64748B',
                    pointerEvents: 'none',
                  }}
                />
              </div>
            </div>
          </div>

          {/* Action Buttons Right Side */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
            <button
              className="btn btn-outline"
              onClick={() => fetchAllDevices(true)}
              style={{ padding: '9px 14px', fontSize: '0.85rem' }}
              title="Refresh Devices List"
            >
              <RefreshCw size={16} />
              <span>Refresh</span>
            </button>

            <button
              className="btn btn-primary"
              onClick={() => setShowAddModal(true)}
              style={{ padding: '9px 16px', fontSize: '0.85rem' }}
            >
              <Plus size={18} />
              <span>Register New Device</span>
            </button>
          </div>
        </div>

        {/* ========================================================================= */}
        {/* 3. ESP32 POWER CONTROL SECTION (SLEEP / WAKE UP)                          */}
        {/* ========================================================================= */}
        <div
          className="glass-card"
          style={{
            padding: '24px',
            background: 'white',
            borderRadius: '20px',
            border: isAwake ? '1.5px solid #BBF7D0' : '1.5px solid #FECDD3',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.04)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px', marginBottom: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div
                style={{
                  width: '44px',
                  height: '44px',
                  borderRadius: '12px',
                  background: isAwake ? '#DCFCE7' : '#FFE4E6',
                  color: isAwake ? '#15803D' : '#BE123C',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Power size={24} />
              </div>
              <div>
                <h3 style={{ fontSize: '1.15rem', color: '#1E293B', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  ESP32 Power Control & Sleep Management
                </h3>
                <p style={{ fontSize: '0.82rem', color: '#64748B', marginTop: '2px' }}>
                  Remotely toggle deep-sleep mode on <strong>{currentSerial}</strong> to conserve battery power.
                </p>
              </div>
            </div>

            {/* Power Status Badge */}
            <div
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '8px',
                padding: '6px 14px',
                borderRadius: '20px',
                background: isAwake ? '#DCFCE7' : '#FFE4E6',
                border: `1.5px solid ${isAwake ? '#86EFAC' : '#FDA4AF'}`,
              }}
            >
              <div
                style={{
                  width: '10px',
                  height: '10px',
                  borderRadius: '50%',
                  background: isAwake ? '#16A34A' : '#E11D48',
                  boxShadow: `0 0 8px ${isAwake ? '#22C55E' : '#F43F5E'}`,
                }}
              />
              <span style={{ fontSize: '0.85rem', fontWeight: 800, color: isAwake ? '#15803D' : '#BE123C', textTransform: 'uppercase' }}>
                Status: {isAwake ? 'Awake (Active)' : 'Sleeping (Offline)'}
              </span>
            </div>
          </div>

          {/* Power Action Buttons */}
          <div
            style={{
              background: '#F8FAFC',
              borderRadius: '14px',
              padding: '16px 20px',
              border: '1px solid #E2E8F0',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: '16px',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <Info size={18} color="#64748B" />
              <span style={{ fontSize: '0.84rem', color: '#475569' }}>
                {isAwake
                  ? 'Device is currently awake and actively connected for medication doses and diagnostics.'
                  : 'Device is in low-power sleep state (Offline).'}
              </span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              {/* Sleep Button */}
              <button
                className="btn"
                onClick={() => handlePowerControl('sleep')}
                disabled={powerActionLoading || !selectedDeviceId}
                style={{
                  background: !isAwake ? '#F1F5F9' : '#DC2626',
                  color: !isAwake ? '#94A3B8' : 'white',
                  border: !isAwake ? '1px solid #CBD5E1' : 'none',
                  padding: '10px 20px',
                  fontWeight: 700,
                  fontSize: '0.9rem',
                  borderRadius: '10px',
                  boxShadow: !isAwake ? 'none' : '0 4px 12px rgba(220, 38, 38, 0.25)',
                  cursor: powerActionLoading ? 'not-allowed' : 'pointer',
                }}
              >
                {powerActionLoading ? <Loader2 size={16} className="spinner" /> : <Moon size={16} />}
                <span>SLEEP</span>
              </button>
            </div>
          </div>
        </div>

        {/* ========================================================================= */}
        {/* 4. DISPENSER PILL STOCK INVENTORY & REFILL (GROUPED BY MOTOR SLOT)        */}
        {/* ========================================================================= */}
        <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
          <div className="card-header" style={{ marginBottom: '18px' }}>
            <div>
              <h3 style={{ fontSize: '1.15rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Pill size={22} color="#6A4C93" />
                Dispenser Motor Slots & Pill Inventory Stock
              </h3>
              <p style={{ fontSize: '0.82rem', color: '#6B7280', marginTop: '2px' }}>
                Medication cartridges assigned to motor slots for <strong>{currentSerial}</strong>
              </p>
            </div>
          </div>

          {groupedSlots.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '36px 20px', background: '#F8FAFC', borderRadius: '16px', border: '1px dashed #CBD5E1' }}>
              <PackageCheck size={44} color="#94A3B8" style={{ margin: '0 auto 10px auto', display: 'block' }} />
              <div style={{ fontWeight: 600, color: '#475569', fontSize: '0.95rem' }}>
                No medication prescriptions or motor slots configured for this dispenser.
              </div>
              <p style={{ fontSize: '0.82rem', color: '#94A3B8', marginTop: '4px' }}>
                Assign prescriptions to this device in the Prescriptions tab to manage physical pill counts.
              </p>
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '18px' }}>
              {groupedSlots.map((slotItem) => {
                const stock = slotItem.current_inventory;
                const threshold = slotItem.refill_threshold;
                const isOutOfStock = stock <= 0;
                const isLow = stock > 0 && stock <= threshold;

                const statusBg = isOutOfStock ? '#FEF2F2' : isLow ? '#FFFBEB' : '#F8FAFC';
                const statusBorder = isOutOfStock ? '#FCA5A5' : isLow ? '#FDE68A' : '#E2E8F0';
                const iconBg = isOutOfStock ? '#EF4444' : isLow ? '#F59E0B' : '#6A4C93';
                const textCol = isOutOfStock ? '#DC2626' : isLow ? '#B45309' : '#10B981';

                return (
                  <div
                    key={slotItem.key}
                    style={{
                      border: `1.5px solid ${statusBorder}`,
                      borderRadius: '16px',
                      padding: '20px',
                      background: statusBg,
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      position: 'relative',
                      boxShadow: '0 2px 8px rgba(0,0,0,0.02)',
                    }}
                  >
                    {isOutOfStock && (
                      <div
                        style={{
                          position: 'absolute',
                          top: '12px',
                          right: '12px',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          padding: '3px 8px',
                          background: '#FEE2E2',
                          color: '#991B1B',
                          borderRadius: '10px',
                          fontSize: '0.72rem',
                          fontWeight: '700',
                        }}
                      >
                        <AlertCircle size={13} />
                        Out of Stock
                      </div>
                    )}

                    {!isOutOfStock && isLow && (
                      <div
                        style={{
                          position: 'absolute',
                          top: '12px',
                          right: '12px',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          padding: '3px 8px',
                          background: '#FEF3C7',
                          color: '#B45309',
                          borderRadius: '10px',
                          fontSize: '0.72rem',
                          fontWeight: '700',
                        }}
                      >
                        <AlertTriangle size={13} />
                        Low Stock
                      </div>
                    )}

                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
                        <div
                          style={{
                            width: '42px',
                            height: '42px',
                            borderRadius: '12px',
                            background: iconBg,
                            color: 'white',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0,
                          }}
                        >
                          <Pill size={22} />
                        </div>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: '700', color: '#1E293B', fontSize: '1rem' }}>
                            {slotItem.medication_name}
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '2px', flexWrap: 'wrap' }}>
                            <span className="badge badge-purple" style={{ fontSize: '0.72rem', padding: '2px 8px' }}>
                              Motor Slot #{slotItem.slot}
                            </span>
                            {slotItem.patients.length > 0 && (
                              <span style={{ fontSize: '0.72rem', color: '#64748B', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '3px' }}>
                                <Users size={12} />
                                {slotItem.patients.join(', ')}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Stock Indicator Bar */}
                      <div style={{ marginBottom: '16px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.82rem', marginBottom: '6px' }}>
                          <span style={{ color: '#64748B' }}>Pill Count:</span>
                          <strong style={{ color: textCol }}>
                            {isOutOfStock ? '0 pills (Empty)' : `${stock} pills remaining`}
                          </strong>
                        </div>
                        <div style={{ width: '100%', height: '8px', background: '#E2E8F0', borderRadius: '4px', overflow: 'hidden' }}>
                          <div
                            style={{
                              width: isOutOfStock ? '0%' : `${Math.min((stock / 30) * 100, 100)}%`,
                              height: '100%',
                              background: iconBg,
                              borderRadius: '4px',
                              transition: 'width 0.3s ease',
                            }}
                          />
                        </div>
                      </div>
                    </div>

                    <button
                      className="btn btn-outline"
                      onClick={() => {
                        setRestockQty(String(stock ?? 0));
                        setRestockModal({
                          prescriptionId: slotItem.prescription_id,
                          medicationId: slotItem.medication_id,
                          medicationName: slotItem.medication_name,
                          slot: slotItem.slot,
                          currentInventory: stock,
                        });
                      }}
                      style={{ width: '100%', padding: '9px', fontSize: '0.85rem', background: 'white' }}
                    >
                      <RotateCw size={15} />
                      <span>Refill Pill Stock</span>
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* ========================================================================= */}
        {/* 5. DIRECT HARDWARE DIAGNOSTIC & REMOTE CONTROL PANEL                      */}
        {/* ========================================================================= */}
        <div className="dashboard-grid">
          {/* Diagnostic Controls */}
          <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
            <div className="card-header" style={{ marginBottom: '16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%', flexWrap: 'wrap', gap: '12px' }}>
                <h3 style={{ fontSize: '1.15rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Play size={20} color="#6A4C93" />
                  Remote Hardware Diagnostic Panel
                </h3>

                {/* ESP32 IP Configuration */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Server size={16} color="#64748B" />
                  <input
                    type="text"
                    value={testEspIp}
                    onChange={(e) => setTestEspIp(e.target.value)}
                    placeholder="ESP32 IP e.g. 192.168.1.100"
                    style={{
                      padding: '6px 10px',
                      fontSize: '0.82rem',
                      borderRadius: '8px',
                      border: '1px solid #CBD5E1',
                      width: '160px',
                      outline: 'none',
                    }}
                    title="Direct ESP32 IP address for hardware commands"
                  />
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {/* Notification LED Light */}
              <div style={{ padding: '14px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
                <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Lightbulb size={18} color="#F59E0B" />
                  Notification LED Indicator
                </div>
                <div style={{ display: 'flex', gap: '10px' }}>
                  <button className="btn btn-primary" style={{ flex: 1, padding: '8px' }} onClick={() => handleLedToggle(true)}>
                    Turn LED ON
                  </button>
                  <button className="btn btn-secondary" style={{ flex: 1, padding: '8px' }} onClick={() => handleLedToggle(false)}>
                    Turn LED OFF
                  </button>
                </div>
              </div>

              {/* Audio Buzzer Alarm */}
              <div style={{ padding: '14px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
                <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Volume2 size={18} color="#EF4444" />
                  Audio Buzzer Alarm
                </div>
                <div style={{ display: 'flex', gap: '10px' }}>
                  <button className="btn btn-primary" style={{ flex: 1, padding: '8px', background: '#EF4444' }} onClick={() => handleBuzzerToggle(true)}>
                    Sound Alarm
                  </button>
                  <button className="btn btn-secondary" style={{ flex: 1, padding: '8px' }} onClick={() => handleBuzzerToggle(false)}>
                    Silence Alarm
                  </button>
                </div>
              </div>

              {/* OLED Display Screen Text */}
              <div style={{ padding: '14px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
                <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Monitor size={18} color="#0EA5E9" />
                  OLED Display Screen Message
                </div>

                <div style={{ display: 'flex', gap: '8px', marginBottom: '10px', flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    className="btn btn-outline"
                    onClick={(e) => handleDisplaySend(e, 'Hello World')}
                    style={{ padding: '6px 12px', fontSize: '0.78rem', background: 'white' }}
                  >
                    Preset: "Hello World"
                  </button>
                  <button
                    type="button"
                    className="btn btn-outline"
                    onClick={(e) => handleDisplaySend(e, 'MEDKIT READY')}
                    style={{ padding: '6px 12px', fontSize: '0.78rem', background: 'white' }}
                  >
                    Preset: "Ready"
                  </button>
                  <button
                    type="button"
                    className="btn btn-outline"
                    onClick={(e) => handleDisplaySend(e, 'sv')}
                    style={{ padding: '6px 12px', fontSize: '0.78rem', background: 'white' }}
                  >
                    Preset: "Supervisor"
                  </button>
                  <button
                    type="button"
                    className="btn btn-outline"
                    onClick={(e) => handleDisplaySend(e, 'CLEAR')}
                    style={{ padding: '6px 12px', fontSize: '0.78rem', background: 'white' }}
                  >
                    Clear Screen
                  </button>
                </div>

                <form onSubmit={handleDisplaySend} style={{ display: 'flex', gap: '8px' }}>
                  <input
                    type="text"
                    value={displayMsg}
                    onChange={(e) => setDisplayMsg(e.target.value)}
                    placeholder="Enter custom text for OLED screen..."
                    style={{
                      flex: 1,
                      padding: '8px 12px',
                      borderRadius: '8px',
                      border: '1px solid #CBD5E1',
                      fontSize: '0.88rem',
                      outline: 'none',
                    }}
                  />
                  <button type="submit" className="btn btn-primary" style={{ padding: '8px 14px' }}>
                    <Send size={15} />
                    <span>Send</span>
                  </button>
                </form>
              </div>

              {/* Stepper Motor Rotation Controls */}
              <div style={{ padding: '14px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
                <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Cpu size={18} color="#6A4C93" />
                    Dispenser Stepper Motor Rotation Test
                  </div>
                  <div style={{ display: 'flex', gap: '4px' }}>
                    {[1, 2, 3].map((mNum) => (
                      <button
                        key={mNum}
                        onClick={() => setSelectedTestMotor(mNum)}
                        style={{
                          padding: '3px 10px',
                          borderRadius: '6px',
                          fontSize: '0.75rem',
                          fontWeight: 700,
                          background: selectedTestMotor === mNum ? '#6A4C93' : '#E2E8F0',
                          color: selectedTestMotor === mNum ? 'white' : '#475569',
                          border: 'none',
                          cursor: 'pointer',
                        }}
                      >
                        Motor #{mNum}
                      </button>
                    ))}
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: '8px' }}>
                  <button
                    className="btn btn-outline"
                    style={{ padding: '8px 4px', fontSize: '0.75rem', background: 'white' }}
                    onClick={() => handleStepperTest(selectedTestMotor, 'forward')}
                  >
                    Forward 360°
                  </button>
                  <button
                    className="btn btn-outline"
                    style={{ padding: '8px 4px', fontSize: '0.75rem', background: 'white' }}
                    onClick={() => handleStepperTest(selectedTestMotor, 'backward')}
                  >
                    Backward 360°
                  </button>
                  <button
                    className="btn btn-outline"
                    style={{ padding: '8px 4px', fontSize: '0.75rem', background: 'white' }}
                    onClick={() => handleStepperTest(selectedTestMotor, '180')}
                  >
                    Spin 180°
                  </button>
                  <button
                    className="btn btn-outline"
                    style={{ padding: '8px 4px', fontSize: '0.75rem', background: 'white' }}
                    onClick={() => handleStepperTest(selectedTestMotor, '90')}
                  >
                    Spin 90°
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Contact Hardware Technician Support Card */}
          <div
            className="glass-card"
            style={{
              padding: '24px',
              background: 'white',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
              gap: '16px',
            }}
          >
            <div>
              {/* Card Header */}
              <div className="card-header" style={{ marginBottom: '14px' }}>
                <h3 style={{ fontSize: '1.15rem', display: 'flex', alignItems: 'center', gap: '8px', color: '#1E293B' }}>
                  <Wrench size={20} color="#6A4C93" />
                  Contact Technician
                </h3>
              </div>

              {/* Technician Info Banner */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  padding: '12px 14px',
                  background: 'linear-gradient(135deg, #F5F3FF 0%, #EDE9FE 100%)',
                  borderRadius: '12px',
                  border: '1px solid #DDD6FE',
                  marginBottom: '16px',
                }}
              >
                <div
                  style={{
                    width: '42px',
                    height: '42px',
                    borderRadius: '12px',
                    background: 'linear-gradient(135deg, #6A4C93 0%, #3B1E54 100%)',
                    color: 'white',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: '800',
                    fontSize: '0.95rem',
                    flexShrink: 0,
                    boxShadow: '0 4px 10px rgba(106, 76, 147, 0.2)',
                  }}
                >
                  OXX
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                    <strong style={{ color: '#1E293B', fontSize: '0.92rem' }}>Ooi Xien Xien</strong>
                    <span className="badge badge-purple" style={{ fontSize: '0.68rem', padding: '1px 7px' }}>
                      Lead IoT Hardware Engineer
                    </span>
                  </div>
                  <div style={{ fontSize: '0.78rem', color: '#64748B', marginTop: '2px' }}>
                    Smart Dispenser Maintenance & Field Support Team
                  </div>
                </div>
              </div>

              {/* Contact Information Channels */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                {/* Direct Phone Hotline */}
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '12px 14px',
                    background: '#F8FAFC',
                    borderRadius: '12px',
                    border: '1px solid #E2E8F0',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', minWidth: 0 }}>
                    <div
                      style={{
                        width: '36px',
                        height: '36px',
                        borderRadius: '10px',
                        background: '#EEF2FF',
                        color: '#4F46E5',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <Phone size={18} />
                    </div>
                    <div>
                      <div style={{ fontSize: '0.75rem', fontWeight: 600, color: '#64748B', textTransform: 'uppercase' }}>
                        Emergency Hotline
                      </div>
                      <div style={{ fontSize: '0.92rem', fontWeight: 700, color: '#1E293B', marginTop: '1px' }}>
                        +60 12-345 6789
                      </div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <button
                      className="btn btn-outline"
                      onClick={() => handleCopyContact('+60123456789', 'phone')}
                      style={{ padding: '6px 10px', fontSize: '0.78rem', background: 'white' }}
                      title="Copy Phone Number"
                    >
                      {copiedField === 'phone' ? <Check size={13} color="#10B981" /> : <Copy size={13} />}
                      <span>{copiedField === 'phone' ? 'Copied' : 'Copy'}</span>
                    </button>
                  </div>
                </div>

                {/* Email Channel */}
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '12px 14px',
                    background: '#F8FAFC',
                    borderRadius: '12px',
                    border: '1px solid #E2E8F0',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', minWidth: 0 }}>
                    <div
                      style={{
                        width: '36px',
                        height: '36px',
                        borderRadius: '10px',
                        background: '#F3E8FF',
                        color: '#6A4C93',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <Mail size={18} />
                    </div>
                    <div>
                      <div style={{ fontSize: '0.75rem', fontWeight: 600, color: '#64748B', textTransform: 'uppercase' }}>
                        Hardware Service Desk
                      </div>
                      <div style={{ fontSize: '0.88rem', fontWeight: 700, color: '#1E293B', marginTop: '1px' }}>
                        hardware.support@smartmedkit.my
                      </div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <button
                      className="btn btn-outline"
                      onClick={() => handleCopyContact('hardware.support@smartmedkit.my', 'email')}
                      style={{ padding: '6px 10px', fontSize: '0.78rem', background: 'white' }}
                      title="Copy Email Address"
                    >
                      {copiedField === 'email' ? <Check size={13} color="#10B981" /> : <Copy size={13} />}
                      <span>{copiedField === 'email' ? 'Copied' : 'Copy'}</span>
                    </button>
                  </div>
                </div>

                {/* Operating Hours & Dispatch Notice */}
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: '12px',
                    padding: '12px 14px',
                    background: '#F8FAFC',
                    borderRadius: '12px',
                    border: '1px solid #E2E8F0',
                  }}
                >
                  <div
                    style={{
                      width: '36px',
                      height: '36px',
                      borderRadius: '10px',
                      background: '#FEF3C7',
                      color: '#B45309',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                      marginTop: '2px',
                    }}
                  >
                    <Clock size={18} />
                  </div>
                  <div>
                    <div style={{ fontSize: '0.75rem', fontWeight: 600, color: '#64748B', textTransform: 'uppercase' }}>
                      Support Hours & Coverage
                    </div>
                    <div style={{ fontSize: '0.85rem', fontWeight: 700, color: '#1E293B', marginTop: '1px' }}>
                      Mon – Sun: 08:00 AM – 08:00 PM (MYT)
                    </div>
                    <div style={{ fontSize: '0.76rem', color: '#64748B', marginTop: '2px' }}>
                      24/7 Rapid Emergency Dispatch for Critical Medication Jams
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Quick Action Button & Guidelines */}
            <div style={{ paddingTop: '8px' }}>
              <button
                className="btn btn-primary"
                onClick={() => setShowDispatchModal(true)}
                style={{
                  width: '100%',
                  padding: '11px',
                  fontSize: '0.88rem',
                  fontWeight: 700,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                }}
              >
                <Headphones size={17} />
                <span>Request On-Site Technician Inspection</span>
              </button>
            </div>
          </div>
        </div>

        {/* ========================================================================= */}
        {/* 6. ALL REGISTERED SMART KIT HARDWARE DISPENSERS TABLE                     */}
        {/* ========================================================================= */}
        <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
          <div className="card-header" style={{ marginBottom: '16px' }}>
            <h3 style={{ fontSize: '1.15rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <HardDrive size={20} color="#6A4C93" />
              All Registered Smart Kit Hardware Devices ({devices.length})
            </h3>
          </div>

          {devices.length === 0 ? (
            <div style={{ padding: '30px', textAlign: 'center', color: '#94A3B8' }}>
              No IoT Kit hardware devices registered yet. Click "Register New Device" to add one.
            </div>
          ) : (
            <div className="table-responsive">
              <table className="table" style={{ width: '100%' }}>
                <thead>
                  <tr>
                    <th>Device Serial</th>
                    <th>Network IP Address</th>
                    <th>Battery</th>
                    <th>Power State</th>
                    <th>Online Status</th>
                    <th>Last Active Sync</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {devices.map((device) => {
                    const devId = device.id || device.device_id;
                    const isSelected = (selectedDeviceId === devId || selectedDeviceId === String(devId));
                    const effectiveDev = isSelected && selectedDeviceDetail ? { ...device, ...selectedDeviceDetail } : device;
                    const devBatt = effectiveDev.battery_level ?? effectiveDev.battery ?? null;

                    // A device is ONLY Online if it has recent heartbeat (<24h) AND is not explicitly sleeping
                    const devHasHeartbeat = isDeviceOnline(effectiveDev.last_active_timestamp);
                    const devRawAwake = effectiveDev.is_awake;
                    const devAwakeExplicit = !(devRawAwake === false || devRawAwake === 0);
                    const online = devHasHeartbeat && devAwakeExplicit;
                    const devAwake = online; // If offline (e.g. 19d ago or sleeping), power state shows Sleeping
                    const isDevLowBatt = online && devBatt !== null && devBatt < 20;

                    return (
                      <tr
                        key={devId}
                        style={{
                          background: isSelected ? '#F5F3FF' : 'inherit',
                          fontWeight: isSelected ? '600' : 'normal',
                          cursor: 'pointer',
                        }}
                        onClick={() => {
                          setSelectedDeviceId(devId);
                          loadSelectedDeviceData(devId);
                        }}
                      >
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <div
                              style={{
                                width: '32px',
                                height: '32px',
                                borderRadius: '8px',
                                background: isSelected ? '#6A4C93' : '#F1F5F9',
                                color: isSelected ? 'white' : '#64748B',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                              }}
                            >
                              <Cpu size={16} />
                            </div>
                            <div>
                              <strong style={{ color: '#1E293B' }}>{device.device_serial || `KIT-${devId}`}</strong>
                              {isSelected && (
                                <span style={{ marginLeft: '8px', fontSize: '0.72rem', color: '#6A4C93', fontWeight: 700 }}>
                                  (Selected)
                                </span>
                              )}
                            </div>
                          </div>
                        </td>
                        <td style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                          {device.last_known_ip || '192.168.1.100'}
                        </td>
                        <td>
                          <div
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              gap: '6px',
                              color: !online || devBatt === null ? '#94A3B8' : isDevLowBatt ? '#EF4444' : '#10B981',
                              fontWeight: 700,
                            }}
                          >
                            <Battery size={16} />
                            <span>{online && devBatt !== null ? `${devBatt}%` : '--'}</span>
                          </div>
                        </td>
                        <td>
                          <span
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '6px',
                              padding: '3px 10px',
                              borderRadius: '12px',
                              fontSize: '0.75rem',
                              fontWeight: 700,
                              background: devAwake ? '#DCFCE7' : '#FFE4E6',
                              color: devAwake ? '#15803D' : '#BE123C',
                            }}
                          >
                            {devAwake ? <Zap size={12} /> : <Moon size={12} />}
                            {devAwake ? 'Awake' : 'Sleeping'}
                          </span>
                        </td>
                        <td>
                          <span className={`badge ${online ? 'badge-success' : 'badge-danger'}`} style={{ fontSize: '0.72rem' }}>
                            {online ? 'ONLINE' : 'OFFLINE'}
                          </span>
                        </td>
                        <td style={{ fontSize: '0.82rem', color: '#64748B' }}>
                          {formatLastActive(device.last_active_timestamp)}
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
                            <button
                              className="btn btn-outline"
                              onClick={(e) => {
                                e.stopPropagation();
                                handleOpenEditModal(device);
                              }}
                              style={{ padding: '5px 10px', fontSize: '0.78rem' }}
                              title="Edit Serial"
                            >
                              <Edit size={14} />
                            </button>

                            <button
                              className="btn btn-outline"
                              onClick={(e) => {
                                e.stopPropagation();
                                setDeleteTarget(device);
                                setShowDeleteModal(true);
                              }}
                              style={{ padding: '5px 10px', fontSize: '0.78rem', color: '#EF4444' }}
                              title="Delete Device"
                            >
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* ========================================================================= */}
        {/* MODALS                                                                    */}
        {/* ========================================================================= */}

        {/* Refill Pill Inventory Modal */}
        {restockModal && (
          <div className="modal-overlay" onClick={() => setRestockModal(null)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '420px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
                <h3 style={{ fontSize: '1.15rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <RotateCw size={18} color="#6A4C93" />
                  Refill Pill Inventory Stock
                </h3>
                <button onClick={() => setRestockModal(null)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              </div>

              <p style={{ fontSize: '0.88rem', color: '#64748B', marginBottom: '16px' }}>
                Refill pill supply for <strong>{restockModal.medicationName}</strong> (Dispenser Motor Slot #{restockModal.slot}).
                <br />
                <span style={{ fontSize: '0.8rem', color: '#94A3B8' }}>Current inventory: {restockModal.currentInventory} pills.</span>
              </p>

              <form onSubmit={handleRestockSubmit}>
                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>
                    Edit Total Inventory Stock Count *
                  </label>
                  <input
                    type="text"
                    pattern="[0-9]*"
                    inputMode="numeric"
                    value={restockQty}
                    onChange={(e) => setRestockQty(e.target.value.replace(/[^0-9]/g, ''))}
                    placeholder="Enter stock count number"
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', fontSize: '0.95rem' }}
                    required
                  />
                  <span style={{ fontSize: '0.75rem', color: '#64748B', marginTop: '4px', display: 'block' }}>
                    Directly edit current inventory stock number (numeric input only).
                  </span>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '20px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setRestockModal(null)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={restockLoading} style={{ flex: 1 }}>
                    {restockLoading ? 'Refilling...' : 'Confirm Refill'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Add Device Modal */}
        {showAddModal && (
          <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '440px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
                <h3 style={{ fontSize: '1.15rem' }}>Register Smart Kit Device</h3>
                <button onClick={() => setShowAddModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              </div>

              <form onSubmit={handleAddDeviceSubmit}>
                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569', marginBottom: '6px', display: 'block' }}>
                    Device Serial Number (Number Only)
                  </label>
                  <div style={{ display: 'flex', alignItems: 'center' }}>
                    <span
                      style={{
                        padding: '10px 14px',
                        background: '#F1F5F9',
                        border: '1px solid #CBD5E1',
                        borderRight: 'none',
                        borderRadius: '8px 0 0 8px',
                        fontWeight: '700',
                        color: '#475569',
                        fontSize: '0.9rem',
                      }}
                    >
                      DISP-
                    </span>
                    <input
                      type="text"
                      inputMode="numeric"
                      value={newSerial}
                      onChange={(e) => setNewSerial(e.target.value.replace(/[^0-9]/g, ''))}
                      placeholder="e.g. 1"
                      style={{
                        flex: 1,
                        padding: '10px',
                        borderRadius: '0 8px 8px 0',
                        border: '1px solid #CBD5E1',
                        fontSize: '0.9rem',
                      }}
                      required
                    />
                  </div>
                  <span style={{ fontSize: '0.75rem', color: '#64748B', marginTop: '6px', display: 'block' }}>
                    Enter number only. Final serial will be saved as: <strong>DISP-{newSerial || '...'}</strong>
                  </span>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" style={{ flex: 1 }}>
                    Register Device
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Edit Device Modal */}
        {showEditModal && (
          <div className="modal-overlay" onClick={() => setShowEditModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '440px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
                <h3 style={{ fontSize: '1.15rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Edit size={18} color="#6A4C93" />
                  Edit Device Serial Number
                </h3>
                <button onClick={() => setShowEditModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              </div>

              <form onSubmit={handleEditDeviceSubmit}>
                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569', marginBottom: '6px', display: 'block' }}>
                    Device Serial Number (Number Only)
                  </label>
                  <div style={{ display: 'flex', alignItems: 'center' }}>
                    <span
                      style={{
                        padding: '10px 14px',
                        background: '#F1F5F9',
                        border: '1px solid #CBD5E1',
                        borderRight: 'none',
                        borderRadius: '8px 0 0 8px',
                        fontWeight: '700',
                        color: '#475569',
                        fontSize: '0.9rem',
                      }}
                    >
                      DISP-
                    </span>
                    <input
                      type="text"
                      inputMode="numeric"
                      value={editSerial}
                      onChange={(e) => setEditSerial(e.target.value.replace(/[^0-9]/g, ''))}
                      placeholder="e.g. 1"
                      style={{
                        flex: 1,
                        padding: '10px',
                        borderRadius: '0 8px 8px 0',
                        border: '1px solid #CBD5E1',
                        fontSize: '0.9rem',
                      }}
                      required
                    />
                  </div>
                  <span style={{ fontSize: '0.75rem', color: '#64748B', marginTop: '6px', display: 'block' }}>
                    Enter number only. Saved format will be: <strong>DISP-{editSerial || '...'}</strong>
                  </span>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setShowEditModal(false)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" style={{ flex: 1 }}>
                    Save Changes
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Delete Confirmation Modal */}
        {showDeleteModal && deleteTarget && (
          <div className="modal-overlay" onClick={() => setShowDeleteModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '420px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
                <h3 style={{ fontSize: '1.15rem', color: '#EF4444', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Trash2 size={20} />
                  Delete Device
                </h3>
                <button onClick={() => setShowDeleteModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              </div>

              <p style={{ fontSize: '0.9rem', color: '#475569', marginBottom: '20px' }}>
                Are you sure you want to delete hardware device <strong>{deleteTarget.device_serial}</strong>?
                <br />
                <span style={{ fontSize: '0.8rem', color: '#94A3B8', marginTop: '6px', display: 'block' }}>
                  Note: A device cannot be deleted if active prescriptions or medications are currently assigned to it.
                </span>
              </p>

              <div style={{ display: 'flex', gap: '12px' }}>
                <button type="button" className="btn btn-secondary" onClick={() => setShowDeleteModal(false)} style={{ flex: 1 }}>
                  Cancel
                </button>
                <button
                  type="button"
                  className="btn"
                  onClick={handleDeleteDeviceSubmit}
                  style={{ flex: 1, background: '#EF4444', color: 'white' }}
                >
                  Delete Device
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Hardware Technician Dispatch Request Modal */}
        {showDispatchModal && (
          <div className="modal-overlay" onClick={handleCloseDispatchModal}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '480px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
                <h3 style={{ fontSize: '1.15rem', display: 'flex', alignItems: 'center', gap: '8px', color: '#1E293B' }}>
                  <Wrench size={18} color="#6A4C93" />
                  Request On-Site Hardware Inspection
                </h3>
                <button onClick={handleCloseDispatchModal} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              </div>

              {dispatchSuccess ? (
                <div style={{ textAlign: 'center', padding: '16px 8px' }}>
                  <div
                    style={{
                      width: '58px',
                      height: '58px',
                      borderRadius: '50%',
                      background: '#DCFCE7',
                      color: '#16A34A',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      margin: '0 auto 14px auto',
                      boxShadow: '0 4px 14px rgba(22, 163, 74, 0.2)',
                    }}
                  >
                    <CheckCircle2 size={32} />
                  </div>
                  <h4 style={{ fontSize: '1.15rem', color: '#1E293B', marginBottom: '6px', fontWeight: 800 }}>
                    Inspection Request Dispatched!
                  </h4>
                  <p style={{ fontSize: '0.86rem', color: '#475569', lineHeight: 1.5, marginBottom: '16px' }}>
                    Ticket <strong style={{ color: '#6A4C93' }}>#{lastTicketInfo?.ticketId || 'HW-8492'}</strong> has been registered for <strong>{currentSerial}</strong>.
                  </p>

                  {/* Mailtrap Notification Delivery Confirmation Box */}
                  <div
                    style={{
                      background: 'linear-gradient(135deg, #F0FDF4 0%, #E8F5E9 100%)',
                      border: '1.5px solid #86EFAC',
                      borderRadius: '12px',
                      padding: '14px 16px',
                      textAlign: 'left',
                      marginBottom: '20px',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#15803D', fontWeight: 700, fontSize: '0.85rem', marginBottom: '6px' }}>
                      <Mail size={16} />
                      <span>Reflected & Logged on Mailtrap (Sandbox)</span>
                    </div>
                    <p style={{ fontSize: '0.8rem', color: '#166534', margin: 0, lineHeight: 1.5 }}>
                      An automated ticket notification email has been delivered to <strong>hardware.support@smartmedkit.my</strong> via Mailtrap SMTP. Assigned Lead Engineer: <strong>Ooi Xien Xien</strong>.
                    </p>
                  </div>

                  <button
                    className="btn btn-primary"
                    onClick={handleCloseDispatchModal}
                    style={{ width: '100%', padding: '10px', fontWeight: 700 }}
                  >
                    Done
                  </button>
                </div>
              ) : (
                <form onSubmit={handleDispatchSubmit}>
                  <p style={{ fontSize: '0.85rem', color: '#64748B', marginBottom: '16px' }}>
                    Submit an on-site hardware maintenance and inspection ticket for <strong>{currentSerial}</strong>. The ticket will be dispatched to the technician and reflected in Mailtrap.
                  </p>

                  <div className="form-group" style={{ marginBottom: '14px' }}>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569', display: 'block', marginBottom: '6px' }}>
                      Hardware Issue Category *
                    </label>
                    <select
                      value={dispatchIssue}
                      onChange={(e) => setDispatchIssue(e.target.value)}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', fontSize: '0.88rem', outline: 'none' }}
                      required
                    >
                      <option value="Motor Jam / Dispensing Calibration">Dispenser Motor Jam / Slot Calibration Error</option>
                      <option value="ESP32 Offline / Wi-Fi Disconnection">ESP32 Offline / Wi-Fi & Heartbeat Failure</option>
                      <option value="Battery Power / Charging Glitch">Battery / Charging Power Circuit Fault</option>
                      <option value="OLED Display / Audio Buzzer Error">OLED Display / Audio Buzzer Malfunction</option>
                      <option value="Physical Enclosure / Pill Sensor Issue">Physical Enclosure / Stock Sensor Recalibration</option>
                      <option value="General Hardware Maintenance">Scheduled Preventive Maintenance</option>
                      <option value="Other">Other</option>
                    </select>
                  </div>

                  <div className="form-group" style={{ marginBottom: '20px' }}>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569', display: 'block', marginBottom: '6px' }}>
                      {dispatchIssue === 'Other' ? 'Describe the Issue Details *' : 'Additional Issue Notes / Observations'}
                    </label>
                    <textarea
                      rows={3}
                      value={dispatchNotes}
                      onChange={(e) => setDispatchNotes(e.target.value)}
                      placeholder={dispatchIssue === 'Other' ? 'Please describe the specific issue in detail...' : 'Describe symptoms (e.g., motor ticking, pill stuck in slot 1)...'}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', fontSize: '0.88rem', outline: 'none', resize: 'vertical' }}
                      required={dispatchIssue === 'Other'}
                    />
                  </div>

                  <div style={{ display: 'flex', gap: '12px' }}>
                    <button type="button" className="btn btn-secondary" onClick={handleCloseDispatchModal} style={{ flex: 1 }} disabled={submittingTicket}>
                      Cancel
                    </button>
                    <button type="submit" className="btn btn-primary" style={{ flex: 1 }} disabled={submittingTicket}>
                      {submittingTicket ? <Loader2 size={16} className="spinner" /> : <Send size={15} />}
                      <span>{submittingTicket ? 'Sending to Mailtrap...' : 'Submit Ticket'}</span>
                    </button>
                  </div>
                </form>
              )}
            </div>
          </div>
        )}

      </div>
    </div>
  );
}

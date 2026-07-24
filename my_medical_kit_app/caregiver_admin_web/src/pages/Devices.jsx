import React, { useState, useEffect } from 'react';
import { 
  Cpu, 
  Wifi, 
  Battery, 
  Lightbulb, 
  Volume2, 
  Monitor, 
  Play, 
  AlertCircle,
  CheckCircle2,
  Plus,
  X
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

export default function Devices({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();
  
  const [devices, setDevices] = useState([]);
  const [patients, setPatients] = useState([]);
  const [selectedDevice, setSelectedDevice] = useState(null);
  const [targetPatientId, setTargetPatientId] = useState(1);
  const [loading, setLoading] = useState(true);

  // Diagnostic Controls State
  const [displayMsg, setDisplayMsg] = useState('MEDKIT READY');
  const [controlLogs, setControlLogs] = useState([]);

  // Add Device Modal State
  const [showAddModal, setShowAddModal] = useState(false);
  const [newSerial, setNewSerial] = useState('ESP32-KIT-99');
  const [newIp, setNewIp] = useState('192.168.1.150');

  const addLog = (msg) => {
    setControlLogs((prev) => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev.slice(0, 15)]);
  };

  const fetchDevices = async () => {
    setLoading(true);
    try {
      const [devList, patList] = await Promise.all([
        apiService.getDevices(),
        apiService.getCaregiverPatients(caregiverId),
      ]);

      if (Array.isArray(devList)) {
        setDevices(devList);
        if (devList.length > 0 && !selectedDevice) {
          setSelectedDevice(devList[0]);
        }
      }
      if (Array.isArray(patList) && patList.length > 0) {
        setPatients(patList);
        setTargetPatientId(patList[0].id || patList[0].patient_id);
      }
    } catch (err) {
      console.error('Error fetching hardware devices:', err);
    } finally {
      setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  useEffect(() => {
    fetchDevices();
  }, [caregiverId]);

  useEffect(() => {
    if (isRefreshing) fetchDevices();
  }, [isRefreshing]);

  // LED Toggle
  const handleLedToggle = async (turnOn) => {
    addLog(`Sending LED command: ${turnOn ? 'ON' : 'OFF'} for Patient ID #${targetPatientId}...`);
    const ok = await apiService.controlLed(targetPatientId, turnOn);
    if (ok) {
      addLog(`SUCCESS: LED turned ${turnOn ? 'ON' : 'OFF'}.`);
    } else {
      addLog(`FAILED: Could not communicate with device LED.`);
    }
  };

  // Buzzer Toggle
  const handleBuzzerToggle = async (turnOn) => {
    addLog(`Sending Buzzer command: ${turnOn ? 'ON' : 'OFF'} for Patient ID #${targetPatientId}...`);
    const ok = await apiService.controlBuzzer(targetPatientId, turnOn);
    if (ok) {
      addLog(`SUCCESS: Buzzer turned ${turnOn ? 'ON' : 'OFF'}.`);
    } else {
      addLog(`FAILED: Could not communicate with device Buzzer.`);
    }
  };

  // Stepper Motor Test
  const handleStepperTest = async (motorNum) => {
    addLog(`Testing Stepper Motor #${motorNum} (90 deg spin) for Patient ID #${targetPatientId}...`);
    const ok = await apiService.controlStepper(targetPatientId, motorNum, '90');
    if (ok) {
      addLog(`SUCCESS: Stepper Motor #${motorNum} rotated 90 degrees.`);
    } else {
      addLog(`FAILED: Stepper Motor #${motorNum} command failed.`);
    }
  };

  // Display Text Command
  const handleDisplaySend = async (e) => {
    e.preventDefault();
    if (!displayMsg) return;
    addLog(`Sending OLED display text: "${displayMsg}" for Patient ID #${targetPatientId}...`);
    const ok = await apiService.controlDisplay(targetPatientId, displayMsg);
    if (ok) {
      addLog(`SUCCESS: Display updated.`);
    } else {
      addLog(`FAILED: Could not update OLED display.`);
    }
  };

  // Add Device
  const handleAddDeviceSubmit = async (e) => {
    e.preventDefault();
    const ok = await apiService.addDevice(newSerial, newIp, 100);
    if (ok) {
      setShowAddModal(false);
      fetchDevices();
    } else {
      alert('Failed to add device.');
    }
  };

  return (
    <div>
      {/* Top Banner */}
      <div className="glass-card" style={{ padding: '24px', marginBottom: '24px', background: 'white' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
          <div>
            <h2 style={{ fontSize: '1.25rem', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '10px' }}>
              <Cpu size={26} color="#6A4C93" />
              Smart Medical Kit Hardware Management
            </h2>
            <p style={{ fontSize: '0.88rem', color: '#6B7280', marginTop: '4px' }}>
              Monitor ESP32 smart dispensers, battery levels, IP endpoints & remote hardware diagnostic test triggers
            </p>
          </div>

          <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
            <Plus size={18} />
            <span>Register New Kit Device</span>
          </button>
        </div>
      </div>

      {/* Main Grid: Devices List & Diagnostic Remote Control */}
      <div className="dashboard-grid">
        {/* Hardware Devices List */}
        <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
          <div className="card-header">
            <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Wifi size={20} color="#6A4C93" />
              Active Hardware Dispensers
            </h3>
          </div>

          {loading ? (
            <p style={{ color: '#94A3B8', textAlign: 'center', padding: '20px' }}>Loading devices...</p>
          ) : devices.length === 0 ? (
            <div style={{ padding: '30px', textAlign: 'center', color: '#94A3B8' }}>
              No IoT Kit hardware devices registered yet.
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {devices.map((device) => {
                const isSelected = selectedDevice?.id === device.id;
                const batt = device.battery ?? 85;

                return (
                  <div
                    key={device.id || device.device_serial}
                    onClick={() => setSelectedDevice(device)}
                    style={{
                      padding: '16px',
                      borderRadius: '14px',
                      border: isSelected ? '2px solid #6A4C93' : '1px solid #E2E8F0',
                      background: isSelected ? '#F3E8FF' : '#F8FAFC',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      transition: 'all 0.2s ease',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                      <div style={{
                        width: '42px',
                        height: '42px',
                        borderRadius: '10px',
                        background: '#6A4C93',
                        color: 'white',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        <Cpu size={22} />
                      </div>

                      <div>
                        <div style={{ fontWeight: '700', color: '#2D3142', fontSize: '0.95rem' }}>
                          Serial: {device.device_serial || `KIT-SERIAL-${device.id}`}
                        </div>
                        <div style={{ fontSize: '0.78rem', color: '#64748B' }}>
                          IP: {device.last_known_ip || '192.168.1.102'} • Last active: Just now
                        </div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.8rem', color: batt < 20 ? '#EF4444' : '#10B981', fontWeight: '700' }}>
                        <Battery size={16} />
                        <span>{batt}%</span>
                      </div>
                      <span className="badge badge-success">ONLINE</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Diagnostic Remote Control Panel */}
        <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
          <div className="card-header">
            <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Play size={20} color="#6A4C93" />
              Remote Hardware Diagnostic Panel
            </h3>
          </div>

          <div style={{ marginBottom: '20px' }}>
            <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#2D3142', display: 'block', marginBottom: '6px' }}>
              Target Patient Device:
            </label>
            <select
              value={targetPatientId}
              onChange={(e) => setTargetPatientId(parseInt(e.target.value))}
              style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
            >
              {patients.map((p) => (
                <option key={p.id || p.patient_id} value={p.id || p.patient_id}>
                  {p.fullname || `Patient #${p.id}`} (Patient ID #{p.id || p.patient_id})
                </option>
              ))}
            </select>
          </div>

          {/* Diagnostic Controls */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginBottom: '20px' }}>
            {/* LED Control */}
            <div style={{ padding: '14px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
              <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Lightbulb size={18} color="#F59E0B" />
                Notification LED Light
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

            {/* Buzzer Alarm Control */}
            <div style={{ padding: '14px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
              <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Volume2 size={18} color="#EF4444" />
                Audio Buzzer Alarm
              </div>
              <div style={{ display: 'flex', gap: '10px' }}>
                <button className="btn btn-primary" style={{ flex: 1, padding: '8px' }} onClick={() => handleBuzzerToggle(true)}>
                  Sound Alarm
                </button>
                <button className="btn btn-secondary" style={{ flex: 1, padding: '8px' }} onClick={() => handleBuzzerToggle(false)}>
                  Silence Alarm
                </button>
              </div>
            </div>

            {/* Stepper Motor Rotation Test */}
            <div style={{ padding: '14px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
              <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Cpu size={18} color="#6A4C93" />
                Dispenser Stepper Motor Spin Test
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button className="btn btn-outline" style={{ flex: 1, padding: '6px', fontSize: '0.78rem' }} onClick={() => handleStepperTest(1)}>
                  Motor 1
                </button>
                <button className="btn btn-outline" style={{ flex: 1, padding: '6px', fontSize: '0.78rem' }} onClick={() => handleStepperTest(2)}>
                  Motor 2
                </button>
                <button className="btn btn-outline" style={{ flex: 1, padding: '6px', fontSize: '0.78rem' }} onClick={() => handleStepperTest(3)}>
                  Motor 3
                </button>
              </div>
            </div>

            {/* OLED Display Command */}
            <form onSubmit={handleDisplaySend} style={{ padding: '14px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
              <div style={{ fontWeight: '600', fontSize: '0.88rem', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Monitor size={18} color="#3B82F6" />
                OLED Screen Message Command
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <input
                  type="text"
                  value={displayMsg}
                  onChange={(e) => setDisplayMsg(e.target.value)}
                  placeholder="Enter screen message..."
                  style={{ flex: 1, padding: '8px', borderRadius: '8px', border: '1px solid #CBD5E1', fontSize: '0.85rem' }}
                />
                <button type="submit" className="btn btn-primary" style={{ padding: '8px 14px', fontSize: '0.82rem' }}>
                  Send
                </button>
              </div>
            </form>
          </div>

          {/* Diagnostic Log Output */}
          <div style={{ background: '#1E293B', color: '#38BDF8', padding: '12px', borderRadius: '10px', fontFamily: 'monospace', fontSize: '0.75rem', height: '140px', overflowY: 'auto' }}>
            {controlLogs.length === 0 ? (
              <span style={{ color: '#64748B' }}>Diagnostic hardware response log output...</span>
            ) : (
              controlLogs.map((log, i) => <div key={i}>{log}</div>)
            )}
          </div>
        </div>
      </div>

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
                <label>Device Serial Number</label>
                <input
                  type="text"
                  value={newSerial}
                  onChange={(e) => setNewSerial(e.target.value)}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  required
                />
              </div>

              <div className="form-group">
                <label>Last Known IP Address</label>
                <input
                  type="text"
                  value={newIp}
                  onChange={(e) => setNewIp(e.target.value)}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  required
                />
              </div>

              <div style={{ display: 'flex', gap: '12px', marginTop: '20px' }}>
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
    </div>
  );
}

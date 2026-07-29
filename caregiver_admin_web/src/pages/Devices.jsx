// Devices.jsx
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
  AlertTriangle,
  CheckCircle2,
  Plus,
  X,
  Loader2,
  Pill,
  RotateCw,
  PackageCheck,
  Edit,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

export default function Devices({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();

  const [devices, setDevices] = useState([]);
  const [patients, setPatients] = useState([]);
  const [selectedDevice, setSelectedDevice] = useState(null);
  const [targetPatientId, setTargetPatientId] = useState('');
  const [targetPrescriptions, setTargetPrescriptions] = useState([]);
  const [loading, setLoading] = useState(true);

  // Diagnostic Controls State
  const [displayMsg, setDisplayMsg] = useState('MEDKIT READY');
  const [controlLogs, setControlLogs] = useState([]);

  // Add Device Modal State
  const [showAddModal, setShowAddModal] = useState(false);
  const [newSerial, setNewSerial] = useState(''); // Initial empty numeric input

  // Edit Device Modal State
  const [showEditModal, setShowEditModal] = useState(false);
  const [editDeviceId, setEditDeviceId] = useState(null);
  const [editSerial, setEditSerial] = useState('');

  // Refill Stock Modal State
  const [restockModal, setRestockModal] = useState(null); // { prescriptionId, medicationName, slot, currentInventory }
  const [restockQty, setRestockQty] = useState('');
  const [restockLoading, setRestockLoading] = useState(false);

  const addLog = (msg) => {
    setControlLogs((prev) => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev.slice(0, 15)]);
  };

  const fetchDevicesAndPatients = async (showSpinner = true) => {
    if (showSpinner) setLoading(true);
    try {
      const [devList, patList] = await Promise.all([
        apiService.getDevices(),
        apiService.getCaregiverPatients(caregiverId),
      ]);

      if (Array.isArray(devList)) setDevices(devList);
      if (Array.isArray(patList)) {
        setPatients(patList);
        if (patList.length > 0 && !targetPatientId) {
          setTargetPatientId(patList[0].patient_id || patList[0].id);
        }
      }
    } catch (err) {
      console.error('Error loading devices data:', err);
    } finally {
      if (showSpinner) setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  const fetchTargetPrescriptions = async (pid) => {
    if (!pid) return;
    try {
      const list = await apiService.getPatientMedications(pid);
      setTargetPrescriptions(list || []);
    } catch (err) {
      setTargetPrescriptions([]);
    }
  };

  useEffect(() => {
    fetchDevicesAndPatients(true);
    const interval = setInterval(() => {
      fetchDevicesAndPatients(false); // Silent background auto-reload without spinner
      if (targetPatientId) fetchTargetPrescriptions(targetPatientId);
    }, 10000);
    return () => clearInterval(interval);
  }, [caregiverId, targetPatientId]);

  useEffect(() => {
    if (targetPatientId) {
      fetchTargetPrescriptions(targetPatientId);
    }
  }, [targetPatientId]);

  useEffect(() => {
    if (isRefreshing) {
      fetchDevicesAndPatients(true);
      if (targetPatientId) fetchTargetPrescriptions(targetPatientId);
    }
  }, [isRefreshing]);

  // LED Command
  const handleLedToggle = async (state) => {
    addLog(`Sending LED command (${state ? 'ON' : 'OFF'}) for Patient ID #${targetPatientId}...`);
    const ok = await apiService.controlLed(targetPatientId, state);
    if (ok) {
      addLog(`SUCCESS: LED indicator turned ${state ? 'ON' : 'OFF'}.`);
    } else {
      addLog(`FAILED: LED command execution failed.`);
    }
  };

  // Buzzer Command
  const handleBuzzerToggle = async (state) => {
    addLog(`Sending Buzzer command (${state ? 'ON' : 'OFF'}) for Patient ID #${targetPatientId}...`);
    const ok = await apiService.controlBuzzer(targetPatientId, state);
    if (ok) {
      addLog(`SUCCESS: Audio Buzzer alarm ${state ? 'activated' : 'silenced'}.`);
    } else {
      addLog(`FAILED: Buzzer command failed.`);
    }
  };

  // Stepper Motor Test
  const handleStepperTest = async (motorNum, action = '90') => {
    const actionDesc = action === 'forward' ? '360° Forward' : action === 'backward' ? '360° Backward' : `${action}°`;
    addLog(`Triggering Stepper Motor #${motorNum} test (${actionDesc})...`);
    const ok = await apiService.controlStepper(targetPatientId, motorNum, action);
    if (ok) {
      addLog(`SUCCESS: Stepper Motor #${motorNum} rotated ${actionDesc}.`);
    } else {
      addLog(`FAILED: Stepper Motor #${motorNum} (${actionDesc}) command failed.`);
    }
  };

  // Display Text Command
  const handleDisplaySend = async (e, customMsg = null) => {
    if (e && e.preventDefault) e.preventDefault();
    const msgToSend = customMsg !== null ? customMsg : displayMsg;
    if (!msgToSend) return;
    addLog(`Sending OLED display text: "${msgToSend}" for Patient ID #${targetPatientId}...`);
    const ok = await apiService.controlDisplay(targetPatientId, msgToSend);
    if (ok) {
      addLog(`SUCCESS: Display updated with "${msgToSend}".`);
    } else {
      addLog(`FAILED: Could not update OLED display.`);
    }
  };

  // Restock Pill Inventory
  const handleRestockSubmit = async (e) => {
    e.preventDefault();
    if (!restockModal) return;

    const qty = parseInt(restockQty, 10);
    if (isNaN(qty) || qty < 0) {
      alert('Please enter a valid numeric inventory stock number.');
      return;
    }

    setRestockLoading(true);
    try {
      const success = await apiService.restockMedication(restockModal.prescriptionId, qty, true);
      if (success) {
        addLog(`SUCCESS: Updated inventory stock to ${qty} pills for Slot #${restockModal.slot} (${restockModal.medicationName}).`);
        setRestockModal(null);
        setRestockQty('');
        fetchTargetPrescriptions(targetPatientId);
      } else {
        alert('Failed to update stock. Please check backend connection.');
      }
    } catch (err) {
      console.error(err);
      alert('Error updating stock.');
    } finally {
      setRestockLoading(false);
    }
  };

  // Add Device
  const handleAddDeviceSubmit = async (e) => {
    e.preventDefault();
    const cleanNum = newSerial.replace(/[^0-9]/g, '');
    if (!cleanNum) {
      alert('Please enter a valid numeric device serial number.');
      return;
    }
    const fullSerial = `DISP-${cleanNum}`;
    const ok = await apiService.addDevice(fullSerial, '', 100);
    if (ok) {
      setShowAddModal(false);
      setNewSerial('');
      fetchDevicesAndPatients();
    } else {
      alert('Failed to add device.');
    }
  };

  // Edit Device
  const handleOpenEditModal = (device) => {
    setEditDeviceId(device.id || device.device_id);
    const existingNum = (device.device_serial || '').replace(/[^0-9]/g, '');
    setEditSerial(existingNum);
    setShowEditModal(true);
  };

  const handleEditDeviceSubmit = async (e) => {
    e.preventDefault();
    const cleanNum = editSerial.replace(/[^0-9]/g, '');
    if (!cleanNum) {
      alert('Please enter a valid numeric device serial number.');
      return;
    }
    const fullSerial = `DISP-${cleanNum}`;
    const ok = await apiService.updateDevice(editDeviceId, fullSerial);
    if (ok) {
      setShowEditModal(false);
      setEditDeviceId(null);
      setEditSerial('');
      fetchDevicesAndPatients();
    } else {
      alert('Failed to update device serial.');
    }
  };

  const showSpinner = loading || isRefreshing;

  return (
    <div style={{ position: 'relative', minHeight: '400px' }}>
      {/* Spinner overlay – shows during initial load or refresh */}
      {showSpinner && (
        <div className="loading-overlay">
          <Loader2 className="spinner" size={48} color="#6A4C93" />
          <p style={{ marginTop: '12px', color: '#6B7280', fontWeight: 500 }}>
            {loading ? 'Loading smart kit devices...' : 'Refreshing...'}
          </p>
        </div>
      )}

      {/* Main content – dimmed when spinner is visible */}
      <div style={{ opacity: showSpinner ? 0.4 : 1, transition: 'opacity 0.2s' }}>
        {/* Top Banner */}
        <div className="glass-card" style={{ padding: '24px', marginBottom: '24px', background: 'white' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
            <div>
              <h2 style={{ fontSize: '1.25rem', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Cpu size={26} color="#6A4C93" />
                Smart Medical Kit Hardware & Stock Management
              </h2>
              <p style={{ fontSize: '0.88rem', color: '#6B7280', marginTop: '4px' }}>
                Monitor ESP32 smart dispensers, refill pill inventory stock & run remote diagnostic tests
              </p>
            </div>

            <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
              <Plus size={18} />
              <span>Register New Kit Device</span>
            </button>
          </div>
        </div>

        {/* Refill Pill Inventory Stock Section */}
        <div className="glass-card" style={{ padding: '24px', marginBottom: '24px', background: 'white' }}>
          <div className="card-header">
            <div>
              <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Pill size={20} color="#6A4C93" />
                Dispenser Pill Stock Inventory & Hardware Refill
              </h3>
              <p style={{ fontSize: '0.8rem', color: '#6B7280' }}>
                Refill pill supply for motor slots assigned to the target patient dispenser
              </p>
            </div>
          </div>

          {targetPrescriptions.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '30px', color: '#94A3B8' }}>
              <PackageCheck size={40} style={{ margin: '0 auto 10px auto', display: 'block' }} />
              No active prescriptions or motor slots configured for this patient.
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px' }}>
              {targetPrescriptions.map((pres) => {
                const stock = pres.current_inventory ?? pres.inventory ?? 0;
                const threshold = pres.refill_threshold ?? 5;
                const isOutOfStock = stock <= 0;
                const isLow = stock > 0 && stock <= threshold;

                const statusBg = isOutOfStock ? '#FEF2F2' : isLow ? '#FFFBEB' : '#F8FAFC';
                const statusBorder = isOutOfStock ? '#FCA5A5' : isLow ? '#FDE68A' : '#E2E8F0';
                const iconBg = isOutOfStock ? '#EF4444' : isLow ? '#F59E0B' : '#6A4C93';
                const textCol = isOutOfStock ? '#DC2626' : isLow ? '#B45309' : '#10B981';

                return (
                  <div
                    key={pres.id || pres.prescription_id}
                    style={{
                      border: `1px solid ${statusBorder}`,
                      borderRadius: '14px',
                      padding: '18px',
                      background: statusBg,
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      position: 'relative',
                    }}
                  >
                    {isOutOfStock && (
                      <div style={{
                        position: 'absolute',
                        top: '10px',
                        right: '10px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px',
                        padding: '3px 8px',
                        background: '#FEE2E2',
                        color: '#991B1B',
                        borderRadius: '10px',
                        fontSize: '0.72rem',
                        fontWeight: '700'
                      }}>
                        <AlertCircle size={13} />
                        Out of Stock
                      </div>
                    )}

                    {!isOutOfStock && isLow && (
                      <div style={{
                        position: 'absolute',
                        top: '10px',
                        right: '10px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px',
                        padding: '3px 8px',
                        background: '#FEF3C7',
                        color: '#B45309',
                        borderRadius: '10px',
                        fontSize: '0.72rem',
                        fontWeight: '700'
                      }}>
                        <AlertTriangle size={13} />
                        Low Stock
                      </div>
                    )}

                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
                        <div style={{
                          width: '38px',
                          height: '38px',
                          borderRadius: '10px',
                          background: iconBg,
                          color: 'white',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          flexShrink: 0
                        }}>
                          <Pill size={20} />
                        </div>
                        <div>
                          <div style={{ fontWeight: '700', color: '#2D3142', fontSize: '0.95rem' }}>
                            {pres.medication_name || pres.name || 'Medication'}
                          </div>
                          <span className="badge badge-purple" style={{ fontSize: '0.7rem' }}>
                            Motor Slot #{pres.motor_slot || 1}
                          </span>
                        </div>
                      </div>

                      {/* Stock Indicator Bar */}
                      <div style={{ marginBottom: '14px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', marginBottom: '4px' }}>
                          <span style={{ color: '#64748B' }}>Pill Count:</span>
                          <strong style={{ color: textCol }}>
                            {isOutOfStock ? '0 pills (Out of Stock)' : `${stock} pills remaining`}
                          </strong>
                        </div>
                        <div style={{ width: '100%', height: '8px', background: '#E2E8F0', borderRadius: '4px', overflow: 'hidden' }}>
                          <div style={{
                            width: isOutOfStock ? '0%' : `${Math.min((stock / 30) * 100, 100)}%`,
                            height: '100%',
                            background: iconBg,
                            borderRadius: '4px',
                            transition: 'width 0.3s ease'
                          }} />
                        </div>
                      </div>
                    </div>

                    <button
                      className="btn btn-outline"
                      onClick={() => {
                        setRestockQty(String(stock ?? 0));
                        setRestockModal({
                          prescriptionId: pres.id || pres.prescription_id,
                          medicationName: pres.medication_name || pres.name || 'Medication',
                          slot: pres.motor_slot || 1,
                          currentInventory: stock,
                        });
                      }}
                      style={{ width: '100%', padding: '8px', fontSize: '0.82rem', background: 'white' }}
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
                        <button
                          className="btn btn-outline"
                          title="Edit Device Serial Number"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleOpenEditModal(device);
                          }}
                          style={{
                            padding: '6px 10px',
                            fontSize: '0.78rem',
                            background: 'white',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '4px',
                            borderRadius: '8px'
                          }}
                        >
                          <Edit size={14} />
                          <span>Edit</span>
                        </button>
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
                  Dispenser Stepper Motor Rotation Controls
                </div>

                {[1, 2, 3].map((mNum) => (
                  <div key={mNum} style={{ marginBottom: mNum < 3 ? '12px' : '0', paddingBottom: mNum < 3 ? '10px' : '0', borderBottom: mNum < 3 ? '1px dashed #CBD5E1' : 'none' }}>
                    <div style={{ fontSize: '0.78rem', fontWeight: '700', color: '#475569', marginBottom: '6px' }}>
                      Motor #{mNum} (Slot {mNum})
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: '6px' }}>
                      <button className="btn btn-outline" style={{ padding: '6px 4px', fontSize: '0.72rem', background: 'white' }} onClick={() => handleStepperTest(mNum, 'forward')}>
                        Forward 360°
                      </button>
                      <button className="btn btn-outline" style={{ padding: '6px 4px', fontSize: '0.72rem', background: 'white' }} onClick={() => handleStepperTest(mNum, 'backward')}>
                        Backward 360°
                      </button>
                      <button className="btn btn-outline" style={{ padding: '6px 4px', fontSize: '0.72rem', background: 'white' }} onClick={() => handleStepperTest(mNum, '180')}>
                        Spin 180°
                      </button>
                      <button className="btn btn-outline" style={{ padding: '6px 4px', fontSize: '0.72rem', background: 'white' }} onClick={() => handleStepperTest(mNum, '90')}>
                        Spin 90°
                      </button>
                    </div>
                  </div>
                ))}
              </div>

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
                Refill pill stock for <strong>{restockModal.medicationName}</strong> (Dispenser Motor Slot #{restockModal.slot}).
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
                    <span style={{
                      padding: '10px 14px',
                      background: '#F1F5F9',
                      border: '1px solid #CBD5E1',
                      borderRight: 'none',
                      borderRadius: '8px 0 0 8px',
                      fontWeight: '700',
                      color: '#475569',
                      fontSize: '0.9rem'
                    }}>
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
                        fontSize: '0.9rem'
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
                    <span style={{
                      padding: '10px 14px',
                      background: '#F1F5F9',
                      border: '1px solid #CBD5E1',
                      borderRight: 'none',
                      borderRadius: '8px 0 0 8px',
                      fontWeight: '700',
                      color: '#475569',
                      fontSize: '0.9rem'
                    }}>
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
                        fontSize: '0.9rem'
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
      </div>
    </div>
  );
}

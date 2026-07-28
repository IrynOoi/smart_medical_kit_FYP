// Prescriptions.jsx
import React, { useState, useEffect } from 'react';
import {
  Pill,
  Plus,
  Edit,
  Trash2,
  AlertTriangle,
  X,
  Clock,
  Calendar,
  CheckCircle2,
  PackageCheck,
  Loader2,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

const DAYS_OF_WEEK = [
  { id: 1, label: 'Mon' },
  { id: 2, label: 'Tue' },
  { id: 3, label: 'Wed' },
  { id: 4, label: 'Thu' },
  { id: 5, label: 'Fri' },
  { id: 6, label: 'Sat' },
  { id: 7, label: 'Sun' },
];

// Helper to format day numbers array to readable string
const formatDispenseDays = (days) => {
  if (!days || days.length === 0 || days.length === 7) return 'Everyday';
  const dayMap = { 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun' };
  const sorted = [...days].sort((a, b) => a - b);
  return sorted.map((d) => dayMap[d]).join(', ');
};

// Helper to format time string "08:00:00" or "20:00:00" to "8:00 AM" / "8:00 PM"
const formatTimeAMPM = (timeStr) => {
  if (!timeStr) return '';
  try {
    const parts = String(timeStr).split(':');
    let hour = parseInt(parts[0], 10);
    const minute = parts[1] ? String(parts[1]).padStart(2, '0') : '00';
    if (isNaN(hour)) return timeStr;
    const ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    hour = hour ? hour : 12; // convert 0 to 12
    return `${hour}:${minute} ${ampm}`;
  } catch (e) {
    return timeStr;
  }
};

// Helper to format time string like "8:00:00", "8:00", or "08:00:00" to valid HTML5 time input format "08:00"
const formatTime24HHMM = (timeStr) => {
  if (!timeStr) return '08:00';
  try {
    const parts = String(timeStr).split(':');
    if (parts.length < 2) return '08:00';
    let hour = parseInt(parts[0], 10);
    let minute = parseInt(parts[1], 10);
    if (isNaN(hour)) hour = 8;
    if (isNaN(minute)) minute = 0;
    const hh = String(hour).padStart(2, '0');
    const mm = String(minute).padStart(2, '0');
    return `${hh}:${mm}`;
  } catch (e) {
    return '08:00';
  }
};

export default function Prescriptions({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();

  const [patients, setPatients] = useState([]);
  const [selectedPatientId, setSelectedPatientId] = useState('');
  const [prescriptions, setPrescriptions] = useState([]);
  const [medCatalog, setMedCatalog] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingPrescriptions, setLoadingPrescriptions] = useState(false);

  // Add Prescription Modal state
  const [showAddModal, setShowAddModal] = useState(false);
  const [newPrescription, setNewPrescription] = useState({
    patient_id: '',
    medication_id: '',
    medication_name: '',
    dosage: '1.0',
    dispense_times: ['08:00'],
    dispense_days: [], // empty = Everyday
    start_date: new Date().toISOString().split('T')[0],
    end_date: '',
  });

  // Edit Prescription Modal state
  const [editingPrescription, setEditingPrescription] = useState(null);
  const [editForm, setEditForm] = useState({
    medication_name: '',
    medication_id: '',
    dosage: '1.0',
    dispense_times: ['08:00'],
    dispense_days: [],
    start_date: '',
    end_date: '',
  });

  const [formError, setFormError] = useState('');
  const [formLoading, setFormLoading] = useState(false);
  const [actionSuccessMsg, setActionSuccessMsg] = useState('');

  const loadData = async () => {
    setLoading(true);
    try {
      const [patientsData, catalogData] = await Promise.all([
        apiService.getCaregiverPatients(caregiverId),
        apiService.getMedicationsCatalog(),
      ]);

      if (Array.isArray(patientsData)) {
        setPatients(patientsData);
        if (patientsData.length > 0 && !selectedPatientId) {
          setSelectedPatientId(patientsData[0].patient_id || patientsData[0].id);
        }
      }
      if (Array.isArray(catalogData)) {
        setMedCatalog(catalogData);
      }
    } catch (err) {
      console.error('Error loading prescriptions data:', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchPrescriptions = async (pid) => {
    if (!pid) return;
    setLoadingPrescriptions(true);
    try {
      const list = await apiService.getPatientMedications(pid);
      setPrescriptions(list || []);
    } catch (err) {
      setPrescriptions([]);
    } finally {
      setLoadingPrescriptions(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [caregiverId]);

  useEffect(() => {
    if (selectedPatientId) {
      fetchPrescriptions(selectedPatientId);
    }
  }, [selectedPatientId]);

  useEffect(() => {
    if (isRefreshing) {
      loadData();
      if (selectedPatientId) fetchPrescriptions(selectedPatientId);
      if (onRefreshComplete) onRefreshComplete();
    }
  }, [isRefreshing]);

  // Open Edit Modal
  const handleOpenEdit = (pres) => {
    setEditingPrescription(pres);

    // Format dispense times array safely to 24h HH:mm format for HTML time input
    let rawTimes = pres.dispense_times && pres.dispense_times.length > 0
      ? pres.dispense_times
      : (pres.scheduled_time ? [pres.scheduled_time] : ['08:00']);

    let times = rawTimes.map((t) => formatTime24HHMM(t));

    const medId = pres.medication_id || '';
    const medName = pres.medication_name || pres.name || '';

    setEditForm({
      medication_name: medName,
      medication_id: medId,
      dosage: pres.dosage ? String(pres.dosage).replace(/[^0-9.]/g, '') : (pres.dosage_tablet ? String(pres.dosage_tablet) : '1.0'),
      dispense_times: times,
      dispense_days: Array.isArray(pres.dispense_days) ? pres.dispense_days : [],
      start_date: pres.start_date ? pres.start_date.substring(0, 10) : new Date().toISOString().split('T')[0],
      end_date: pres.end_date ? pres.end_date.substring(0, 10) : '',
    });
    setFormError('');
  };

  // Submit Add Prescription Form
  const handleAddPrescriptionSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setFormLoading(true);

    try {
      const pid = newPrescription.patient_id || selectedPatientId;
      const selectedMed = medCatalog.find((m) => String(m.medication_id || m.id) === String(newPrescription.medication_id));
      const medName = selectedMed ? (selectedMed.medication_name || selectedMed.name) : (newPrescription.medication_name || 'Medication');

      // Date validation
      if (newPrescription.end_date && newPrescription.end_date < newPrescription.start_date) {
        setFormError('End date cannot be earlier than start date.');
        setFormLoading(false);
        return;
      }

      const res = await apiService.addPrescription({
        patient_id: parseInt(pid),
        medication_id: parseInt(newPrescription.medication_id) || (medCatalog[0]?.medication_id || medCatalog[0]?.id || 1),
        medication_name: medName,
        dosage: `${newPrescription.dosage} tablet(s)`,
        dosage_tablet: parseFloat(newPrescription.dosage) || 1.0,
        dispense_times: newPrescription.dispense_times,
        dispense_days: newPrescription.dispense_days.length > 0 ? newPrescription.dispense_days : [1, 2, 3, 4, 5, 6, 7],
        start_date: newPrescription.start_date,
        end_date: newPrescription.end_date || null,
        current_inventory: 30,
        refill_threshold: 5,
      });

      if (res && (res.success || res.message)) {
        setShowAddModal(false);
        setActionSuccessMsg('Prescription added successfully!');
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchPrescriptions(selectedPatientId);
      } else {
        setFormError(res?.message || res?.error || 'Failed to add prescription.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred.');
    } finally {
      setFormLoading(false);
    }
  };

  // Submit Edit Prescription Form
  const handleEditPrescriptionSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setFormLoading(true);

    try {
      const presId = editingPrescription.id || editingPrescription.prescription_id;
      const selectedMed = medCatalog.find((m) => String(m.medication_id || m.id) === String(editForm.medication_id));
      const medName = selectedMed ? (selectedMed.medication_name || selectedMed.name) : (editForm.medication_name || editingPrescription.medication_name || 'Medication');

      // Date validation
      if (editForm.end_date && editForm.end_date < editForm.start_date) {
        setFormError('End date cannot be earlier than start date.');
        setFormLoading(false);
        return;
      }

      const payload = {
        medication_name: medName,
        medication_id: editForm.medication_id ? parseInt(editForm.medication_id) : undefined,
        dosage: `${editForm.dosage} tablet(s)`,
        dosage_tablet: parseFloat(editForm.dosage) || 1.0,
        dispense_times: editForm.dispense_times,
        dispense_days: editForm.dispense_days.length > 0 ? editForm.dispense_days : [1, 2, 3, 4, 5, 6, 7],
        start_date: editForm.start_date,
        end_date: editForm.end_date || null,
      };

      const success = await apiService.updatePrescription(presId, payload);
      if (success) {
        setEditingPrescription(null);
        setActionSuccessMsg('Prescription updated successfully!');
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchPrescriptions(selectedPatientId);
      } else {
        setFormError('Failed to update prescription. Check backend logs.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred while updating.');
    } finally {
      setFormLoading(false);
    }
  };

  // Delete Prescription
  const handleDeletePrescription = async (pres) => {
    const presId = pres.id || pres.prescription_id;
    const name = pres.medication_name || pres.name || 'this prescription';

    if (window.confirm(`Are you sure you want to delete the prescription for "${name}"?`)) {
      const success = await apiService.deletePrescription(presId);
      if (success) {
        setActionSuccessMsg(`Prescription "${name}" deleted.`);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchPrescriptions(selectedPatientId);
      } else {
        alert('Failed to delete prescription.');
      }
    }
  };

  const showSpinner = loading || isRefreshing || loadingPrescriptions;

  return (
    <div style={{ position: 'relative', minHeight: '400px' }}>
      {/* Spinner overlay */}
      {showSpinner && (
        <div className="loading-overlay">
          <Loader2 className="spinner" size={48} color="#6A4C93" />
          <p style={{ marginTop: '12px', color: '#6B7280', fontWeight: 500 }}>
            {loadingPrescriptions
              ? 'Loading patient prescriptions...'
              : loading
              ? 'Loading prescription schedule...'
              : 'Refreshing...'}
          </p>
        </div>
      )}

      {/* Main content */}
      <div style={{ opacity: showSpinner ? 0.4 : 1, transition: 'opacity 0.2s' }}>
        {/* Success Notification Banner */}
        {actionSuccessMsg && (
          <div style={{
            padding: '14px 20px',
            background: '#D1FAE5',
            border: '1px solid #10B981',
            borderRadius: '12px',
            color: '#065F46',
            fontWeight: '600',
            fontSize: '0.9rem',
            marginBottom: '20px',
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
          }}>
            <CheckCircle2 size={20} color="#10B981" />
            <span>{actionSuccessMsg}</span>
          </div>
        )}

        {/* Patient Selector & Action Bar */}
        <div className="glass-card" style={{ padding: '20px', marginBottom: '24px', background: 'white' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <label style={{ fontSize: '0.9rem', fontWeight: '600', color: '#2D3142' }}>
                Select Patient:
              </label>
              <select
                value={selectedPatientId}
                onChange={(e) => setSelectedPatientId(e.target.value)}
                style={{
                  padding: '8px 16px',
                  borderRadius: '10px',
                  border: '1px solid #CBD5E1',
                  fontSize: '0.9rem',
                  fontWeight: '600',
                  outline: 'none',
                  background: '#F8FAFC',
                  minWidth: '180px',
                }}
                disabled={loading || patients.length === 0}
              >
                {loading ? (
                  <option value="" disabled>Loading patients...</option>
                ) : patients.length === 0 ? (
                  <option value="" disabled>No patients available</option>
                ) : (
                  patients.map((p) => {
                    const id = p.patient_id || p.id;
                    const name = p.fullname || p.full_name || p.name || `Patient #${id}`;
                    return (
                      <option key={id} value={id}>
                        {name}
                      </option>
                    );
                  })
                )}
              </select>
            </div>

            <button
              className="btn btn-primary"
              onClick={() => {
                const todayStr = new Date().toISOString().split('T')[0];
                const firstMedId = medCatalog[0]?.medication_id || medCatalog[0]?.id || '';
                const firstMedName = medCatalog[0]?.medication_name || medCatalog[0]?.name || '';
                setNewPrescription({
                  patient_id: selectedPatientId,
                  medication_id: firstMedId,
                  medication_name: firstMedName,
                  dosage: '1.0',
                  dispense_times: ['08:00'],
                  dispense_days: [],
                  start_date: todayStr,
                  end_date: '',
                });
                setFormError('');
                setShowAddModal(true);
              }}
              disabled={!selectedPatientId || loading}
            >
              <Plus size={18} />
              <span>Add New Prescription</span>
            </button>
          </div>
        </div>

        {/* Prescriptions Schedule List */}
        <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
          <div className="card-header">
            <div>
              <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Pill size={20} color="#6A4C93" />
                Medication Schedule & Prescriptions
              </h3>
              <p style={{ fontSize: '0.8rem', color: '#6B7280' }}>
                Configure prescription timings and dosages for patients
              </p>
            </div>
          </div>

          {prescriptions.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#94A3B8' }}>
              <PackageCheck size={48} style={{ margin: '0 auto 12px auto', display: 'block' }} />
              No prescriptions found for the selected patient. Click "Add New Prescription" above.
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '20px' }}>
              {prescriptions.map((pres) => {
                const presId = pres.id || pres.prescription_id;
                const timesList = pres.dispense_times && pres.dispense_times.length > 0
                  ? pres.dispense_times
                  : (pres.scheduled_time ? [pres.scheduled_time] : ['08:00']);

                return (
                  <div
                    key={presId}
                    style={{
                      border: '1px solid #E2E8F0',
                      borderRadius: '16px',
                      padding: '20px',
                      background: '#F8FAFC',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      position: 'relative',
                    }}
                  >
                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '14px' }}>
                        <div style={{
                          width: '44px',
                          height: '44px',
                          borderRadius: '12px',
                          background: '#6A4C93',
                          color: 'white',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          <Pill size={22} />
                        </div>
                        <div>
                          <h4 style={{ fontSize: '1.05rem', color: '#2D3142', fontWeight: '700' }}>
                            {pres.medication_name || pres.name || 'Prescription Name'}
                          </h4>
                          <span className="badge badge-purple" style={{ fontSize: '0.72rem' }}>
                            Active Prescription
                          </span>
                        </div>
                      </div>

                      <div style={{ fontSize: '0.85rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '16px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span style={{ color: '#64748B' }}>Dosage (Tablets):</span>
                          <strong>{pres.dosage_tablet ? `${pres.dosage_tablet} pill(s)` : (pres.dosage || '1.0 pill')}</strong>
                        </div>
                        
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                          <span style={{ color: '#64748B' }}>Dispense Times ({timesList.length}):</span>
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                            {timesList.map((t, idx) => (
                              <span key={idx} style={{
                                padding: '4px 10px',
                                background: '#F3E8FF',
                                color: '#6A4C93',
                                borderRadius: '8px',
                                fontWeight: '700',
                                fontSize: '0.78rem',
                                display: 'flex',
                                alignItems: 'center',
                                gap: '4px'
                              }}>
                                <Clock size={12} />
                                {formatTimeAMPM(t)}
                              </span>
                            ))}
                          </div>
                        </div>

                        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '4px' }}>
                          <span style={{ color: '#64748B' }}>Days of Week:</span>
                          <strong style={{ color: '#2D3142' }}>{formatDispenseDays(pres.dispense_days)}</strong>
                        </div>

                        <div style={{ display: 'flex', justifyContent: 'space-between', paddingTop: '8px', borderTop: '1px solid #E2E8F0' }}>
                          <span style={{ color: '#64748B' }}>Start Date:</span>
                          <span>{pres.start_date ? pres.start_date.substring(0, 10) : 'N/A'}</span>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span style={{ color: '#64748B' }}>End Date:</span>
                          <span>{pres.end_date ? pres.end_date.substring(0, 10) : 'No end date'}</span>
                        </div>
                      </div>
                    </div>

                    {/* Prescription Action Buttons: Edit & Delete */}
                    <div style={{ display: 'flex', gap: '8px', paddingTop: '14px', borderTop: '1px solid #E2E8F0' }}>
                      <button
                        className="btn"
                        style={{ flex: 1, padding: '7px', fontSize: '0.82rem', background: '#F1F5F9', color: '#334155', border: '1px solid #CBD5E1' }}
                        onClick={() => handleOpenEdit(pres)}
                        title="Edit Prescription Details"
                      >
                        <Edit size={15} />
                        <span>Edit</span>
                      </button>

                      <button
                        className="btn btn-secondary"
                        style={{ padding: '7px 12px', color: '#EF4444', background: '#FEE2E2', border: '1px solid #FCA5A5' }}
                        onClick={() => handleDeletePrescription(pres)}
                        title="Delete Prescription"
                      >
                        <Trash2 size={15} />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Add Prescription Modal */}
        {showAddModal && (
          <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '520px', maxHeight: '90vh', overflowY: 'auto' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142', fontWeight: '700' }}>Add New Prescription</h3>
                <button onClick={() => setShowAddModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}>
                  <X size={20} />
                </button>
              </div>

              {formError && (
                <div style={{ padding: '10px', background: '#FEE2E2', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                  {formError}
                </div>
              )}

              <form onSubmit={handleAddPrescriptionSubmit}>
                {/* Select Patient */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Target Patient *</label>
                  <select
                    value={newPrescription.patient_id || selectedPatientId}
                    onChange={(e) => setNewPrescription({ ...newPrescription, patient_id: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                    required
                  >
                    {patients.map((p) => {
                      const id = p.patient_id || p.id;
                      const name = p.fullname || p.full_name || p.name || `Patient #${id}`;
                      return (
                        <option key={id} value={id}>
                          {name}
                        </option>
                      );
                    })}
                  </select>
                </div>

                {/* Select Medication (Fixed: Extracts medication_name & medication_id correctly) */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Select Medication *</label>
                  <select
                    value={newPrescription.medication_id}
                    onChange={(e) => {
                      const mId = e.target.value;
                      const selected = medCatalog.find((m) => String(m.medication_id || m.id) === String(mId));
                      setNewPrescription({
                        ...newPrescription,
                        medication_id: mId,
                        medication_name: selected ? (selected.medication_name || selected.name) : '',
                      });
                    }}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                    required
                  >
                    <option value="">-- Choose Medication --</option>
                    {medCatalog.map((m) => {
                      const id = m.medication_id || m.id;
                      const name = m.medication_name || m.name || `Medication #${id}`;
                      return (
                        <option key={id} value={id}>
                          💊 {name} ({m.dosage_form || 'Tablet'})
                        </option>
                      );
                    })}
                  </select>
                </div>

                {/* Dosage (Tablets) - Dispenser Motor removed as requested */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Dosage (Tablets) *</label>
                  <input
                    type="number"
                    step="0.5"
                    min="0.5"
                    placeholder="1.0"
                    value={newPrescription.dosage}
                    onChange={(e) => setNewPrescription({ ...newPrescription, dosage: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    required
                  />
                </div>

                {/* Dispense Times Section (Multiple Times) */}
                <div className="form-group" style={{ marginBottom: '18px' }}>
                  <label style={{ fontWeight: '700', fontSize: '0.9rem', color: '#2D3142', display: 'block', marginBottom: '4px' }}>
                    Dispense Times
                  </label>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '8px' }}>
                    {newPrescription.dispense_times.map((tVal, idx) => (
                      <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{
                          flex: 1,
                          display: 'flex',
                          alignItems: 'center',
                          gap: '10px',
                          background: '#F8FAFC',
                          padding: '8px 12px',
                          borderRadius: '10px',
                          border: '1px solid #E2E8F0'
                        }}>
                          <Clock size={16} color="#6A4C93" />
                          <input
                            type="time"
                            value={tVal}
                            onChange={(e) => {
                              const updated = [...newPrescription.dispense_times];
                              updated[idx] = e.target.value;
                              setNewPrescription({ ...newPrescription, dispense_times: updated });
                            }}
                            style={{ border: 'none', background: 'transparent', outline: 'none', fontSize: '0.95rem', fontWeight: '600', color: '#6A4C93' }}
                            required
                          />
                        </div>
                        {newPrescription.dispense_times.length > 1 && (
                          <button
                            type="button"
                            onClick={() => {
                              const updated = newPrescription.dispense_times.filter((_, i) => i !== idx);
                              setNewPrescription({ ...newPrescription, dispense_times: updated });
                            }}
                            style={{ background: '#FEE2E2', border: 'none', color: '#EF4444', padding: '8px', borderRadius: '8px', cursor: 'pointer' }}
                            title="Remove time"
                          >
                            <Trash2 size={16} />
                          </button>
                        )}
                      </div>
                    ))}

                    <button
                      type="button"
                      onClick={() => {
                        setNewPrescription({
                          ...newPrescription,
                          dispense_times: [...newPrescription.dispense_times, '12:00'],
                        });
                      }}
                      style={{
                        alignSelf: 'flex-start',
                        marginTop: '4px',
                        background: 'none',
                        border: 'none',
                        color: '#6A4C93',
                        fontWeight: '700',
                        fontSize: '0.88rem',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        padding: '6px 0',
                      }}
                    >
                      <Plus size={16} />
                      <span>Add Time</span>
                    </button>
                  </div>
                </div>

                {/* Days of the Week Section */}
                <div className="form-group" style={{ marginBottom: '20px' }}>
                  <label style={{ fontWeight: '700', fontSize: '0.9rem', color: '#2D3142', display: 'block', marginBottom: '2px' }}>
                    Days of the Week
                  </label>
                  <span style={{ fontSize: '0.78rem', color: '#94A3B8', display: 'block', marginBottom: '10px' }}>
                    If no days are selected, it will default to Everyday.
                  </span>

                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                    {DAYS_OF_WEEK.map((day) => {
                      const isSelected = newPrescription.dispense_days.includes(day.id);
                      return (
                        <button
                          type="button"
                          key={day.id}
                          onClick={() => {
                            let updated = [...newPrescription.dispense_days];
                            if (isSelected) {
                              updated = updated.filter((d) => d !== day.id);
                            } else {
                              updated.push(day.id);
                            }
                            setNewPrescription({ ...newPrescription, dispense_days: updated });
                          }}
                          style={{
                            padding: '8px 14px',
                            borderRadius: '12px',
                            border: isSelected ? '1.5px solid #6A4C93' : '1px solid #CBD5E1',
                            background: isSelected ? '#6A4C93' : '#FFFFFF',
                            color: isSelected ? 'white' : '#475569',
                            fontWeight: '700',
                            fontSize: '0.85rem',
                            cursor: 'pointer',
                            transition: 'all 0.15s ease',
                          }}
                        >
                          {day.label}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Start Date & End Date Datepicker (End Date validated >= Start Date) */}
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '24px' }}>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Start Date *</label>
                    <input
                      type="date"
                      value={newPrescription.start_date}
                      onChange={(e) => {
                        const newStart = e.target.value;
                        let updatedEnd = newPrescription.end_date;
                        if (updatedEnd && updatedEnd < newStart) {
                          updatedEnd = newStart;
                        }
                        setNewPrescription({ ...newPrescription, start_date: newStart, end_date: updatedEnd });
                      }}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                      required
                    />
                  </div>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>End Date</label>
                    <input
                      type="date"
                      value={newPrescription.end_date}
                      min={newPrescription.start_date}
                      onChange={(e) => setNewPrescription({ ...newPrescription, end_date: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={formLoading} style={{ flex: 1, padding: '12px' }}>
                    {formLoading ? 'Saving...' : 'Save Prescription'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Edit Prescription Modal */}
        {editingPrescription && (
          <div className="modal-overlay" onClick={() => setEditingPrescription(null)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '520px', maxHeight: '90vh', overflowY: 'auto' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Edit size={20} color="#6A4C93" />
                  Edit Prescription
                </h3>
                <button onClick={() => setEditingPrescription(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}>
                  <X size={20} />
                </button>
              </div>

              {formError && (
                <div style={{ padding: '10px', background: '#FEE2E2', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                  {formError}
                </div>
              )}

              <form onSubmit={handleEditPrescriptionSubmit}>
                {/* Select Medication (Fixed: Extracts medication_name & medication_id correctly) */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Select Medication *</label>
                  <select
                    value={editForm.medication_id}
                    onChange={(e) => {
                      const mId = e.target.value;
                      const selected = medCatalog.find((m) => String(m.medication_id || m.id) === String(mId));
                      setEditForm({
                        ...editForm,
                        medication_id: mId,
                        medication_name: selected ? (selected.medication_name || selected.name) : editForm.medication_name,
                      });
                    }}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                  >
                    <option value="">{editForm.medication_name || '-- Select Medication --'}</option>
                    {medCatalog.map((m) => {
                      const id = m.medication_id || m.id;
                      const name = m.medication_name || m.name || `Medication #${id}`;
                      return (
                        <option key={id} value={id}>
                          💊 {name} ({m.dosage_form || 'Tablet'})
                        </option>
                      );
                    })}
                  </select>
                </div>

                {/* Dosage (Tablets) - Dispenser Motor Slot removed */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Dosage (Tablets) *</label>
                  <input
                    type="number"
                    step="0.5"
                    min="0.5"
                    placeholder="1.0"
                    value={editForm.dosage}
                    onChange={(e) => setEditForm({ ...editForm, dosage: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    required
                  />
                </div>

                {/* Dispense Times Section (Multiple Times) */}
                <div className="form-group" style={{ marginBottom: '18px' }}>
                  <label style={{ fontWeight: '700', fontSize: '0.9rem', color: '#2D3142', display: 'block', marginBottom: '4px' }}>
                    Dispense Times
                  </label>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '8px' }}>
                    {editForm.dispense_times.map((tVal, idx) => (
                      <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{
                          flex: 1,
                          display: 'flex',
                          alignItems: 'center',
                          gap: '10px',
                          background: '#F8FAFC',
                          padding: '8px 12px',
                          borderRadius: '10px',
                          border: '1px solid #E2E8F0'
                        }}>
                          <Clock size={16} color="#6A4C93" />
                          <input
                            type="time"
                            value={tVal}
                            onChange={(e) => {
                              const updated = [...editForm.dispense_times];
                              updated[idx] = e.target.value;
                              setEditForm({ ...editForm, dispense_times: updated });
                            }}
                            style={{ border: 'none', background: 'transparent', outline: 'none', fontSize: '0.95rem', fontWeight: '600', color: '#6A4C93' }}
                            required
                          />
                        </div>
                        {editForm.dispense_times.length > 1 && (
                          <button
                            type="button"
                            onClick={() => {
                              const updated = editForm.dispense_times.filter((_, i) => i !== idx);
                              setEditForm({ ...editForm, dispense_times: updated });
                            }}
                            style={{ background: '#FEE2E2', border: 'none', color: '#EF4444', padding: '8px', borderRadius: '8px', cursor: 'pointer' }}
                            title="Remove time"
                          >
                            <Trash2 size={16} />
                          </button>
                        )}
                      </div>
                    ))}

                    <button
                      type="button"
                      onClick={() => {
                        setEditForm({
                          ...editForm,
                          dispense_times: [...editForm.dispense_times, '12:00'],
                        });
                      }}
                      style={{
                        alignSelf: 'flex-start',
                        marginTop: '4px',
                        background: 'none',
                        border: 'none',
                        color: '#6A4C93',
                        fontWeight: '700',
                        fontSize: '0.88rem',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        padding: '6px 0',
                      }}
                    >
                      <Plus size={16} />
                      <span>Add Time</span>
                    </button>
                  </div>
                </div>

                {/* Days of the Week Section */}
                <div className="form-group" style={{ marginBottom: '20px' }}>
                  <label style={{ fontWeight: '700', fontSize: '0.9rem', color: '#2D3142', display: 'block', marginBottom: '2px' }}>
                    Days of the Week
                  </label>
                  <span style={{ fontSize: '0.78rem', color: '#94A3B8', display: 'block', marginBottom: '10px' }}>
                    If no days are selected, it will default to Everyday.
                  </span>

                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                    {DAYS_OF_WEEK.map((day) => {
                      const isSelected = editForm.dispense_days.includes(day.id);
                      return (
                        <button
                          type="button"
                          key={day.id}
                          onClick={() => {
                            let updated = [...editForm.dispense_days];
                            if (isSelected) {
                              updated = updated.filter((d) => d !== day.id);
                            } else {
                              updated.push(day.id);
                            }
                            setEditForm({ ...editForm, dispense_days: updated });
                          }}
                          style={{
                            padding: '8px 14px',
                            borderRadius: '12px',
                            border: isSelected ? '1.5px solid #6A4C93' : '1px solid #CBD5E1',
                            background: isSelected ? '#6A4C93' : '#FFFFFF',
                            color: isSelected ? 'white' : '#475569',
                            fontWeight: '700',
                            fontSize: '0.85rem',
                            cursor: 'pointer',
                            transition: 'all 0.15s ease',
                          }}
                        >
                          {day.label}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Start Date & End Date Datepicker (End Date validated >= Start Date) */}
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '24px' }}>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Start Date *</label>
                    <input
                      type="date"
                      value={editForm.start_date}
                      onChange={(e) => {
                        const newStart = e.target.value;
                        let updatedEnd = editForm.end_date;
                        if (updatedEnd && updatedEnd < newStart) {
                          updatedEnd = newStart;
                        }
                        setEditForm({ ...editForm, start_date: newStart, end_date: updatedEnd });
                      }}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                      required
                    />
                  </div>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>End Date</label>
                    <input
                      type="date"
                      value={editForm.end_date}
                      min={editForm.start_date}
                      onChange={(e) => setEditForm({ ...editForm, end_date: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setEditingPrescription(null)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={formLoading} style={{ flex: 1, padding: '12px' }}>
                    {formLoading ? 'Saving...' : 'Save Changes'}
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

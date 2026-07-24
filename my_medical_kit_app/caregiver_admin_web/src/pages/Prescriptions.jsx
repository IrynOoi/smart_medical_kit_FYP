import React, { useState, useEffect } from 'react';
import { 
  Pill, 
  Plus, 
  AlertTriangle, 
  RotateCw, 
  X, 
  Clock, 
  CheckCircle2, 
  PackageCheck,
  ChevronRight
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

export default function Prescriptions({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();
  
  const [patients, setPatients] = useState([]);
  const [selectedPatientId, setSelectedPatientId] = useState('');
  const [prescriptions, setPrescriptions] = useState([]);
  const [medCatalog, setMedCatalog] = useState([]);
  const [loading, setLoading] = useState(true);

  // Restock modal state
  const [restockModal, setRestockModal] = useState(null); // { prescriptionId, currentInventory, medicationName }
  const [restockQty, setRestockQty] = useState(20);
  const [restockLoading, setRestockLoading] = useState(false);

  // Add prescription modal state
  const [showAddModal, setShowAddModal] = useState(false);
  const [newPrescription, setNewPrescription] = useState({
    patient_id: '',
    medication_id: '',
    dosage: '1 pill',
    frequency: 'Daily',
    scheduled_time: '08:00',
    motor_slot: 1,
    current_inventory: 30,
    refill_threshold: 5,
  });
  const [formError, setFormError] = useState('');
  const [formLoading, setFormLoading] = useState(false);

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
          setSelectedPatientId(patientsData[0].id || patientsData[0].patient_id);
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
    try {
      const list = await apiService.getPatientMedications(pid);
      setPrescriptions(list);
    } catch (err) {
      setPrescriptions([]);
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

  // Handle Restock Submit
  const handleRestockSubmit = async (e) => {
    e.preventDefault();
    if (!restockModal) return;

    setRestockLoading(true);
    const success = await apiService.restockMedication(restockModal.prescriptionId, restockQty);
    if (success) {
      setRestockModal(null);
      fetchPrescriptions(selectedPatientId);
    } else {
      alert('Failed to restock medication. Please check backend connection.');
    }
    setRestockLoading(false);
  };

  // Handle Add Prescription Submit
  const handleAddPrescriptionSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setFormLoading(true);

    try {
      const pid = newPrescription.patient_id || selectedPatientId;
      const res = await apiService.addPrescription({
        ...newPrescription,
        patient_id: parseInt(pid),
        medication_id: parseInt(newPrescription.medication_id) || (medCatalog[0]?.id || 1),
        motor_slot: parseInt(newPrescription.motor_slot),
        current_inventory: parseInt(newPrescription.current_inventory),
        refill_threshold: parseInt(newPrescription.refill_threshold),
      });

      if (res.success) {
        setShowAddModal(false);
        fetchPrescriptions(selectedPatientId);
      } else {
        setFormError(res.error || 'Failed to add prescription.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred.');
    } finally {
      setFormLoading(false);
    }
  };

  return (
    <div>
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
                background: '#F8FAFC'
              }}
            >
              {patients.map((p) => (
                <option key={p.id || p.patient_id} value={p.id || p.patient_id}>
                  {p.fullname || `Patient #${p.id}`}
                </option>
              ))}
            </select>
          </div>

          <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
            <Plus size={18} />
            <span>Add New Prescription</span>
          </button>
        </div>
      </div>

      {/* Prescriptions & Inventory List */}
      <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
        <div className="card-header">
          <div>
            <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Pill size={20} color="#6A4C93" />
              Medication Schedule & Inventory Stock
            </h3>
            <p style={{ fontSize: '0.8rem', color: '#6B7280' }}>
              Monitor pill count levels and hardware dispenser motor slots
            </p>
          </div>
        </div>

        {prescriptions.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px', color: '#94A3B8' }}>
            <PackageCheck size={48} style={{ margin: '0 auto 12px auto', display: 'block' }} />
            No prescriptions found for the selected patient.
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '20px' }}>
            {prescriptions.map((pres) => {
              const stock = pres.current_inventory ?? pres.inventory ?? 20;
              const threshold = pres.refill_threshold ?? 5;
              const isLow = stock <= threshold;

              return (
                <div
                  key={pres.id || pres.prescription_id}
                  style={{
                    border: '1px solid #E2E8F0',
                    borderRadius: '16px',
                    padding: '20px',
                    background: isLow ? '#FFFBEB' : '#F8FAFC',
                    position: 'relative',
                    transition: 'all 0.2s ease',
                  }}
                >
                  {isLow && (
                    <div style={{
                      position: 'absolute',
                      top: '12px',
                      right: '12px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                      padding: '4px 8px',
                      background: '#FEF3C7',
                      color: '#B45309',
                      borderRadius: '12px',
                      fontSize: '0.75rem',
                      fontWeight: '700'
                    }}>
                      <AlertTriangle size={14} />
                      Low Stock
                    </div>
                  )}

                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '14px' }}>
                    <div style={{
                      width: '44px',
                      height: '44px',
                      borderRadius: '12px',
                      background: isLow ? '#F59E0B' : '#6A4C93',
                      color: 'white',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}>
                      <Pill size={22} />
                    </div>
                    <div>
                      <h4 style={{ fontSize: '1.05rem', color: '#2D3142' }}>
                        {pres.medication_name || pres.name || 'Prescription Name'}
                      </h4>
                      <span className="badge badge-purple" style={{ fontSize: '0.72rem' }}>
                        Dispenser Slot #{pres.motor_slot || 1}
                      </span>
                    </div>
                  </div>

                  <div style={{ fontSize: '0.85rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '16px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span>Dosage:</span>
                      <strong>{pres.dosage || '1 pill'}</strong>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span>Scheduled Time:</span>
                      <strong>{pres.scheduled_time || pres.time || '08:00 AM'}</strong>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span>Frequency:</span>
                      <strong>{pres.frequency || 'Daily'}</strong>
                    </div>
                  </div>

                  {/* Stock Level Bar */}
                  <div style={{ marginBottom: '16px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', marginBottom: '4px' }}>
                      <span style={{ color: '#64748B' }}>Pill Inventory Level</span>
                      <strong style={{ color: isLow ? '#B45309' : '#10B981' }}>{stock} pills remaining</strong>
                    </div>
                    <div style={{ width: '100%', height: '8px', background: '#E2E8F0', borderRadius: '4px', overflow: 'hidden' }}>
                      <div style={{
                        width: `${Math.min((stock / 30) * 100, 100)}%`,
                        height: '100%',
                        background: isLow ? '#F59E0B' : '#10B981',
                        borderRadius: '4px',
                        transition: 'width 0.3s ease'
                      }} />
                    </div>
                  </div>

                  <button
                    className="btn btn-outline"
                    onClick={() => setRestockModal({
                      prescriptionId: pres.id || pres.prescription_id,
                      currentInventory: stock,
                      medicationName: pres.medication_name || pres.name || 'Medication',
                    })}
                    style={{ width: '100%', padding: '8px', fontSize: '0.85rem' }}
                  >
                    <RotateCw size={16} />
                    <span>Restock Pill Supply</span>
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Restock Modal */}
      {restockModal && (
        <div className="modal-overlay" onClick={() => setRestockModal(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '420px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '1.15rem' }}>Restock Pill Inventory</h3>
              <button onClick={() => setRestockModal(null)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>

            <p style={{ fontSize: '0.88rem', color: '#64748B', marginBottom: '16px' }}>
              Refill pill stock for <strong>{restockModal.medicationName}</strong> (Current: {restockModal.currentInventory} pills).
            </p>

            <form onSubmit={handleRestockSubmit}>
              <div className="form-group">
                <label>Add Pills Quantity</label>
                <input
                  type="number"
                  min="1"
                  max="100"
                  value={restockQty}
                  onChange={(e) => setRestockQty(parseInt(e.target.value) || 1)}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  required
                />
              </div>

              <div style={{ display: 'flex', gap: '12px', marginTop: '20px' }}>
                <button type="button" className="btn btn-secondary" onClick={() => setRestockModal(null)} style={{ flex: 1 }}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={restockLoading} style={{ flex: 1 }}>
                  {restockLoading ? 'Updating...' : 'Confirm Restock'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Prescription Modal */}
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
              <h3 style={{ fontSize: '1.2rem' }}>Add New Prescription</h3>
              <button onClick={() => setShowAddModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>

            {formError && (
              <div style={{ padding: '10px', background: '#FEE2E2', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                {formError}
              </div>
            )}

            <form onSubmit={handleAddPrescriptionSubmit}>
              <div className="form-group">
                <label>Select Patient</label>
                <select
                  value={newPrescription.patient_id || selectedPatientId}
                  onChange={(e) => setNewPrescription({ ...newPrescription, patient_id: e.target.value })}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  required
                >
                  {patients.map((p) => (
                    <option key={p.id || p.patient_id} value={p.id || p.patient_id}>
                      {p.fullname || `Patient #${p.id}`}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Select Medication</label>
                <select
                  value={newPrescription.medication_id}
                  onChange={(e) => setNewPrescription({ ...newPrescription, medication_id: e.target.value })}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  required
                >
                  <option value="">-- Choose from Master Catalog --</option>
                  {medCatalog.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.name} ({m.dosage_form || 'Tablet'})
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label>Dosage</label>
                  <input
                    type="text"
                    value={newPrescription.dosage}
                    onChange={(e) => setNewPrescription({ ...newPrescription, dosage: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    required
                  />
                </div>
                <div>
                  <label>Dispenser Slot (1-3)</label>
                  <select
                    value={newPrescription.motor_slot}
                    onChange={(e) => setNewPrescription({ ...newPrescription, motor_slot: parseInt(e.target.value) })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  >
                    <option value={1}>Slot 1 (Motor 1)</option>
                    <option value={2}>Slot 2 (Motor 2)</option>
                    <option value={3}>Slot 3 (Motor 3)</option>
                  </select>
                </div>
              </div>

              <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label>Scheduled Time</label>
                  <input
                    type="time"
                    value={newPrescription.scheduled_time}
                    onChange={(e) => setNewPrescription({ ...newPrescription, scheduled_time: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    required
                  />
                </div>
                <div>
                  <label>Initial Pill Count</label>
                  <input
                    type="number"
                    value={newPrescription.current_inventory}
                    onChange={(e) => setNewPrescription({ ...newPrescription, current_inventory: parseInt(e.target.value) || 0 })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>
              </div>

              <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)} style={{ flex: 1 }}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={formLoading} style={{ flex: 1 }}>
                  {formLoading ? 'Saving...' : 'Save Prescription'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

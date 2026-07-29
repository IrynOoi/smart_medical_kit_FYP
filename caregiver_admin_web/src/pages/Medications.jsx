// Medications.jsx
import React, { useState, useEffect } from 'react';
import {
  Pill,
  Plus,
  Edit,
  Trash2,
  Search,
  X,
  CheckCircle2,
  AlertTriangle,
  Loader2,
  PackageCheck,
  Cpu,
} from 'lucide-react';
import { apiService } from '../services/apiService';

export default function Medications({ isRefreshing, onRefreshComplete }) {
  const [medications, setMedications] = useState([]);
  const [devicesList, setDevicesList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Add Medication Modal State
  const [showAddModal, setShowAddModal] = useState(false);
  const [newMed, setNewMed] = useState({
    medication_name: '',
    current_inventory: 0,
    refill_threshold: 10,
    device_serial: '',
    motor_slot: 1,
  });

  // Edit Medication Modal State
  const [editingMed, setEditingMed] = useState(null);
  const [editForm, setEditForm] = useState({
    medication_name: '',
    current_inventory: 0,
    refill_threshold: 10,
    device_serial: '',
    motor_slot: 1,
  });

  const [formError, setFormError] = useState('');
  const [formLoading, setFormLoading] = useState(false);
  const [actionSuccessMsg, setActionSuccessMsg] = useState('');

  const fetchMedications = async (showSpinner = true) => {
    if (showSpinner) setLoading(true);
    try {
      const [medsData, devData] = await Promise.all([
        apiService.getMedicationsCatalog(),
        apiService.getDevices(),
      ]);

      setMedications(Array.isArray(medsData) ? medsData : []);
      if (Array.isArray(devData)) {
        setDevicesList(devData);
      }
    } catch (err) {
      console.error('Error fetching medication catalog:', err);
    } finally {
      if (showSpinner) setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  useEffect(() => {
    fetchMedications(true);
    const interval = setInterval(() => {
      fetchMedications(false); // Silent background auto-reload without spinner
    }, 15000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (isRefreshing) fetchMedications(true);
  }, [isRefreshing]);

  // Open Add Modal
  const handleOpenAdd = () => {
    const defaultSerial = devicesList[0]?.device_serial || 'DISP-1';
    setNewMed({
      medication_name: '',
      current_inventory: 0,
      refill_threshold: 10,
      device_serial: defaultSerial,
      motor_slot: 1,
    });
    setFormError('');
    setShowAddModal(true);
  };

  // Open Edit Modal
  const handleOpenEdit = (med) => {
    setEditingMed(med);
    const defaultSerial = med.device_serial || (devicesList[0]?.device_serial || 'DISP-1');
    setEditForm({
      medication_name: med.medication_name || med.name || '',
      current_inventory: med.current_inventory ?? 0,
      refill_threshold: med.refill_threshold ?? 10,
      device_serial: defaultSerial,
      motor_slot: med.motor_slot || 1,
    });
    setFormError('');
  };

  // Handle Add Medication Submit
  const handleAddSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setFormLoading(true);

    try {
      const payload = {
        medication_name: newMed.medication_name.trim(),
        current_inventory: parseInt(newMed.current_inventory) || 0,
        refill_threshold: parseInt(newMed.refill_threshold) || 10,
        device_serial: newMed.device_serial,
        motor_slot: parseInt(newMed.motor_slot) || 1,
      };

      const res = await apiService.addMedicationCatalog(payload);
      if (res && (res.success || res.data)) {
        setShowAddModal(false);
        setActionSuccessMsg(`Medication "${payload.medication_name}" added to catalog!`);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchMedications();
      } else {
        setFormError(res?.message || res?.error || 'Failed to add medication.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred.');
    } finally {
      setFormLoading(false);
    }
  };

  // Handle Edit Medication Submit
  const handleEditSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setFormLoading(true);

    try {
      const medId = editingMed.id || editingMed.medication_id;
      const payload = {
        medication_name: editForm.medication_name.trim(),
        current_inventory: parseInt(editForm.current_inventory) || 0,
        refill_threshold: parseInt(editForm.refill_threshold) || 10,
        device_serial: editForm.device_serial,
        motor_slot: parseInt(editForm.motor_slot) || 1,
      };

      const res = await apiService.updateMedicationCatalog(medId, payload);
      if (res && (res.success || res.data)) {
        setEditingMed(null);
        setActionSuccessMsg('Medication details updated successfully!');
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchMedications();
      } else {
        setFormError(res?.message || res?.error || 'Failed to update medication.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred while updating.');
    } finally {
      setFormLoading(false);
    }
  };

  // Handle Delete Medication
  const handleDeleteMedication = async (med) => {
    const medId = med.id || med.medication_id;
    const name = med.medication_name || med.name || 'this medication';

    if (window.confirm(`Delete "${name}" from master catalog?\n\nNote: Deletion is only allowed if no active prescriptions are using this medication.`)) {
      const res = await apiService.deleteMedicationCatalog(medId);
      if (res && res.success) {
        setActionSuccessMsg(`Medication "${name}" deleted from catalog.`);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchMedications();
      } else {
        alert(res?.message || 'Cannot delete medication: It is currently assigned to one or more active prescriptions.');
      }
    }
  };

  // Filter list by search query
  const filteredMeds = medications.filter((m) => {
    const name = m.medication_name || m.name || '';
    const serial = m.device_serial || '';
    const query = searchQuery.toLowerCase();
    return name.toLowerCase().includes(query) || serial.toLowerCase().includes(query);
  });

  const showSpinner = loading || isRefreshing;

  return (
    <div style={{ position: 'relative', minHeight: '400px' }}>
      {/* Spinner overlay */}
      {showSpinner && (
        <div className="loading-overlay">
          <Loader2 className="spinner" size={48} color="#6A4C93" />
          <p style={{ marginTop: '12px', color: '#6B7280', fontWeight: 500 }}>
            {loading ? 'Loading master medications catalog...' : 'Refreshing...'}
          </p>
        </div>
      )}

      {/* Main Content */}
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

        {/* Top Banner & Search */}
        <div className="glass-card" style={{ padding: '20px', marginBottom: '24px', background: 'white' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
            <div className="search-box" style={{ width: '320px' }}>
              <Search size={18} />
              <input
                type="text"
                placeholder="Search medication name or device serial..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            <button className="btn btn-primary" onClick={handleOpenAdd}>
              <Plus size={18} />
              <span>Add New Medication</span>
            </button>
          </div>
        </div>

        {/* Medication Cards Grid */}
        {filteredMeds.length === 0 ? (
          <div className="glass-card" style={{ padding: '40px', textAlign: 'center', background: 'white' }}>
            <PackageCheck size={48} color="#94A3B8" style={{ margin: '0 auto 12px auto', display: 'block' }} />
            <h3 style={{ color: '#2D3142' }}>No Medications Found</h3>
            <p style={{ color: '#6B7280', fontSize: '0.9rem', marginTop: '4px' }}>
              {searchQuery ? 'No medications matched your search.' : 'Click "Add New Medication" to expand the catalog.'}
            </p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
            {filteredMeds.map((med) => {
              const medId = med.id || med.medication_id;
              const name = med.medication_name || med.name || 'Medication Name';
              const serial = med.device_serial || 'DISP-1';
              const slot = med.motor_slot || 1;
              const stock = med.current_inventory ?? 0;
              const threshold = med.refill_threshold ?? 10;
              const isLow = stock <= threshold;

              return (
                <div
                  key={medId}
                  className="glass-card"
                  style={{
                    padding: '20px',
                    background: 'white',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    borderLeft: `4px solid ${isLow ? '#F59E0B' : '#6A4C93'}`,
                  }}
                >
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' }}>
                      <div style={{
                        width: '48px',
                        height: '48px',
                        borderRadius: '12px',
                        background: isLow ? 'linear-gradient(135deg, #D97706 0%, #F59E0B 100%)' : 'linear-gradient(135deg, #3B1E54 0%, #6A4C93 100%)',
                        color: 'white',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}>
                        <Pill size={24} />
                      </div>

                      <div style={{ flex: 1, overflow: 'hidden' }}>
                        <h3 style={{ fontSize: '1.1rem', color: '#2D3142', fontWeight: '700', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                          {name}
                        </h3>
                        <span className="badge badge-purple" style={{ fontSize: '0.72rem' }}>
                          {serial} • Slot #{slot}
                        </span>
                      </div>
                    </div>

                    <div style={{ fontSize: '0.85rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '16px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: '#64748B' }}>Current Inventory:</span>
                        <strong style={{ color: isLow ? '#B45309' : '#10B981' }}>{stock} pills</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: '#64748B' }}>Refill Threshold:</span>
                        <strong>{threshold} pills</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: '#64748B' }}>Assigned Hardware Serial:</span>
                        <strong>{serial}</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: '#64748B' }}>Dispenser Motor Slot:</span>
                        <strong>Slot {slot} (Motor {slot})</strong>
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div style={{ display: 'flex', gap: '8px', paddingTop: '14px', borderTop: '1px solid #E2E8F0' }}>
                    <button
                      className="btn"
                      style={{ flex: 1, padding: '7px', fontSize: '0.82rem', background: '#F1F5F9', color: '#334155', border: '1px solid #CBD5E1' }}
                      onClick={() => handleOpenEdit(med)}
                      title="Edit Medication Details"
                    >
                      <Edit size={15} />
                      <span>Edit</span>
                    </button>

                    <button
                      className="btn btn-secondary"
                      style={{ padding: '7px 12px', color: '#EF4444', background: '#FEE2E2', border: '1px solid #FCA5A5' }}
                      onClick={() => handleDeleteMedication(med)}
                      title="Delete Medication"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Add Medication Modal */}
        {showAddModal && (
          <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '460px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142', fontWeight: '700' }}>Add New Medication</h3>
                <button onClick={() => setShowAddModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}>
                  <X size={20} />
                </button>
              </div>

              {formError && (
                <div style={{ padding: '10px', background: '#FEE2E2', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                  {formError}
                </div>
              )}

              <form onSubmit={handleAddSubmit}>
                {/* 1. Medication Name * */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Medication Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Paracetamol 500mg"
                    value={newMed.medication_name}
                    onChange={(e) => setNewMed({ ...newMed, medication_name: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>

                {/* 2. Initial Inventory & 3. Refill Threshold */}
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '16px' }}>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Initial Inventory *</label>
                    <input
                      type="number"
                      required
                      min="0"
                      value={newMed.current_inventory}
                      onChange={(e) => setNewMed({ ...newMed, current_inventory: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Refill Threshold *</label>
                    <input
                      type="number"
                      required
                      min="1"
                      value={newMed.refill_threshold}
                      onChange={(e) => setNewMed({ ...newMed, refill_threshold: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                </div>

                {/* 4. Device Serial (Dropdown) */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Device Serial *</label>
                  <select
                    value={newMed.device_serial}
                    onChange={(e) => setNewMed({ ...newMed, device_serial: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                    required
                  >
                    {devicesList.length === 0 ? (
                      <option value="DISP-1">DISP-1 (Default Device)</option>
                    ) : (
                      devicesList.map((d) => (
                        <option key={d.id || d.device_serial} value={d.device_serial}>
                          {d.device_serial}
                        </option>
                      ))
                    )}
                  </select>
                </div>

                {/* 5. Motor Slot (1-3) */}
                <div className="form-group" style={{ marginBottom: '24px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Motor Slot (1-3) *</label>
                  <select
                    value={newMed.motor_slot}
                    onChange={(e) => setNewMed({ ...newMed, motor_slot: parseInt(e.target.value) })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                    required
                  >
                    <option value={1}>Motor Slot 1</option>
                    <option value={2}>Motor Slot 2</option>
                    <option value={3}>Motor Slot 3</option>
                  </select>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={formLoading} style={{ flex: 1, padding: '12px' }}>
                    {formLoading ? 'Saving...' : 'Add Medication'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Edit Medication Modal */}
        {editingMed && (
          <div className="modal-overlay" onClick={() => setEditingMed(null)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '460px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Edit size={20} color="#6A4C93" />
                  Edit Medication Entry
                </h3>
                <button onClick={() => setEditingMed(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}>
                  <X size={20} />
                </button>
              </div>

              {formError && (
                <div style={{ padding: '10px', background: '#FEE2E2', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                  {formError}
                </div>
              )}

              <form onSubmit={handleEditSubmit}>
                {/* 1. Medication Name * */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Medication Name *</label>
                  <input
                    type="text"
                    required
                    value={editForm.medication_name}
                    onChange={(e) => setEditForm({ ...editForm, medication_name: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>

                {/* 2. Current Inventory & 3. Refill Threshold */}
                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '16px' }}>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Current Inventory *</label>
                    <input
                      type="number"
                      required
                      min="0"
                      value={editForm.current_inventory}
                      onChange={(e) => setEditForm({ ...editForm, current_inventory: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Refill Threshold *</label>
                    <input
                      type="number"
                      required
                      min="1"
                      value={editForm.refill_threshold}
                      onChange={(e) => setEditForm({ ...editForm, refill_threshold: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                </div>

                {/* 4. Device Serial (Dropdown) */}
                <div className="form-group" style={{ marginBottom: '16px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Device Serial *</label>
                  <select
                    value={editForm.device_serial}
                    onChange={(e) => setEditForm({ ...editForm, device_serial: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                    required
                  >
                    {devicesList.length === 0 ? (
                      <option value={editForm.device_serial || 'DISP-1'}>{editForm.device_serial || 'DISP-1'}</option>
                    ) : (
                      devicesList.map((d) => (
                        <option key={d.id || d.device_serial} value={d.device_serial}>
                          {d.device_serial}
                        </option>
                      ))
                    )}
                  </select>
                </div>

                {/* 5. Motor Slot (1-3) */}
                <div className="form-group" style={{ marginBottom: '24px' }}>
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Motor Slot (1-3) *</label>
                  <select
                    value={editForm.motor_slot}
                    onChange={(e) => setEditForm({ ...editForm, motor_slot: parseInt(e.target.value) })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                    required
                  >
                    <option value={1}>Motor Slot 1</option>
                    <option value={2}>Motor Slot 2</option>
                    <option value={3}>Motor Slot 3</option>
                  </select>
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setEditingMed(null)} style={{ flex: 1 }}>
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

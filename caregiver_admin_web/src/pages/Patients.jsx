//Patients.jsx
import React, { useState, useEffect } from 'react';
import {
  Users,
  Search,
  UserPlus,
  Eye,
  Trash2,
  X,
  Phone,
  Mail,
  MapPin,
  Pill,
  AlertCircle,
  CheckCircle2
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

export default function Patients({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();

  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Modals state
  const [selectedPatient, setSelectedPatient] = useState(null);
  const [patientMedications, setPatientMedications] = useState([]);
  const [showAddModal, setShowAddModal] = useState(false);

  // New Patient Form state
  const [newPatient, setNewPatient] = useState({
    fullname: '',
    email: '',
    password: 'Password123!',
    phone: '',
    address: '',
    age: 65,
    caregiver_id: caregiverId,
  });
  const [formError, setFormError] = useState('');
  const [formLoading, setFormLoading] = useState(false);

  const fetchPatients = async () => {
    setLoading(true);
    try {
      const data = await apiService.getCaregiverPatients(caregiverId);
      if (Array.isArray(data)) {
        setPatients(data);
      }
    } catch (err) {
      console.error('Error fetching patients:', err);
    } finally {
      setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  useEffect(() => {
    fetchPatients();
  }, [caregiverId]);

  useEffect(() => {
    if (isRefreshing) fetchPatients();
  }, [isRefreshing]);

  // View patient details
  const handleViewPatient = async (patient) => {
    setSelectedPatient(patient);
    try {
      const meds = await apiService.getPatientMedications(patient.id || patient.patient_id);
      setPatientMedications(meds);
    } catch (err) {
      setPatientMedications([]);
    }
  };

  // Add Patient Submission
  const handleAddPatientSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setFormLoading(true);

    try {
      const res = await apiService.addPatient({
        ...newPatient,
        caregiver_id: caregiverId,
      });

      if (res.success) {
        setShowAddModal(false);
        setNewPatient({
          fullname: '',
          email: '',
          password: 'Password123!',
          phone: '',
          address: '',
          age: 65,
          caregiver_id: caregiverId,
        });
        fetchPatients();
      } else {
        setFormError(res.error || 'Failed to create patient account.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred.');
    } finally {
      setFormLoading(false);
    }
  };

  // Delete Patient
  const handleDeletePatient = async (id) => {
    if (window.confirm('Are you sure you want to remove this patient from your care list?')) {
      const success = await apiService.deletePatient(id);
      if (success) {
        fetchPatients();
      }
    }
  };

  // Filter patients by search query
  const filteredPatients = patients.filter((p) => {
    const name = p.fullname || p.name || '';
    const email = p.email || '';
    const query = searchQuery.toLowerCase();
    return name.toLowerCase().includes(query) || email.toLowerCase().includes(query);
  });

  return (
    <div>
      {/* Action & Search Bar */}
      <div className="glass-card" style={{ padding: '20px', marginBottom: '24px', background: 'white' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
          <div className="search-box" style={{ width: '320px' }}>
            <Search size={18} />
            <input
              type="text"
              placeholder="Search patients by name or email..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
            <UserPlus size={18} />
            <span>Add New Patient</span>
          </button>
        </div>
      </div>

      {/* Patient Cards Grid */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px', color: '#64748B' }}>
          Loading assigned patients...
        </div>
      ) : filteredPatients.length === 0 ? (
        <div className="glass-card" style={{ padding: '40px', textAlign: 'center', background: 'white' }}>
          <Users size={48} color="#94A3B8" style={{ margin: '0 auto 12px auto', display: 'block' }} />
          <h3 style={{ color: '#2D3142' }}>No Patients Found</h3>
          <p style={{ color: '#6B7280', fontSize: '0.9rem', marginTop: '4px' }}>
            {searchQuery ? 'No patients matched your search criteria.' : 'Click "Add New Patient" to enroll a patient.'}
          </p>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
          {filteredPatients.map((patient) => (
            <div
              key={patient.id || patient.patient_id}
              className="glass-card"
              style={{ padding: '20px', background: 'white', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}
            >
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' }}>
                  <div style={{
                    width: '48px',
                    height: '48px',
                    borderRadius: '50%',
                    background: 'linear-gradient(135deg, #3B1E54 0%, #6A4C93 100%)',
                    color: 'white',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: '700',
                    fontSize: '1.2rem'
                  }}>
                    {patient.fullname ? patient.fullname.charAt(0).toUpperCase() : 'P'}
                  </div>

                  <div>
                    <h3 style={{ fontSize: '1.05rem', color: '#2D3142' }}>
                      {patient.fullname || 'Patient Name'}
                    </h3>
                    <div style={{ fontSize: '0.8rem', color: '#64748B' }}>
                      ID: #{patient.id || patient.patient_id} • Age: {patient.age || 'N/A'}
                    </div>
                  </div>
                </div>

                <div style={{ fontSize: '0.85rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '16px' }}>
                  {patient.email && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <Mail size={14} color="#6A4C93" />
                      <span>{patient.email}</span>
                    </div>
                  )}
                  {patient.phone && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <Phone size={14} color="#6A4C93" />
                      <span>{patient.phone}</span>
                    </div>
                  )}
                  {patient.address && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <MapPin size={14} color="#6A4C93" />
                      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{patient.address}</span>
                    </div>
                  )}
                </div>
              </div>

              <div style={{ display: 'flex', gap: '10px', paddingTop: '14px', borderTop: '1px solid #E2E8F0' }}>
                <button
                  className="btn btn-outline"
                  style={{ flex: 1, padding: '8px', fontSize: '0.82rem' }}
                  onClick={() => handleViewPatient(patient)}
                >
                  <Eye size={16} />
                  <span>View Details</span>
                </button>

                <button
                  className="btn btn-secondary"
                  style={{ padding: '8px 12px', color: '#EF4444' }}
                  onClick={() => handleDeletePatient(patient.id || patient.patient_id)}
                  title="Remove patient"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* View Patient Details Modal */}
      {selectedPatient && (
        <div className="modal-overlay" onClick={() => setSelectedPatient(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
              <h3 style={{ fontSize: '1.2rem' }}>Patient Detailed Profile</h3>
              <button
                onClick={() => setSelectedPatient(null)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}
              >
                <X size={20} />
              </button>
            </div>

            <div style={{ display: 'flex', gap: '16px', alignItems: 'center', marginBottom: '20px' }}>
              <div style={{ width: '60px', height: '60px', borderRadius: '50%', background: '#6A4C93', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.5rem', fontWeight: '700' }}>
                {selectedPatient.fullname?.charAt(0).toUpperCase()}
              </div>
              <div>
                <h4 style={{ fontSize: '1.2rem', color: '#2D3142' }}>{selectedPatient.fullname}</h4>
                <p style={{ fontSize: '0.85rem', color: '#64748B' }}>Email: {selectedPatient.email}</p>
                <p style={{ fontSize: '0.85rem', color: '#64748B' }}>Phone: {selectedPatient.phone || 'N/A'}</p>
              </div>
            </div>

            <h4 style={{ fontSize: '1rem', color: '#3B1E54', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Pill size={18} />
              Prescribed Medications ({patientMedications.length})
            </h4>

            {patientMedications.length === 0 ? (
              <p style={{ color: '#94A3B8', fontSize: '0.88rem', fontStyle: 'italic', marginBottom: '20px' }}>
                No active prescriptions assigned to this patient.
              </p>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '20px' }}>
                {patientMedications.map((med, i) => (
                  <div key={med.id || i} style={{ padding: '12px', background: '#F8FAFC', borderRadius: '10px', border: '1px solid #E2E8F0' }}>
                    <div style={{ fontWeight: '600', color: '#2D3142' }}>{med.medication_name || med.name}</div>
                    <div style={{ fontSize: '0.8rem', color: '#64748B' }}>
                      Dosage: {med.dosage || '1 pill'} • Schedule: {med.scheduled_time || med.frequency || 'Daily'} • Motor Slot: #{med.motor_slot || 1}
                    </div>
                  </div>
                ))}
              </div>
            )}

            <button
              className="btn btn-secondary"
              onClick={() => setSelectedPatient(null)}
              style={{ width: '100%', padding: '10px' }}
            >
              Close Profile
            </button>
          </div>
        </div>
      )}

      {/* Add New Patient Modal */}
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
              <h3 style={{ fontSize: '1.2rem' }}>Enroll New Patient</h3>
              <button onClick={() => setShowAddModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>

            {formError && (
              <div style={{ padding: '10px', background: '#FEE2E2', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                {formError}
              </div>
            )}

            <form onSubmit={handleAddPatientSubmit}>
              <div className="form-group">
                <label>Full Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. John Smith"
                  value={newPatient.fullname}
                  onChange={(e) => setNewPatient({ ...newPatient, fullname: e.target.value })}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                />
              </div>

              <div className="form-group">
                <label>Email Address</label>
                <input
                  type="email"
                  required
                  placeholder="patient@example.com"
                  value={newPatient.email}
                  onChange={(e) => setNewPatient({ ...newPatient, email: e.target.value })}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                />
              </div>

              <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label>Age</label>
                  <input
                    type="number"
                    value={newPatient.age}
                    onChange={(e) => setNewPatient({ ...newPatient, age: parseInt(e.target.value) || 60 })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>
                <div>
                  <label>Phone</label>
                  <input
                    type="text"
                    placeholder="+60..."
                    value={newPatient.phone}
                    onChange={(e) => setNewPatient({ ...newPatient, phone: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>
              </div>

              <div className="form-group">
                <label>Address</label>
                <input
                  type="text"
                  placeholder="Resident address..."
                  value={newPatient.address}
                  onChange={(e) => setNewPatient({ ...newPatient, address: e.target.value })}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)} style={{ flex: 1 }}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={formLoading} style={{ flex: 1 }}>
                  {formLoading ? 'Creating...' : 'Enroll Patient'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

// Patients.jsx
import React, { useState, useEffect } from 'react';
import {
  Users,
  Search,
  UserPlus,
  UserCheck,
  ShieldCheck,
  Eye,
  Edit,
  Trash2,
  UserX,
  X,
  Phone,
  Mail,
  MapPin,
  Pill,
  Calendar,
  FileText,
  AlertCircle,
  CheckCircle2,
  Loader2,
  Link,
  Unlink,
} from 'lucide-react';
import { apiService, BASE_URL, getPhotoUrl, handleImageError } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

// Helper to compute age from date string or object
const calculateAge = (dob) => {
  if (!dob) return 'N/A';
  try {
    const birthDate = new Date(dob);
    if (isNaN(birthDate.getTime())) return 'N/A';
    const difference = Date.now() - birthDate.getTime();
    const ageDate = new Date(difference);
    const age = Math.abs(ageDate.getUTCFullYear() - 1970);
    return isNaN(age) ? 'N/A' : age;
  } catch (e) {
    return 'N/A';
  }
};

const today = new Date();
const maxDate = new Date(today.setFullYear(today.getFullYear() - 60))
  .toISOString()
  .split('T')[0]; // e.g., "1966-07-27"
export default function Patients({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();

  const [myPatients, setMyPatients] = useState([]);
  const [availablePatients, setAvailablePatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCategory, setFilterCategory] = useState('my_patients'); // 'my_patients', 'available', 'all'

  // View Details Modal state
  const [selectedPatient, setSelectedPatient] = useState(null);
  const [patientMedications, setPatientMedications] = useState([]);

  // Add Patient Modal state
  const [showAddModal, setShowAddModal] = useState(false);
  const [newPatient, setNewPatient] = useState({
    fullname: '',
    email: '',
    password: 'Password123!',
    phone: '',
    address: '',
    date_of_birth: '',
    age: 65,
    caregiver_id: caregiverId,
  });

  // Edit Patient Modal state
  const [editingPatient, setEditingPatient] = useState(null);
  const [editForm, setEditForm] = useState({
    full_name: '',
    email: '',
    phone_no: '',
    date_of_birth: '',
    gender: 'Male',
    address: '',
    medical_notes: '',
  });

  // Action status state
  const [formError, setFormError] = useState('');
  const [formLoading, setFormLoading] = useState(false);
  const [actionSuccessMsg, setActionSuccessMsg] = useState('');

  const fetchAllPatientData = async (showSpinner = true) => {
    if (showSpinner) setLoading(true);
    try {
      const [myPats, availPats] = await Promise.all([
        apiService.getCaregiverPatients(caregiverId, 'all'),
        apiService.getAvailablePatients(caregiverId),
      ]);

      const taggedMyPats = (myPats || []).map((p) => ({ ...p, is_my_patient: true }));
      const taggedAvailPats = (availPats || []).map((p) => ({ ...p, is_my_patient: false }));

      setMyPatients(taggedMyPats);
      setAvailablePatients(taggedAvailPats);
    } catch (err) {
      console.error('Error fetching patients:', err);
    } finally {
      if (showSpinner) setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  useEffect(() => {
    fetchAllPatientData(true);
    const interval = setInterval(() => {
      fetchAllPatientData(false); // Silent background auto-reload without spinner
    }, 15000);
    return () => clearInterval(interval);
  }, [caregiverId]);

  useEffect(() => {
    if (isRefreshing) fetchAllPatientData(true);
  }, [isRefreshing]);

  // View patient details
  const handleViewPatient = async (patient) => {
    setSelectedPatient(patient);
    try {
      const pId = patient.id || patient.patient_id;
      const meds = await apiService.getPatientMedications(pId);
      setPatientMedications(meds || []);
    } catch (err) {
      setPatientMedications([]);
    }
  };

  // Link Patient to Caregiver
  const handleLinkPatient = async (patient) => {
    const pId = patient.id || patient.patient_id;
    const name = patient.fullname || patient.full_name || patient.name || 'this patient';

    setFormLoading(true);
    try {
      const res = await apiService.linkPatient(caregiverId, pId);
      if (res && res.success) {
        setActionSuccessMsg(`Patient "${name}" linked to your care list!`);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchAllPatientData();
      } else {
        alert(res?.message || 'Failed to link patient.');
      }
    } catch (err) {
      alert('An error occurred while linking patient.');
    } finally {
      setFormLoading(false);
    }
  };

  // Unlink Patient from Caregiver
  const handleUnlinkPatient = async (patient) => {
    const pId = patient.id || patient.patient_id;
    const name = patient.fullname || patient.full_name || patient.name || 'this patient';

    if (window.confirm(`Unlink "${name}" from your care list?\n\nThe patient account will remain active in the system.`)) {
      const success = await apiService.unlinkPatient(caregiverId, pId);
      if (success) {
        setActionSuccessMsg(`Patient "${name}" unlinked from your care.`);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        if (selectedPatient) setSelectedPatient(null);
        fetchAllPatientData();
      } else {
        alert('Failed to unlink patient.');
      }
    }
  };

  // Open Edit Modal
  const handleOpenEdit = (patient) => {
    setEditingPatient(patient);
    setEditForm({
      full_name: patient.fullname || patient.full_name || patient.name || '',
      email: patient.email || '',
      phone_no: patient.phone || patient.phone_no || '',
      date_of_birth: patient.date_of_birth || '',
      gender: patient.gender || 'Male',
      address: patient.address || '',
      medical_notes: patient.medical_notes || '',
    });
    setFormError('');
  };

  // Submit Edit Patient Form
  const handleEditPatientSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setFormLoading(true);

    try {
      const pId = editingPatient.id || editingPatient.patient_id;
      const res = await apiService.updatePatient(pId, editForm);

      if (res && (res.success || res.message)) {
        setActionSuccessMsg('Patient profile updated successfully!');
        setEditingPatient(null);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        fetchAllPatientData();
      } else {
        setFormError(res?.error || 'Failed to update patient profile.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred while updating.');
    } finally {
      setFormLoading(false);
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

      if (res && res.success) {
        setShowAddModal(false);
        setActionSuccessMsg('New patient enrolled successfully!');
        setTimeout(() => setActionSuccessMsg(''), 4000);
        setNewPatient({
          fullname: '',
          email: '',
          password: 'Password123!',
          phone: '',
          address: '',
          date_of_birth: '',
          age: 65,
          caregiver_id: caregiverId,
        });
        fetchAllPatientData();
      } else {
        setFormError(res?.error || 'Failed to create patient account.');
      }
    } catch (err) {
      setFormError(err.message || 'An error occurred.');
    } finally {
      setFormLoading(false);
    }
  };

  // Deactivate Patient Account (Soft Delete)
  const handleDeactivatePatient = async (patient) => {
    const pId = patient.id || patient.patient_id;
    const name = patient.fullname || patient.full_name || patient.name || 'this patient';

    if (window.confirm(`Deactivate account for "${name}"?\n\nThis will temporarily disable patient access while preserving medical records.`)) {
      const success = await apiService.deactivatePatient(pId);
      if (success) {
        setActionSuccessMsg(`Patient "${name}" deactivated.`);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        if (selectedPatient) setSelectedPatient(null);
        fetchAllPatientData();
      } else {
        alert('Failed to deactivate patient account.');
      }
    }
  };

  // Delete Patient Account Permanently (Hard Delete)
  const handleDeletePatientPermanent = async (patient) => {
    const pId = patient.id || patient.patient_id;
    const name = patient.fullname || patient.full_name || patient.name || 'this patient';

    if (window.confirm(`PERMANENTLY DELETE account for "${name}"?\n\nWARNING: This action CANNOT be undone. All prescriptions, device links, and adherence history will be deleted.`)) {
      const success = await apiService.deletePatient(pId, true);
      if (success) {
        setActionSuccessMsg(`Patient "${name}" permanently deleted.`);
        setTimeout(() => setActionSuccessMsg(''), 4000);
        if (selectedPatient) setSelectedPatient(null);
        fetchAllPatientData();
      } else {
        alert('Failed to delete patient account.');
      }
    }
  };

  // Reactivate Patient Account
  const handleReactivatePatient = async (patient) => {
    const pId = patient.id || patient.patient_id;
    const name = patient.fullname || patient.full_name || patient.name || 'this patient';

    if (window.confirm(`Activate account for "${name}"?\n\nThis will restore the patient's account to active status.`)) {
      setFormLoading(true);
      try {
        const success = await apiService.reactivatePatient(pId);
        if (success) {
          setActionSuccessMsg(`Patient "${name}" has been successfully activated!`);
          setTimeout(() => setActionSuccessMsg(''), 4000);
          if (selectedPatient && (selectedPatient.id === pId || selectedPatient.patient_id === pId)) {
            setSelectedPatient({ ...selectedPatient, is_active: 1 });
          }
          fetchAllPatientData();
        } else {
          alert('Failed to activate patient account.');
        }
      } catch (err) {
        alert('An error occurred while activating patient.');
      } finally {
        setFormLoading(false);
      }
    }
  };

  // Active patients assigned to me
  const myActivePatients = myPatients.filter(
    (p) => p.is_active !== false && p.is_active !== 0 && p.is_active !== '0'
  );

  // Available active patients (not assigned to me, and is_active == 1)
  const availableActivePatients = availablePatients.filter(
    (p) => p.is_active !== false && p.is_active !== 0 && p.is_active !== '0'
  );

  // All patients in the system (unique combination of myPatients + availablePatients)
  const getAllPatients = () => {
    const combined = [...myPatients];
    const myIds = new Set(myPatients.map((p) => p.id || p.patient_id));
    availablePatients.forEach((p) => {
      const id = p.id || p.patient_id;
      if (!myIds.has(id)) {
        combined.push(p);
      }
    });
    return combined;
  };
  const allPatients = getAllPatients();

  // Inactive patients across the entire system
  const inactivePatients = allPatients.filter(
    (p) => p.is_active === false || p.is_active === 0 || p.is_active === '0'
  );

  // Combine or filter patients based on category selection
  const getDisplayList = () => {
    if (filterCategory === 'my_patients') return myActivePatients;
    if (filterCategory === 'available') return availableActivePatients;
    if (filterCategory === 'inactive') return inactivePatients;
    return allPatients; // 'all'
  };

  const displayList = getDisplayList();

  // Filter patients by search query
  const filteredPatients = displayList.filter((p) => {
    const name = p.fullname || p.full_name || p.name || '';
    const email = p.email || '';
    const query = searchQuery.toLowerCase();
    return name.toLowerCase().includes(query) || email.toLowerCase().includes(query);
  });

  const showSpinner = loading || isRefreshing;

  return (
    <div style={{ position: 'relative', minHeight: '400px' }}>
      {/* Spinner overlay – shows during initial load or refresh */}
      {showSpinner && (
        <div className="loading-overlay">
          <Loader2 className="spinner" size={48} color="#6A4C93" />
          <p style={{ marginTop: '12px', color: '#6B7280', fontWeight: 500 }}>
            {loading ? 'Loading patient directory...' : 'Refreshing...'}
          </p>
        </div>
      )}

      {/* Main content – dimmed when spinner is visible */}
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

        {/* Action & Filter Bar */}
        <div className="glass-card" style={{ padding: '20px', marginBottom: '24px', background: 'white' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
            {/* Search Box */}
            <div className="search-box" style={{ width: '300px' }}>
              <Search size={18} />
              <input
                type="text"
                placeholder="Search by name or email..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            {/* Category Filter Tabs */}
            <div
              style={{
                display: 'flex',
                background: '#F1F5F9',
                padding: '4px',
                borderRadius: '12px',
                border: '1px solid #E2E8F0',
                gap: '4px',
                flexWrap: 'wrap',
              }}
            >
              <button
                onClick={() => setFilterCategory('my_patients')}
                style={{
                  padding: '8px 16px',
                  fontSize: '0.82rem',
                  fontWeight: '700',
                  border: 'none',
                  borderRadius: '9px',
                  background: filterCategory === 'my_patients' ? '#6A4C93' : 'transparent',
                  color: filterCategory === 'my_patients' ? 'white' : '#64748B',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                }}
              >
                My Patients ({myActivePatients.length})
              </button>
              <button
                onClick={() => setFilterCategory('available')}
                style={{
                  padding: '8px 16px',
                  fontSize: '0.82rem',
                  fontWeight: '700',
                  border: 'none',
                  borderRadius: '9px',
                  background: filterCategory === 'available' ? '#6A4C93' : 'transparent',
                  color: filterCategory === 'available' ? 'white' : '#64748B',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                }}
              >
                Available Active Patients ({availableActivePatients.length})
              </button>
              <button
                onClick={() => setFilterCategory('inactive')}
                style={{
                  padding: '8px 16px',
                  fontSize: '0.82rem',
                  fontWeight: '700',
                  border: 'none',
                  borderRadius: '9px',
                  background: filterCategory === 'inactive' ? '#6A4C93' : 'transparent',
                  color: filterCategory === 'inactive' ? 'white' : '#64748B',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                }}
              >
                Inactive Patients ({inactivePatients.length})
              </button>
              <button
                onClick={() => setFilterCategory('all')}
                style={{
                  padding: '8px 16px',
                  fontSize: '0.82rem',
                  fontWeight: '700',
                  border: 'none',
                  borderRadius: '9px',
                  background: filterCategory === 'all' ? '#6A4C93' : 'transparent',
                  color: filterCategory === 'all' ? 'white' : '#64748B',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                }}
              >
                All System Patients ({allPatients.length})
              </button>
            </div>

            <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
              <UserPlus size={18} />
              <span>Add New Patient</span>
            </button>
          </div>
        </div>

        {/* Patient Cards Grid */}
        {filteredPatients.length === 0 ? (
          <div className="glass-card" style={{ padding: '40px', textAlign: 'center', background: 'white' }}>
            <Users size={48} color="#94A3B8" style={{ margin: '0 auto 12px auto', display: 'block' }} />
            <h3 style={{ color: '#2D3142' }}>No Patients Found</h3>
            <p style={{ color: '#6B7280', fontSize: '0.9rem', marginTop: '4px' }}>
              {searchQuery
                ? 'No patients matched your search criteria.'
                : filterCategory === 'available'
                  ? 'No unassigned active patients found in system.'
                  : filterCategory === 'inactive'
                    ? 'No inactive or deactivated patients found in system.'
                    : filterCategory === 'my_patients'
                      ? 'No active patients currently assigned to your care.'
                      : 'Click "Add New Patient" to enroll a patient.'}
            </p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
            {filteredPatients.map((patient) => {
              const name = patient.fullname || patient.full_name || patient.name || 'Patient Name';
              const pId = patient.id || patient.patient_id;
              const ageDisplay = patient.age && patient.age !== 'N/A'
                ? patient.age
                : calculateAge(patient.date_of_birth);
              const phoneDisplay = patient.phone || patient.phone_no;
              const isActive = patient.is_active !== false && patient.is_active !== 0;
              const isMyPatient = patient.is_my_patient === true;

              return (
                <div
                  key={pId}
                  className="glass-card"
                  style={{
                    padding: '20px',
                    background: 'white',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    opacity: 1,
                    border: isActive ? '1px solid #E2E8F0' : '1px solid #FECACA',
                    borderLeft: isMyPatient
                      ? '4px solid #6A4C93'
                      : '4px solid #3B82F6',
                    boxShadow: isActive ? '0 1px 3px rgba(0,0,0,0.05)' : '0 1px 4px rgba(239, 68, 68, 0.08)',
                  }}
                >
                  <div>
                    {/* Top Header Row with Status Badges */}
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px', gap: '8px' }}>
                      {isMyPatient ? (
                        <span className="badge badge-purple" style={{ fontSize: '0.72rem', display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <ShieldCheck size={13} />
                          Assigned to My Care
                        </span>
                      ) : (
                        <span className="badge badge-info" style={{ fontSize: '0.72rem', display: 'flex', alignItems: 'center', gap: '4px', background: '#DBEAFE', color: '#1D4ED8' }}>
                          <UserPlus size={13} />
                          {patient.assignment_status || 'Unassigned / Available'}
                        </span>
                      )}

                      {!isActive ? (
                        <span className="badge" style={{ fontSize: '0.72rem', background: '#FEE2E2', color: '#B91C1C', border: '1px solid #FCA5A5', fontWeight: '700' }}>
                          Inactive
                        </span>
                      ) : (
                        <span className="badge" style={{ fontSize: '0.72rem', background: '#DCFCE7', color: '#15803D', border: '1px solid #86EFAC', fontWeight: '700' }}>
                          Active
                        </span>
                      )}
                    </div>

                    {/* Patient Name & Avatar */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' }}>
                      {getPhotoUrl(patient.profile_photo) ? (
                        <img
                          src={getPhotoUrl(patient.profile_photo)}
                          alt={name}
                          style={{
                            width: '48px',
                            height: '48px',
                            borderRadius: '50%',
                            objectFit: 'cover',
                            border: isMyPatient ? '2px solid #6A4C93' : '2px solid #3B82F6',
                            flexShrink: 0,
                            boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                          }}
                          onError={(e) => handleImageError(e, patient.profile_photo)}
                        />
                      ) : null}

                      <div style={{
                        width: '48px',
                        height: '48px',
                        borderRadius: '50%',
                        background: isMyPatient
                          ? 'linear-gradient(135deg, #3B1E54 0%, #6A4C93 100%)'
                          : 'linear-gradient(135deg, #1E3A8A 0%, #3B82F6 100%)',
                        color: 'white',
                        display: getPhotoUrl(patient.profile_photo) ? 'none' : 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontWeight: '700',
                        fontSize: '1.2rem',
                        flexShrink: 0,
                      }}>
                        {name.charAt(0).toUpperCase()}
                      </div>

                      <div style={{ flex: 1, overflow: 'hidden' }}>
                        <h3 style={{ fontSize: '1.05rem', color: '#2D3142', fontWeight: '700', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                          {name}
                        </h3>
                        <div style={{ fontSize: '0.8rem', color: '#64748B' }}>
                          ID: #{pId} • Age: {ageDisplay}
                        </div>
                      </div>
                    </div>

                    {/* Contact Info */}
                    <div style={{ fontSize: '0.85rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '16px' }}>
                      {patient.email && (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <Mail size={14} color={isMyPatient ? '#6A4C93' : '#3B82F6'} />
                          <span style={{ textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>{patient.email}</span>
                        </div>
                      )}
                      {phoneDisplay && (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <Phone size={14} color={isMyPatient ? '#6A4C93' : '#3B82F6'} />
                          <span>{phoneDisplay}</span>
                        </div>
                      )}
                      {patient.address && (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <MapPin size={14} color={isMyPatient ? '#6A4C93' : '#3B82F6'} />
                          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{patient.address}</span>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Card Action Buttons */}
                  <div style={{ display: 'flex', gap: '6px', paddingTop: '14px', borderTop: '1px solid #E2E8F0', alignItems: 'center' }}>
                    <button
                      className="btn btn-outline"
                      style={{ flex: 1, padding: '7px 8px', fontSize: '0.8rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '4px' }}
                      onClick={() => handleViewPatient(patient)}
                    >
                      <Eye size={14} />
                      <span>View</span>
                    </button>

                    <button
                      className="btn"
                      style={{ padding: '7px 8px', fontSize: '0.8rem', background: '#F1F5F9', color: '#334155', border: '1px solid #CBD5E1', display: 'flex', alignItems: 'center', gap: '4px' }}
                      onClick={() => handleOpenEdit(patient)}
                      title="Edit Patient Details"
                    >
                      <Edit size={14} />
                      <span>Edit</span>
                    </button>

                    {/* Caregiver Assignment Action: Link or Unlink */}
                    {isMyPatient ? (
                      <button
                        className="btn"
                        style={{ padding: '7px 8px', background: '#FEF3C7', color: '#D97706', border: '1px solid #FCD34D' }}
                        onClick={() => handleUnlinkPatient(patient)}
                        title="Unlink from My Care List"
                      >
                        <Unlink size={14} />
                      </button>
                    ) : (
                      <button
                        className="btn"
                        style={{ padding: '7px 8px', background: '#6A4C93', color: 'white', border: 'none', fontSize: '0.78rem', fontWeight: '600' }}
                        onClick={() => handleLinkPatient(patient)}
                        title="Link Patient to My Care List"
                        disabled={formLoading}
                      >
                        <UserCheck size={14} />
                      </button>
                    )}

                    {/* Account Lifecycle Actions: Deactivate or Reactivate/Activate */}
                    {!isActive ? (
                      <button
                        className="btn"
                        style={{
                          padding: '7px 10px',
                          background: '#10B981',
                          color: 'white',
                          border: 'none',
                          fontSize: '0.78rem',
                          fontWeight: '700',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                        }}
                        onClick={() => handleReactivatePatient(patient)}
                        title="Activate Patient Account"
                        disabled={formLoading}
                      >
                        <UserCheck size={14} />
                        <span>Activate</span>
                      </button>
                    ) : (
                      <button
                        className="btn"
                        style={{ padding: '7px 8px', background: '#F8FAFC', color: '#64748B', border: '1px solid #E2E8F0' }}
                        onClick={() => handleDeactivatePatient(patient)}
                        title="Deactivate Patient Account"
                      >
                        <UserX size={14} />
                      </button>
                    )}

                    <button
                      className="btn btn-secondary"
                      style={{ padding: '7px 8px', color: '#EF4444', background: '#FEE2E2', border: '1px solid #FCA5A5' }}
                      onClick={() => handleDeletePatientPermanent(patient)}
                      title="Delete Account Permanently"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* View Patient Details Modal */}
        {selectedPatient && (
          <div className="modal-overlay" onClick={() => setSelectedPatient(null)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '520px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142' }}>Patient Profile & Details</h3>
                <button
                  onClick={() => setSelectedPatient(null)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}
                >
                  <X size={20} />
                </button>
              </div>

              <div style={{ display: 'flex', gap: '16px', alignItems: 'center', marginBottom: '20px' }}>
                <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: selectedPatient.is_my_patient ? '#6A4C93' : '#3B82F6', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.6rem', fontWeight: '700', flexShrink: 0 }}>
                  {(selectedPatient.fullname || selectedPatient.full_name || selectedPatient.name || 'P').charAt(0).toUpperCase()}
                </div>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <h4 style={{ fontSize: '1.2rem', color: '#2D3142', fontWeight: '700' }}>
                      {selectedPatient.fullname || selectedPatient.full_name || selectedPatient.name}
                    </h4>
                    {selectedPatient.is_my_patient ? (
                      <span className="badge badge-purple" style={{ fontSize: '0.7rem' }}>Under My Care</span>
                    ) : (
                      <span className="badge badge-info" style={{ fontSize: '0.7rem' }}>{selectedPatient.assignment_status || 'Available'}</span>
                    )}
                  </div>
                  <div style={{ fontSize: '0.85rem', color: '#64748B', marginTop: '2px' }}>
                    Patient ID: #{selectedPatient.id || selectedPatient.patient_id} • Age: {selectedPatient.age && selectedPatient.age !== 'N/A' ? selectedPatient.age : calculateAge(selectedPatient.date_of_birth)}
                  </div>
                </div>
              </div>

              {/* Profile Field Details Grid */}
              <div style={{ background: '#F8FAFC', padding: '16px', borderRadius: '12px', marginBottom: '20px', display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '0.88rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: '#64748B', fontWeight: '600' }}>Email:</span>
                  <span style={{ color: '#2D3142', fontWeight: '600' }}>{selectedPatient.email || 'N/A'}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: '#64748B', fontWeight: '600' }}>Phone:</span>
                  <span style={{ color: '#2D3142', fontWeight: '600' }}>{selectedPatient.phone || selectedPatient.phone_no || 'N/A'}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: '#64748B', fontWeight: '600' }}>Gender:</span>
                  <span style={{ color: '#2D3142', fontWeight: '600' }}>{selectedPatient.gender || 'N/A'}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: '#64748B', fontWeight: '600' }}>Date of Birth:</span>
                  <span style={{ color: '#2D3142', fontWeight: '600' }}>{selectedPatient.date_of_birth || 'N/A'}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: '#64748B', fontWeight: '600' }}>Address:</span>
                  <span style={{ color: '#2D3142', fontWeight: '600', maxWidth: '240px', textAlign: 'right' }}>{selectedPatient.address || 'N/A'}</span>
                </div>
                {selectedPatient.medical_notes && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', marginTop: '6px', paddingTop: '8px', borderTop: '1px solid #E2E8F0' }}>
                    <span style={{ color: '#64748B', fontWeight: '600' }}>Medical Notes:</span>
                    <span style={{ color: '#2D3142', fontStyle: 'italic' }}>{selectedPatient.medical_notes}</span>
                  </div>
                )}
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
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '20px', maxHeight: '200px', overflowY: 'auto' }}>
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

              <div style={{ display: 'flex', gap: '10px', marginTop: '16px' }}>
                {(selectedPatient.is_active === false || selectedPatient.is_active === 0) && (
                  <button
                    className="btn"
                    onClick={() => handleReactivatePatient(selectedPatient)}
                    style={{ flex: 1, background: '#10B981', color: 'white', border: 'none', fontWeight: '700', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
                  >
                    <UserCheck size={16} />
                    <span>Activate Patient</span>
                  </button>
                )}
                <button
                  className="btn"
                  onClick={() => {
                    const p = selectedPatient;
                    setSelectedPatient(null);
                    handleOpenEdit(p);
                  }}
                  style={{ flex: 1, background: '#F3E8FF', color: '#6A4C93', border: '1px solid #D8B4FE', fontWeight: '600' }}
                >
                  <Edit size={16} />
                  <span>Edit Profile</span>
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={() => setSelectedPatient(null)}
                  style={{ flex: 1 }}
                >
                  Close Profile
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Edit Patient Details Modal */}
        {editingPatient && (
          <div className="modal-overlay" onClick={() => setEditingPatient(null)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '520px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Edit size={20} color="#6A4C93" />
                  Edit Patient Profile
                </h3>
                <button onClick={() => setEditingPatient(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}>
                  <X size={20} />
                </button>
              </div>

              {formError && (
                <div style={{ padding: '10px', background: '#FEE2E2', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                  {formError}
                </div>
              )}

              <form onSubmit={handleEditPatientSubmit}>
                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Full Name</label>
                  <input
                    type="text"
                    required
                    value={editForm.full_name}
                    onChange={(e) => setEditForm({ ...editForm, full_name: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>

                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Email Address</label>
                  <input
                    type="email"
                    required
                    value={editForm.email}
                    onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>

                <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Phone Number</label>
                    <input
                      type="text"
                      placeholder="+60..."
                      value={editForm.phone_no}
                      onChange={(e) => setEditForm({ ...editForm, phone_no: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Gender</label>
                    <select
                      value={editForm.gender}
                      onChange={(e) => setEditForm({ ...editForm, gender: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', background: 'white' }}
                    >
                      <option value="Male">Male</option>
                      <option value="Female">Female</option>
                      <option value="Other">Other</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Date of Birth</label>
                  <input
                    type="date"
                    value={editForm.date_of_birth}
                    onChange={(e) => setEditForm({ ...editForm, date_of_birth: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    max={maxDate}   // <-- add this
                  />
                </div>

                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Address</label>
                  <input
                    type="text"
                    placeholder="Resident address..."
                    value={editForm.address}
                    onChange={(e) => setEditForm({ ...editForm, address: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                  />
                </div>

                <div className="form-group">
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Medical Notes / Care Instructions</label>
                  <textarea
                    rows="3"
                    placeholder="Allergies, chronic conditions..."
                    value={editForm.medical_notes}
                    onChange={(e) => setEditForm({ ...editForm, medical_notes: e.target.value })}
                    style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1', fontFamily: 'inherit' }}
                  />
                </div>

                <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setEditingPatient(null)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={formLoading} style={{ flex: 1 }}>
                    {formLoading ? 'Saving...' : 'Save Changes'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Add New Patient Modal */}
        {showAddModal && (
          <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '520px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142' }}>Enroll New Patient</h3>
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
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Full Name</label>
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
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Email Address</label>
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
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Date of Birth</label>
                    <input
                      type="date"
                      value={newPatient.date_of_birth}
                      onChange={(e) => setNewPatient({ ...newPatient, date_of_birth: e.target.value })}
                      style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #CBD5E1' }}
                    />
                  </div>
                  <div>
                    <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Phone Number</label>
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
                  <label style={{ fontWeight: '600', fontSize: '0.85rem', color: '#475569' }}>Address</label>
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
                    {formLoading ? 'Enrolling...' : 'Enroll Patient'}
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

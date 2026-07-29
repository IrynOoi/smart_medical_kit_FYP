// Profile.jsx
import React, { useState, useEffect } from 'react';
import {
  User,
  Mail,
  Phone,
  MapPin,
  Calendar,
  Shield,
  AlertTriangle,
  UserX,
  Trash2,
  CheckCircle2,
  Loader2,
  Edit,
  Camera,
  X,
  Venus,
  Upload,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { apiService, BASE_URL, getPhotoUrl, handleImageError } from '../services/apiService';

export default function Profile() {
  const { user, caregiverId, logout, updateUser } = useAuth();
  const [profileData, setProfileData] = useState(null);
  const [loading, setLoading] = useState(true);

  // Modals
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeactivateModal, setShowDeactivateModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Edit Form State
  const [editForm, setEditForm] = useState({
    full_name: '',
    email: '',
    phone_no: '',
    gender: 'Male',
    date_of_birth: '',
    address: '',
  });
  const [selectedPhotoFile, setSelectedPhotoFile] = useState(null);
  const [photoPreviewUrl, setPhotoPreviewUrl] = useState('');

  const fetchProfileDetails = async (showSpinner = true) => {
    if (showSpinner) setLoading(true);
    try {
      if (caregiverId) {
        const res = await apiService.getCaregiverProfile(caregiverId);
        if (res && res.success && res.data) {
          setProfileData(res.data);
          if (updateUser) updateUser(res.data);
        } else if (user) {
          setProfileData(user);
        }
      } else if (user) {
        setProfileData(user);
      }
    } catch (err) {
      console.error('Error fetching caregiver profile:', err);
    } finally {
      if (showSpinner) setLoading(false);
    }
  };

  useEffect(() => {
    fetchProfileDetails(true);
    const interval = setInterval(() => {
      fetchProfileDetails(false); // Silent background auto-reload without spinner
    }, 15000);
    return () => clearInterval(interval);
  }, [caregiverId]);

  const profile = profileData || user || {};

  // Safely resolve photo URL with fallback
  const getPhotoUrl = (photoPath) => {
    if (!photoPath) return null;

    let cleanPath = photoPath;
    if (typeof cleanPath === 'string' && cleanPath.includes('/static/profiles/')) {
      const filename = cleanPath.split('/static/profiles/')[1];
      cleanPath = `/static/profiles/${filename}`;
    }

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return cleanPath;
    }

    const base = BASE_URL.endsWith('/') ? BASE_URL.slice(0, -1) : BASE_URL;
    const path = cleanPath.startsWith('/') ? cleanPath : `/${cleanPath}`;
    return `${base}${path}`;
  };

  const extractFilename = (photoPath) => {
    if (!photoPath || typeof photoPath !== 'string') return null;
    if (photoPath.includes('/static/profiles/')) {
      return photoPath.split('/static/profiles/')[1];
    }
    return photoPath.split('/').pop();
  };

  const handleImageError = (e, photoPath) => {
    const filename = extractFilename(photoPath);
    if (filename && !e.target.dataset.triedLocal) {
      e.target.dataset.triedLocal = 'true';
      e.target.src = `http://localhost:5000/static/profiles/${filename}`;
    } else {
      e.target.style.display = 'none';
      if (e.target.nextSibling) {
        e.target.nextSibling.style.display = 'flex';
      }
    }
  };

  const currentPhotoUrl = getPhotoUrl(profile.profile_photo);

  const handleOpenEdit = () => {
    setEditForm({
      full_name: profile.full_name || profile.fullname || profile.name || '',
      email: profile.email || '',
      phone_no: profile.phone_no || profile.phone || '',
      gender: profile.gender || 'Female',
      date_of_birth: profile.date_of_birth ? profile.date_of_birth.substring(0, 10) : '',
      address: profile.address || '',
    });
    setSelectedPhotoFile(null);
    setPhotoPreviewUrl(currentPhotoUrl || '');
    setErrorMsg('');
    setSuccessMsg('');
    setShowEditModal(true);
  };

  const handlePhotoFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setSelectedPhotoFile(file);
      setPhotoPreviewUrl(URL.createObjectURL(file));
    }
  };

  const handleSaveProfile = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    setErrorMsg('');
    setSuccessMsg('');

    try {
      const activeId = caregiverId || profile.user_id || profile.caregiver_id;
      if (!activeId) {
        setErrorMsg('Caregiver ID missing. Cannot update profile.');
        setActionLoading(false);
        return;
      }

      if (!editForm.full_name || !editForm.email || !editForm.phone_no || !editForm.gender || !editForm.date_of_birth || !editForm.address) {
        setErrorMsg('All profile fields are compulsory and must be filled in.');
        setActionLoading(false);
        return;
      }

      if (editForm.date_of_birth) {
        const birthDate = new Date(editForm.date_of_birth);
        const today = new Date();
        let age = today.getFullYear() - birthDate.getFullYear();
        const m = today.getMonth() - birthDate.getMonth();
        if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
          age--;
        }
        if (age < 18) {
          setErrorMsg('Caregiver must be at least 18 years old.');
          setActionLoading(false);
          return;
        }
      }

      let res;
      if (selectedPhotoFile) {
        const formData = new FormData();
        formData.append('full_name', editForm.full_name);
        formData.append('email', editForm.email);
        formData.append('phone_no', editForm.phone_no);
        formData.append('gender', editForm.gender);
        formData.append('date_of_birth', editForm.date_of_birth);
        formData.append('address', editForm.address);
        formData.append('profile_photo', selectedPhotoFile);

        res = await apiService.updateCaregiverProfile(activeId, formData);
      } else {
        res = await apiService.updateCaregiverProfile(activeId, {
          ...editForm,
          profile_photo: profile.profile_photo,
        });
      }

      if (res && res.success) {
        setSuccessMsg('Profile updated successfully!');
        const updatedObj = res.data || { ...profile, ...editForm };
        setProfileData(updatedObj);
        if (updateUser) updateUser(updatedObj);
        setTimeout(() => {
          setShowEditModal(false);
        }, 1000);
      } else {
        setErrorMsg(res?.error || res?.message || 'Failed to update profile.');
      }
    } catch (err) {
      console.error('Update profile error:', err);
      setErrorMsg('An error occurred while updating profile.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeactivate = async () => {
    setActionLoading(true);
    setErrorMsg('');
    try {
      const success = await apiService.deactivateCaregiver(caregiverId || user?.user_id);
      if (success) {
        alert('Your account has been deactivated successfully.');
        logout();
      } else {
        setErrorMsg('Failed to deactivate account. Please try again.');
      }
    } catch (err) {
      setErrorMsg('An error occurred during account deactivation.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteAccount = async () => {
    setActionLoading(true);
    setErrorMsg('');
    try {
      const success = await apiService.deleteCaregiverAccount(caregiverId || user?.user_id);
      if (success) {
        alert('Your account has been permanently deleted.');
        logout();
      } else {
        setErrorMsg('Failed to delete account. Please check backend log.');
      }
    } catch (err) {
      setErrorMsg('An error occurred while deleting your account.');
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div style={{ position: 'relative', minHeight: '400px', maxWidth: '840px', margin: '0 auto', paddingBottom: '40px' }}>
      {/* Spinner overlay */}
      {loading && (
        <div className="loading-overlay">
          <Loader2 className="spinner" size={48} color="#6A4C93" />
          <p style={{ marginTop: '12px', color: '#6B7280', fontWeight: 500 }}>
            Loading profile details...
          </p>
        </div>
      )}

      {/* Main content */}
      <div style={{ opacity: loading ? 0.4 : 1, transition: 'opacity 0.2s' }}>

        {/* Profile Banner Card (Inspired by Mobile App Design) */}
        <div
          style={{
            background: 'linear-gradient(135deg, #5B328E 0%, #3B1E54 100%)',
            borderRadius: '24px',
            padding: '36px',
            color: 'white',
            marginBottom: '24px',
            boxShadow: '0 12px 32px rgba(91, 50, 142, 0.25)',
            position: 'relative',
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>

            {/* Circular Profile Avatar */}
            <div style={{ position: 'relative', width: '104px', height: '104px', marginBottom: '16px' }}>
              {currentPhotoUrl ? (
                <img
                  src={currentPhotoUrl}
                  alt="Caregiver Profile"
                  onError={(e) => handleImageError(e, profile.profile_photo)}
                  style={{
                    width: '104px',
                    height: '104px',
                    borderRadius: '50%',
                    objectFit: 'cover',
                    border: '4px solid rgba(255, 255, 255, 0.9)',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
                  }}
                />
              ) : null}

              <div
                style={{
                  display: currentPhotoUrl ? 'none' : 'flex',
                  width: '104px',
                  height: '104px',
                  borderRadius: '50%',
                  background: 'rgba(255, 255, 255, 0.2)',
                  backdropFilter: 'blur(10px)',
                  color: 'white',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '2.8rem',
                  fontWeight: '800',
                  border: '4px solid rgba(255, 255, 255, 0.9)',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
                }}
              >
                {profile.full_name || profile.fullname || profile.name ? (profile.full_name || profile.fullname || profile.name).charAt(0).toUpperCase() : 'C'}
              </div>

              <button
                onClick={handleOpenEdit}
                title="Update Profile Photo"
                style={{
                  position: 'absolute',
                  bottom: '2px',
                  right: '2px',
                  width: '34px',
                  height: '34px',
                  borderRadius: '50%',
                  background: '#FFFFFF',
                  color: '#5B328E',
                  border: 'none',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  boxShadow: '0 4px 10px rgba(0,0,0,0.25)',
                  transition: 'transform 0.2s ease',
                }}
              >
                <Camera size={18} />
              </button>
            </div>

            {/* Profile Name & Badges */}
            <h2 style={{ fontSize: '1.8rem', fontWeight: '800', color: 'white', marginBottom: '8px' }}>
              {profile.full_name || profile.fullname || profile.name || 'Caregiver User'}
            </h2>

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '20px' }}>
              <span
                style={{
                  background: 'rgba(255, 255, 255, 0.2)',
                  padding: '6px 14px',
                  borderRadius: '20px',
                  fontSize: '0.78rem',
                  fontWeight: '700',
                  letterSpacing: '0.8px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                }}
              >
                <Shield size={14} />
                {profile.role ? profile.role.toUpperCase() : 'CAREGIVER'}
              </span>

              <span
                style={{
                  background: '#10B981',
                  color: 'white',
                  padding: '6px 14px',
                  borderRadius: '20px',
                  fontSize: '0.78rem',
                  fontWeight: '700',
                  letterSpacing: '0.8px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                }}
              >
                <CheckCircle2 size={14} />
                ACTIVE
              </span>
            </div>

            {/* Edit Profile Action Button */}
            <button
              onClick={handleOpenEdit}
              style={{
                background: 'rgba(255, 255, 255, 0.18)',
                backdropFilter: 'blur(10px)',
                color: 'white',
                border: '1.5px solid rgba(255, 255, 255, 0.4)',
                padding: '10px 24px',
                borderRadius: '14px',
                fontSize: '0.9rem',
                fontWeight: '600',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                transition: 'all 0.2s ease',
              }}
            >
              <Edit size={16} />
              <span>Edit Personal Details</span>
            </button>

          </div>
        </div>

        {/* Contact Details Card (Structured like Flutter App) */}
        <div className="glass-card" style={{ padding: '24px 28px', background: 'white', borderRadius: '20px', marginBottom: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
            <h3 style={{ fontSize: '1.1rem', fontWeight: '700', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{ padding: '8px', background: '#F3E8FF', borderRadius: '10px', color: '#6A4C93' }}>
                <Mail size={18} />
              </div>
              Contact Details
            </h3>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '12px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #F1F5F9' }}>
              <Mail size={20} color="#6A4C93" />
              <div>
                <div style={{ fontSize: '0.75rem', color: '#94A3B8', fontWeight: '700' }}>EMAIL ADDRESS</div>
                <div style={{ fontSize: '0.95rem', color: '#1E293B', fontWeight: '700', marginTop: '2px' }}>{profile.email || 'N/A'}</div>
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '12px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #F1F5F9' }}>
              <Phone size={20} color="#6A4C93" />
              <div>
                <div style={{ fontSize: '0.75rem', color: '#94A3B8', fontWeight: '700' }}>MOBILE NUMBER</div>
                <div style={{ fontSize: '0.95rem', color: '#1E293B', fontWeight: '700', marginTop: '2px' }}>{profile.phone_no || profile.phone || 'N/A'}</div>
              </div>
            </div>
          </div>
        </div>

        {/* Personal Info Card (Structured like Flutter App) */}
        <div className="glass-card" style={{ padding: '24px 28px', background: 'white', borderRadius: '20px', marginBottom: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
            <h3 style={{ fontSize: '1.1rem', fontWeight: '700', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{ padding: '8px', background: '#F3E8FF', borderRadius: '10px', color: '#6A4C93' }}>
                <User size={18} />
              </div>
              Personal Info
            </h3>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '12px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #F1F5F9' }}>
              <Venus size={20} color="#6A4C93" />
              <div>
                <div style={{ fontSize: '0.75rem', color: '#94A3B8', fontWeight: '700' }}>GENDER</div>
                <div style={{ fontSize: '0.95rem', color: '#1E293B', fontWeight: '700', marginTop: '2px' }}>{profile.gender || 'N/A'}</div>
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '12px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #F1F5F9' }}>
              <Calendar size={20} color="#6A4C93" />
              <div>
                <div style={{ fontSize: '0.75rem', color: '#94A3B8', fontWeight: '700' }}>DATE OF BIRTH</div>
                <div style={{ fontSize: '0.95rem', color: '#1E293B', fontWeight: '700', marginTop: '2px' }}>
                  {profile.date_of_birth ? profile.date_of_birth.substring(0, 10) : 'N/A'}
                </div>
              </div>
            </div>

            <div style={{ gridColumn: '1 / -1', display: 'flex', alignItems: 'center', gap: '16px', padding: '12px 16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #F1F5F9' }}>
              <MapPin size={20} color="#6A4C93" />
              <div>
                <div style={{ fontSize: '0.75rem', color: '#94A3B8', fontWeight: '700' }}>ADDRESS</div>
                <div style={{ fontSize: '0.95rem', color: '#1E293B', fontWeight: '700', marginTop: '2px' }}>{profile.address || 'N/A'}</div>
              </div>
            </div>
          </div>
        </div>

        {/* Danger Zone */}
        <div style={{ padding: '24px', background: '#FFF5F5', border: '1px solid #FEE2E2', borderRadius: '20px' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: '700', color: '#991B1B', marginBottom: '6px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <AlertTriangle size={20} color="#EF4444" />
            Account Actions & Danger Zone
          </h3>
          <p style={{ fontSize: '0.85rem', color: '#7F1D1D', marginBottom: '16px' }}>
            Manage your account lifecycle. Deactivating disables portal access temporarily.
          </p>

          <div style={{ display: 'flex', gap: '14px', flexWrap: 'wrap' }}>
            <button
              onClick={() => setShowDeactivateModal(true)}
              style={{
                background: '#FFF',
                border: '1.5px solid #F59E0B',
                color: '#D97706',
                fontWeight: '600',
                padding: '9px 16px',
                borderRadius: '10px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                cursor: 'pointer',
                fontSize: '0.88rem',
              }}
            >
              <UserX size={16} />
              <span>Deactivate Account</span>
            </button>

            <button
              className="btn btn-danger"
              onClick={() => setShowDeleteModal(true)}
              style={{ padding: '9px 16px', borderRadius: '10px', fontSize: '0.88rem' }}
            >
              <Trash2 size={16} />
              <span>Delete Account Permanently</span>
            </button>
          </div>
        </div>

        {/* Edit Profile Modal (Redesigned & Improvised UI) */}
        {showEditModal && (
          <div className="modal-overlay" onClick={() => setShowEditModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '580px', width: '92%' }}>

              {/* Modal Header */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', paddingBottom: '14px', borderBottom: '1px solid #F1F5F9' }}>
                <h3 style={{ fontSize: '1.3rem', fontWeight: '800', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{ padding: '8px', background: '#F3E8FF', borderRadius: '10px', color: '#6A4C93' }}>
                    <Edit size={20} />
                  </div>
                  Edit Caregiver Profile
                </h3>
                <button
                  onClick={() => setShowEditModal(false)}
                  style={{ background: '#F1F5F9', border: 'none', borderRadius: '50%', width: '32px', height: '32px', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: '#64748B' }}
                >
                  <X size={18} />
                </button>
              </div>

              {errorMsg && (
                <div style={{ padding: '12px 16px', background: '#FEE2E2', border: '1px solid #EF4444', borderRadius: '10px', color: '#991B1B', marginBottom: '20px', fontSize: '0.88rem' }}>
                  {errorMsg}
                </div>
              )}

              {successMsg && (
                <div style={{ padding: '12px 16px', background: '#D1FAE5', border: '1px solid #10B981', borderRadius: '10px', color: '#065F46', marginBottom: '20px', fontSize: '0.88rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <CheckCircle2 size={18} color="#10B981" />
                  {successMsg}
                </div>
              )}

              <form onSubmit={handleSaveProfile}>

                {/* Photo Upload Section (Custom UI Box) */}
                <div style={{ padding: '18px', background: '#F8FAFC', borderRadius: '16px', border: '1.5px solid #E2E8F0', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '20px' }}>
                  <div style={{ position: 'relative', width: '76px', height: '76px', borderRadius: '50%', overflow: 'hidden', flexShrink: 0, background: '#E2E8F0', border: '3px solid white', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}>
                    {photoPreviewUrl ? (
                      <img
                        src={photoPreviewUrl}
                        alt="Profile Preview"
                        onError={(e) => handleImageError(e, profile.profile_photo)}
                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                      />
                    ) : (
                      <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#6A4C93', color: 'white', fontSize: '1.8rem', fontWeight: '700' }}>
                        {editForm.full_name ? editForm.full_name.charAt(0).toUpperCase() : 'C'}
                      </div>
                    )}
                  </div>

                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: '700', fontSize: '0.92rem', color: '#1E293B', marginBottom: '4px' }}>
                      Profile Picture
                    </div>
                    <div style={{ fontSize: '0.8rem', color: '#64748B', marginBottom: '10px' }}>
                      PNG or JPG format up to 5MB.
                    </div>
                    <label
                      htmlFor="modal-photo-upload"
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '8px',
                        padding: '8px 16px',
                        background: '#FFFFFF',
                        border: '1.5px solid #CBD5E1',
                        borderRadius: '10px',
                        fontSize: '0.85rem',
                        fontWeight: '600',
                        color: '#475569',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                      }}
                    >
                      <Upload size={14} color="#6A4C93" />
                      <span>{selectedPhotoFile ? selectedPhotoFile.name : 'Choose File'}</span>
                    </label>
                    <input
                      id="modal-photo-upload"
                      type="file"
                      accept="image/*"
                      onChange={handlePhotoFileChange}
                      style={{ display: 'none' }}
                    />
                  </div>
                </div>

                {/* Form Controls Grid */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Full Name *</label>
                    <input
                      type="text"
                      className="form-control"
                      value={editForm.full_name}
                      onChange={(e) => setEditForm({ ...editForm, full_name: e.target.value })}
                      required
                      placeholder="Jane Smith"
                    />
                  </div>

                  <div className="form-group">
                    <label>Email Address *</label>
                    <input
                      type="email"
                      className="form-control"
                      value={editForm.email}
                      onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                      required
                      placeholder="caregiver@example.com"
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group">
                    <label>Mobile Number *</label>
                    <input
                      type="text"
                      className="form-control"
                      value={editForm.phone_no}
                      onChange={(e) => setEditForm({ ...editForm, phone_no: e.target.value })}
                      placeholder="+60197775462"
                      required
                    />
                  </div>

                  <div className="form-group">
                    <label>Gender *</label>
                    <select
                      className="form-control"
                      value={editForm.gender}
                      onChange={(e) => setEditForm({ ...editForm, gender: e.target.value })}
                      required
                    >
                      <option value="Female">Female</option>
                      <option value="Male">Male</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label>Date of Birth * (Must be 18+ years old)</label>
                  <input
                    type="date"
                    className="form-control"
                    max={(() => {
                      const today = new Date();
                      return `${today.getFullYear() - 18}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
                    })()}
                    value={editForm.date_of_birth}
                    onChange={(e) => setEditForm({ ...editForm, date_of_birth: e.target.value })}
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Address *</label>
                  <textarea
                    className="form-control"
                    rows="3"
                    value={editForm.address}
                    onChange={(e) => setEditForm({ ...editForm, address: e.target.value })}
                    placeholder="Enter your address..."
                    style={{ resize: 'vertical' }}
                    required
                  ></textarea>
                </div>

                {/* Modal Footer Actions */}
                <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '28px', paddingTop: '16px', borderTop: '1px solid #F1F5F9' }}>
                  <button
                    type="button"
                    className="btn btn-outline"
                    onClick={() => setShowEditModal(false)}
                    disabled={actionLoading}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={actionLoading}
                    style={{ minWidth: '130px' }}
                  >
                    {actionLoading ? 'Saving...' : 'Save Changes'}
                  </button>
                </div>
              </form>

            </div>
          </div>
        )}

        {/* Deactivate Modal */}
        {showDeactivateModal && (
          <div className="modal-overlay" onClick={() => setShowDeactivateModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '460px' }}>
              <div style={{ textAlign: 'center', padding: '12px 0' }}>
                <div style={{ width: '56px', height: '56px', background: '#FEF3C7', borderRadius: '50%', color: '#F59E0B', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px auto' }}>
                  <UserX size={30} />
                </div>
                <h3 style={{ fontSize: '1.2rem', color: '#2D3142', marginBottom: '8px' }}>Deactivate Caregiver Account?</h3>
                <p style={{ fontSize: '0.88rem', color: '#64748B', lineHeight: '1.5' }}>
                  Deactivating your account will temporarily disable your access to the caregiver dashboard and patient alerts.
                </p>
              </div>

              <div className="modal-actions" style={{ marginTop: '24px', display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
                <button
                  className="btn btn-outline"
                  onClick={() => setShowDeactivateModal(false)}
                  disabled={actionLoading}
                >
                  Cancel
                </button>
                <button
                  className="btn"
                  onClick={handleDeactivate}
                  disabled={actionLoading}
                  style={{ background: '#F59E0B', color: 'white', border: 'none' }}
                >
                  {actionLoading ? 'Deactivating...' : 'Confirm Deactivation'}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Delete Account Modal */}
        {showDeleteModal && (
          <div className="modal-overlay" onClick={() => setShowDeleteModal(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '460px' }}>
              <div style={{ textAlign: 'center', padding: '12px 0' }}>
                <div style={{ width: '56px', height: '56px', background: '#FEE2E2', borderRadius: '50%', color: '#EF4444', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px auto' }}>
                  <Trash2 size={30} />
                </div>
                <h3 style={{ fontSize: '1.2rem', color: '#991B1B', marginBottom: '8px' }}>Permanently Delete Account?</h3>
                <p style={{ fontSize: '0.88rem', color: '#64748B', lineHeight: '1.5' }}>
                  This action <strong style={{ color: '#EF4444' }}>CANNOT</strong> be undone. All your caregiver profile data and patient assignment mappings will be permanently removed.
                </p>
              </div>

              <div className="modal-actions" style={{ marginTop: '24px', display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
                <button
                  className="btn btn-outline"
                  onClick={() => setShowDeleteModal(false)}
                  disabled={actionLoading}
                >
                  Cancel
                </button>
                <button
                  className="btn btn-danger"
                  onClick={handleDeleteAccount}
                  disabled={actionLoading}
                >
                  {actionLoading ? 'Deleting...' : 'Delete Permanently'}
                </button>
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}

// AIAnalytics.jsx
import React, { useState, useEffect } from 'react';
import {
  BrainCircuit,
  AlertTriangle,
  RotateCw,
  CheckCircle2,
  Activity,
  Zap,
  ShieldAlert,
  Loader2,
  X,
  Check,
  Minus,
  Info,
  Calendar,
  Clock,
  User,
  Sparkles,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

export default function AIAnalytics({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();

  const [overview, setOverview] = useState({
    high_risk_patients: 0,
    medium_risk_patients: 0,
    total_analyzed: 0,
  });

  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [jobRunning, setJobRunning] = useState(false);

  // Prediction Setup Modal State
  const [setupModalPatient, setSetupModalPatient] = useState(null);
  const [modalLoadingHistory, setModalLoadingHistory] = useState(false);
  const [patientHistory, setPatientHistory] = useState([-1, -1, -1]);
  const [isPredicting, setIsPredicting] = useState(false);

  // Insufficient Data Alert Modal State
  const [insufficientDataMsg, setInsufficientDataMsg] = useState(null);

  // Prediction Complete Result Modal State
  const [predictionResult, setPredictionResult] = useState(null);

  const fetchAIOverview = async (showSpinner = true) => {
    if (showSpinner) setLoading(true);
    try {
      const [overviewData, patientsData, riskData] = await Promise.all([
        apiService.getAnalyticsOverview(caregiverId),
        apiService.getCaregiverPatients(caregiverId, 'active'),
        apiService.getAtRiskPatients(caregiverId),
      ]);

      if (overviewData) setOverview(overviewData);

      // Merge patient details with predictions - strictly filter to ACTIVE patients only
      const rawList = Array.isArray(patientsData) && patientsData.length > 0
        ? patientsData
        : (Array.isArray(riskData) ? riskData : []);

      const activePatientList = rawList.filter((pat) => pat.is_active !== false && pat.is_active !== 0);

      // Fetch predictions for each active patient concurrently
      const enriched = await Promise.all(
        activePatientList.map(async (pat) => {
          const pid = pat.patient_id || pat.id;
          const pred = await apiService.getAIPrediction(pid);
          return {
            ...pat,
            patient_id: pid,
            prediction: pred,
          };
        })
      );

      setPatients(enriched);
    } catch (err) {
      console.error('Error fetching AI analytics:', err);
    } finally {
      if (showSpinner) setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  useEffect(() => {
    if (caregiverId) {
      fetchAIOverview(true);
      const interval = setInterval(() => {
        fetchAIOverview(false); // Silent background auto-reload without spinner
      }, 15000);
      return () => clearInterval(interval);
    }
  }, [caregiverId]);

  useEffect(() => {
    if (isRefreshing) fetchAIOverview(true);
  }, [isRefreshing]);

  // Run Batch AI Model
  const handleRunBatchAI = async () => {
    setJobRunning(true);
    const success = await apiService.runBatchPrediction();
    if (success) {
      alert('Batch AI analytics pipeline completed successfully for all active patients!');
    } else {
      alert('Batch AI job finished or completed with status update.');
    }
    await fetchAIOverview();
    setJobRunning(false);
  };

  // Helper date/time calculations matching Flutter app
  const getCurrentDayOfWeek = () => {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[new Date().getDay()];
  };

  const getCurrentTimeOfDay = () => {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 18) return 'Afternoon';
    return 'Evening';
  };

  const calculateAge = (dobString) => {
    if (!dobString) return 65;
    try {
      const dob = new Date(dobString);
      const diff = Date.now() - dob.getTime();
      const ageDate = new Date(diff);
      return Math.abs(ageDate.getUTCFullYear() - 1970) || 65;
    } catch (e) {
      return 65;
    }
  };

  // Fetch patient recent history (3 items: 1=Taken, 0=Missed, -1=No Data)
  const fetchPatientHistory = async (patientId) => {
    try {
      const logs = await apiService.getPatientAdherenceLogs(patientId, 10);
      const history = [];

      if (Array.isArray(logs)) {
        for (let log of logs) {
          if (log.status === 'TAKEN') {
            history.push(1);
          } else if (log.status === 'MISSED') {
            history.push(0);
          }
          if (history.length === 3) break;
        }
      }

      // Fill missing entries with -1
      while (history.length < 3) {
        history.unshift(-1);
      }
      return history.reverse(); // oldest on left, most recent on right
    } catch (e) {
      return [-1, -1, -1];
    }
  };

  // Open Prediction Dialog (matching Flutter _showPredictionDialog)
  const handleOpenPredictionDialog = async (patient) => {
    setSetupModalPatient(patient);
    setModalLoadingHistory(true);

    const history = await fetchPatientHistory(patient.patient_id || patient.id);
    setPatientHistory(history);
    setModalLoadingHistory(false);
  };

  // Execute single prediction
  const handleRunPrediction = async () => {
    if (!setupModalPatient) return;
    const pid = setupModalPatient.patient_id || setupModalPatient.id;

    setIsPredicting(true);
    try {
      const res = await apiService.recalculatePrediction(pid);
      setIsPredicting(false);
      setSetupModalPatient(null);

      if (!res || res.success === false) {
        setInsufficientDataMsg(
          res?.message || 'Insufficient adherence data. At least 3 recorded doses (TAKEN or MISSED) are required to run a reliable AI prediction.'
        );
        return;
      }

      const predData = res.data || res;
      if (predData && (predData.prediction_score !== undefined || predData.risk_score !== undefined)) {
        const score = predData.prediction_score ?? predData.risk_score ?? predData.forget_probability ?? 0.0;
        const riskLevel = predData.risk_level || (score > 60 ? 'HIGH' : score > 30 ? 'MEDIUM' : 'LOW');

        setPredictionResult({
          score: parseFloat(score),
          riskLevel: riskLevel,
          patientName: setupModalPatient.full_name || setupModalPatient.fullname || setupModalPatient.name || 'Patient',
        });

        // Refresh overview and patient list
        fetchAIOverview();
      } else {
        setInsufficientDataMsg('Invalid prediction response format.');
      }
    } catch (err) {
      setIsPredicting(false);
      setSetupModalPatient(null);
      alert(`Prediction failed: ${err.message || 'Server error'}`);
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
            {loading ? 'Loading AI analytics & predictions...' : 'Refreshing...'}
          </p>
        </div>
      )}

      {/* Main content – dimmed when spinner is visible */}
      <div style={{ opacity: showSpinner ? 0.4 : 1, transition: 'opacity 0.2s' }}>
        {/* Top Banner & Batch Trigger */}
        <div className="glass-card" style={{ padding: '24px', marginBottom: '24px', background: 'white' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
            <div>
              <h2 style={{ fontSize: '1.25rem', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <BrainCircuit size={26} color="#6A4C93" />
                Hybrid AI Adherence Prediction Engine
              </h2>
              <p style={{ fontSize: '0.88rem', color: '#6B7280', marginTop: '4px' }}>
                Machine learning models (LSTM + Random Forest) analyze historical dosing patterns, age, and schedule factors to predict missed doses
              </p>
            </div>

            <button className="btn btn-primary" onClick={handleRunBatchAI} disabled={jobRunning}>
              <Zap size={18} className={jobRunning ? 'animate-spin' : ''} />
              <span>{jobRunning ? 'Running AI Engine...' : 'Run Batch AI Analytics'}</span>
            </button>
          </div>
        </div>

        {/* AI Metrics Overview Row – 3 Cards (Overall Predicted Adherence REMOVED as requested) */}
        <div className="metrics-grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)', gap: '20px' }}>
          {/* Card 1: High Risk Patients */}
          <div className="metric-card">
            <div>
              <div className="metric-title">High Risk Patients</div>
              <div className="metric-value" style={{ color: '#EF4444' }}>
                {overview.high_risk_patients || patients.filter(p => p.prediction?.risk_level === 'HIGH').length || 0}
              </div>
              <span className="badge badge-danger">Immediate Outreach</span>
            </div>
            <div className="metric-icon-box" style={{ background: '#FEE2E2', color: '#EF4444' }}>
              <ShieldAlert size={26} />
            </div>
          </div>

          {/* Card 2: Medium Risk Patients */}
          <div className="metric-card">
            <div>
              <div className="metric-title">Medium Risk Patients</div>
              <div className="metric-value" style={{ color: '#F59E0B' }}>
                {overview.medium_risk_patients || patients.filter(p => p.prediction?.risk_level === 'MEDIUM').length || 0}
              </div>
              <span className="badge badge-warning">Monitor Closely</span>
            </div>
            <div className="metric-icon-box" style={{ background: '#FEF3C7', color: '#F59E0B' }}>
              <AlertTriangle size={26} />
            </div>
          </div>

          {/* Card 3: Total Patients Analyzed */}
          <div className="metric-card">
            <div>
              <div className="metric-title">Total Patients Analyzed</div>
              <div className="metric-value">{overview.total_analyzed || patients.length || 0}</div>
            </div>
            <div className="metric-icon-box" style={{ background: '#DBEAFE', color: '#3B82F6' }}>
              <Activity size={26} />
            </div>
          </div>
        </div>

        {/* Patient AI Predictions Table */}
        <div className="glass-card" style={{ padding: '24px', marginTop: '24px', background: 'white' }}>
          <div className="card-header" style={{ marginBottom: '16px' }}>
            <div>
              <h3 style={{ fontSize: '1.1rem', color: '#2D3142', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <BrainCircuit size={20} color="#6A4C93" />
                Patient Adherence Risk Table & Inference
              </h3>
              <p style={{ fontSize: '0.82rem', color: '#6B7280' }}>
                Click "Run AI Prediction" on any patient to view history and compute individual LSTM + Random Forest prediction
              </p>
            </div>
          </div>

          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th>Patient Name</th>
                  <th>Age</th>
                  <th>Risk Level</th>
                  <th>Forget Probability</th>
                  <th>Risk Progress</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {patients.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '30px', color: '#94A3B8' }}>
                      No patients assigned to caregiver yet.
                    </td>
                  </tr>
                ) : (
                  patients.map((patient, i) => {
                    const pid = patient.patient_id || patient.id || i;
                    const name = patient.full_name || patient.fullname || patient.name || `Patient #${pid}`;
                    const age = calculateAge(patient.date_of_birth || patient.dob);

                    const pred = patient.prediction;
                    const score = pred ? (pred.prediction_score ?? pred.risk_score ?? pred.forget_probability ?? 0.0) : 0.0;
                    const riskLevel = pred ? (pred.risk_level || (score > 60 ? 'HIGH' : score > 30 ? 'MEDIUM' : 'LOW')) : 'UNTESTED';

                    const riskBadgeClass = riskLevel === 'HIGH' ? 'badge-danger' : riskLevel === 'MEDIUM' ? 'badge-warning' : riskLevel === 'LOW' ? 'badge-success' : 'badge-info';
                    const riskColor = riskLevel === 'HIGH' ? '#EF4444' : riskLevel === 'MEDIUM' ? '#F59E0B' : riskLevel === 'LOW' ? '#10B981' : '#94A3B8';

                    return (
                      <tr key={pid}>
                        <td style={{ fontWeight: '600', color: '#2D3142' }}>{name}</td>
                        <td style={{ color: '#64748B' }}>{age} yrs</td>
                        <td>
                          <span className={`badge ${riskBadgeClass}`}>
                            {riskLevel} RISK
                          </span>
                        </td>
                        <td style={{ fontWeight: '700', color: riskColor }}>
                          {pred ? `${score.toFixed(2)}%` : 'N/A'}
                        </td>
                        <td style={{ minWidth: '130px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <div style={{ flex: 1, height: '8px', background: '#E2E8F0', borderRadius: '4px', overflow: 'hidden' }}>
                              <div style={{
                                width: `${Math.min(score, 100)}%`,
                                height: '100%',
                                background: riskColor,
                                transition: 'width 0.3s'
                              }} />
                            </div>
                          </div>
                        </td>
                        <td>
                          <button
                            className="btn btn-primary"
                            style={{ padding: '6px 14px', fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '6px' }}
                            onClick={() => handleOpenPredictionDialog(patient)}
                          >
                            <Sparkles size={14} />
                            <span>Run AI Prediction</span>
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* 1. PREDICTION SETUP MODAL (Matches Flutter _showPredictionDialog) */}
      {/* ========================================================================= */}
      {setupModalPatient && (
        <div className="modal-overlay" onClick={() => !isPredicting && setSetupModalPatient(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '440px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
              <h3 style={{ fontSize: '1.15rem', color: '#2D3142', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <BrainCircuit size={20} color="#6A4C93" />
                Hybrid AI Prediction for {setupModalPatient.full_name || setupModalPatient.fullname || setupModalPatient.name || 'Patient'}
              </h3>
              {!isPredicting && (
                <button onClick={() => setSetupModalPatient(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}>
                  <X size={20} />
                </button>
              )}
            </div>

            {isPredicting ? (
              <div style={{ textAlign: 'center', padding: '30px 20px' }}>
                <Loader2 className="spinner" size={42} color="#6A4C93" style={{ margin: '0 auto 16px auto', display: 'block' }} />
                <h4 style={{ color: '#2D3142', fontWeight: '700' }}>Running Hybrid AI (LSTM + Random Forest)...</h4>
                <p style={{ color: '#6B7280', fontSize: '0.85rem', marginTop: '6px' }}>
                  Processing temporal adherence vectors & schedule risk parameters...
                </p>
              </div>
            ) : modalLoadingHistory ? (
              <div style={{ textAlign: 'center', padding: '30px 20px' }}>
                <Loader2 className="spinner" size={32} color="#6A4C93" style={{ margin: '0 auto 12px auto', display: 'block' }} />
                <p style={{ color: '#6B7280', fontSize: '0.85rem' }}>Loading recent patient adherence history...</p>
              </div>
            ) : (
              <div>
                <p style={{ fontSize: '0.88rem', fontWeight: '600', color: '#334155', marginBottom: '8px' }}>
                  This will run the Hybrid AI model (LSTM + Random Forest) to predict:
                </p>
                <ul style={{ fontSize: '0.85rem', color: '#64748B', paddingLeft: '18px', marginBottom: '16px', lineHeight: '1.6' }}>
                  <li>• Probability of missing next dose</li>
                  <li>• Risk level (LOW / MEDIUM / HIGH)</li>
                  <li>• Temporal pattern analysis</li>
                </ul>

                {/* Info Card Box */}
                <div style={{ background: '#F8FAFC', padding: '14px', borderRadius: '10px', border: '1px solid #E2E8F0', marginBottom: '20px' }}>
                  <div style={{ fontWeight: '700', fontSize: '0.85rem', color: '#1E293B', marginBottom: '8px' }}>
                    Patient Information:
                  </div>
                  <div style={{ fontSize: '0.82rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span>Name:</span>
                      <strong>{setupModalPatient.full_name || setupModalPatient.fullname || setupModalPatient.name}</strong>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span>Age:</span>
                      <strong>{calculateAge(setupModalPatient.date_of_birth || setupModalPatient.dob)} years</strong>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span>Date:</span>
                      <strong>{new Date().toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' })} ({getCurrentDayOfWeek()})</strong>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span>Time:</span>
                      <strong>{new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })} ({getCurrentTimeOfDay()})</strong>
                    </div>
                  </div>

                  <hr style={{ margin: '12px 0', border: 'none', borderTop: '1px solid #E2E8F0' }} />

                  <div style={{ fontWeight: '700', fontSize: '0.85rem', color: '#1E293B', marginBottom: '10px' }}>
                    Recent Adherence History:
                  </div>

                  {/* 3 Circle Indicators */}
                  <div style={{ display: 'flex', justifyContent: 'space-around', alignItems: 'center', marginBottom: '8px' }}>
                    {patientHistory.map((val, idx) => {
                      const isTaken = val === 1;
                      const isMissed = val === 0;
                      const bgColor = isTaken ? '#10B981' : isMissed ? '#EF4444' : '#94A3B8';

                      return (
                        <div key={idx} style={{ textAlign: 'center' }}>
                          <div style={{
                            width: '40px',
                            height: '40px',
                            borderRadius: '50%',
                            background: bgColor,
                            color: 'white',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            margin: '0 auto 4px auto',
                            fontWeight: 'bold',
                          }}>
                            {isTaken ? <Check size={20} /> : isMissed ? <X size={20} /> : <Minus size={20} />}
                          </div>
                          <span style={{ fontSize: '0.68rem', color: '#64748B' }}>
                            {idx === 0 ? 'Oldest' : idx === 2 ? 'Most Recent' : ''}
                          </span>
                        </div>
                      );
                    })}
                  </div>

                  <div style={{ fontSize: '0.78rem', color: '#475569', textAlign: 'center', marginTop: '6px', fontWeight: '500' }}>
                    History: {patientHistory.map(h => h === 1 ? '✓ Taken' : h === 0 ? '✗ Missed' : '- No Data').join(' → ')}
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '12px' }}>
                  <button className="btn btn-secondary" onClick={() => setSetupModalPatient(null)} style={{ flex: 1 }}>
                    Cancel
                  </button>
                  <button className="btn btn-primary" onClick={handleRunPrediction} style={{ flex: 1, padding: '12px' }}>
                    Run Prediction
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 2. INSUFFICIENT DATA ALERT MODAL (Matches Flutter AlertDialog) */}
      {/* ========================================================================= */}
      {insufficientDataMsg && (
        <div className="modal-overlay" onClick={() => setInsufficientDataMsg(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '380px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '14px' }}>
              <AlertTriangle size={24} color="#F59E0B" />
              <h3 style={{ fontSize: '1.1rem', color: '#2D3142', fontWeight: '700' }}>Insufficient Data</h3>
            </div>
            <p style={{ fontSize: '0.88rem', color: '#475569', marginBottom: '20px', lineHeight: '1.5' }}>
              {insufficientDataMsg}
            </p>
            <button className="btn btn-primary" onClick={() => setInsufficientDataMsg(null)} style={{ width: '100%', padding: '10px' }}>
              OK
            </button>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 3. PREDICTION COMPLETE RESULT MODAL (Matches Flutter Result Card) */}
      {/* ========================================================================= */}
      {predictionResult && (
        <div className="modal-overlay" onClick={() => setPredictionResult(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '420px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px', paddingBottom: '12px', borderBottom: '1px solid #E2E8F0' }}>
              <h3 style={{ fontSize: '1.15rem', color: '#10B981', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <CheckCircle2 size={22} color="#10B981" />
                Prediction Complete!
              </h3>
              <button onClick={() => setPredictionResult(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748B' }}>
                <X size={20} />
              </button>
            </div>

            {/* Gradient Result Card */}
            {(() => {
              const { score, riskLevel, patientName } = predictionResult;
              const riskColor = riskLevel === 'HIGH' ? '#EF4444' : riskLevel === 'MEDIUM' ? '#F59E0B' : '#10B981';
              const riskBg = riskLevel === 'HIGH' ? '#FEF2F2' : riskLevel === 'MEDIUM' ? '#FFFBEB' : '#ECFDF5';

              return (
                <div style={{
                  background: riskBg,
                  border: `1px solid ${riskColor}40`,
                  borderRadius: '12px',
                  padding: '18px',
                  marginBottom: '20px',
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                    <span style={{ fontWeight: '700', fontSize: '0.9rem', color: '#1E293B' }}>Risk Level:</span>
                    <span className={`badge ${riskLevel === 'HIGH' ? 'badge-danger' : riskLevel === 'MEDIUM' ? 'badge-warning' : 'badge-success'}`} style={{ fontSize: '0.82rem', padding: '4px 12px' }}>
                      {riskLevel} RISK
                    </span>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                    <span style={{ fontWeight: '700', fontSize: '0.9rem', color: '#1E293B' }}>Forget Probability:</span>
                    <span style={{ fontSize: '1.5rem', fontWeight: '800', color: riskColor }}>
                      {score.toFixed(2)}%
                    </span>
                  </div>

                  {/* Progress Bar */}
                  <div style={{ height: '8px', background: '#E2E8F0', borderRadius: '4px', overflow: 'hidden', marginBottom: '12px' }}>
                    <div style={{
                      width: `${Math.min(score, 100)}%`,
                      height: '100%',
                      background: riskColor,
                      transition: 'width 0.4s ease-out'
                    }} />
                  </div>

                  <p style={{ fontSize: '0.85rem', color: '#334155', fontWeight: '600', marginTop: '8px' }}>
                    {score > 60
                      ? '⚠️ High risk of missing next dose. Send reminder!'
                      : score > 30
                        ? '⚡ Moderate risk. Monitor patient adherence closely.'
                        : '✅ Patient adherence is stable.'}
                  </p>
                </div>
              );
            })()}

            <button className="btn btn-primary" onClick={() => setPredictionResult(null)} style={{ width: '100%', padding: '11px' }}>
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

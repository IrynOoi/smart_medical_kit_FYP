import React, { useState, useEffect } from 'react';
import { 
  Users, 
  CheckCircle2, 
  XCircle, 
  Clock, 
  AlertTriangle, 
  TrendingUp, 
  Activity,
  Calendar
} from 'lucide-react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import { Bar, Line } from 'react-chartjs-2';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

// Register ChartJS modules
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

export default function Dashboard({ isRefreshing, onRefreshComplete }) {
  const { caregiverId } = useAuth();
  
  const [stats, setStats] = useState({
    taken_count: 0,
    missed_count: 0,
    pending_count: 0,
    total_patients: 0,
    low_stock_count: 0,
  });
  
  const [period, setPeriod] = useState('Week');
  const [chartData, setChartData] = useState({
    taken: [0, 0, 0, 0, 0, 0, 0],
    missed: [0, 0, 0, 0, 0, 0, 0],
  });
  
  const [recentLogs, setRecentLogs] = useState([]);
  const [atRiskPatients, setAtRiskPatients] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchDashboardData = async () => {
    setLoading(true);
    try {
      const [overviewRes, chartRes, logsRes, riskRes] = await Promise.all([
        apiService.getCaregiverOverview(caregiverId),
        apiService.getChartData(caregiverId, period),
        apiService.getAllRecentLogs(caregiverId, 10),
        apiService.getAtRiskPatients(caregiverId),
      ]);

      if (overviewRes) setStats(overviewRes);
      if (chartRes) setChartData(chartRes);
      if (logsRes) setRecentLogs(logsRes);
      if (riskRes) setAtRiskPatients(riskRes);
    } catch (err) {
      console.error('Error loading dashboard data:', err);
    } finally {
      setLoading(false);
      if (onRefreshComplete) onRefreshComplete();
    }
  };

  useEffect(() => {
    fetchDashboardData();
  }, [caregiverId, period]);

  useEffect(() => {
    if (isRefreshing) {
      fetchDashboardData();
    }
  }, [isRefreshing]);

  // Labels based on selected period
  const getPeriodLabels = () => {
    if (period === 'Day') return ['6AM', '9AM', '12PM', '3PM', '6PM', '9PM'];
    if (period === 'Month') return ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  };

  const chartConfig = {
    labels: getPeriodLabels(),
    datasets: [
      {
        label: 'Doses Taken',
        data: chartData.taken || [],
        backgroundColor: 'rgba(16, 185, 129, 0.7)',
        borderColor: '#10B981',
        borderWidth: 2,
        borderRadius: 6,
      },
      {
        label: 'Doses Missed',
        data: chartData.missed || [],
        backgroundColor: 'rgba(239, 68, 68, 0.7)',
        borderColor: '#EF4444',
        borderWidth: 2,
        borderRadius: 6,
      },
    ],
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          font: { family: 'Plus Jakarta Sans', size: 12 },
          usePointStyle: true,
        },
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        grid: { color: '#E2E8F0' },
      },
      x: {
        grid: { display: false },
      },
    },
  };

  return (
    <div>
      {/* Metrics Row */}
      <div className="metrics-grid">
        <div className="metric-card">
          <div>
            <div className="metric-title">Assigned Patients</div>
            <div className="metric-value">{stats.total_patients || 0}</div>
            <span style={{ fontSize: '0.75rem', color: '#6B7280' }}>Active in care system</span>
          </div>
          <div className="metric-icon-box" style={{ background: '#F3E8FF', color: '#6A4C93' }}>
            <Users size={26} />
          </div>
        </div>

        <div className="metric-card">
          <div>
            <div className="metric-title">Doses Taken Today</div>
            <div className="metric-value" style={{ color: '#10B981' }}>{stats.taken_count || 0}</div>
            <span className="badge badge-success">On Schedule</span>
          </div>
          <div className="metric-icon-box" style={{ background: '#D1FAE5', color: '#10B981' }}>
            <CheckCircle2 size={26} />
          </div>
        </div>

        <div className="metric-card">
          <div>
            <div className="metric-title">Missed Doses</div>
            <div className="metric-value" style={{ color: '#EF4444' }}>{stats.missed_count || 0}</div>
            <span className="badge badge-danger">Attention Needed</span>
          </div>
          <div className="metric-icon-box" style={{ background: '#FEE2E2', color: '#EF4444' }}>
            <XCircle size={26} />
          </div>
        </div>

        <div className="metric-card">
          <div>
            <div className="metric-title">Low Stock Alerts</div>
            <div className="metric-value" style={{ color: '#F59E0B' }}>{stats.low_stock_count || 0}</div>
            <span className="badge badge-warning">Refill Required</span>
          </div>
          <div className="metric-icon-box" style={{ background: '#FEF3C7', color: '#F59E0B' }}>
            <AlertTriangle size={26} />
          </div>
        </div>
      </div>

      {/* Main Grid: Chart & At Risk Patients */}
      <div className="dashboard-grid">
        {/* Adherence Graph */}
        <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
          <div className="card-header">
            <div>
              <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <TrendingUp size={20} color="#6A4C93" />
                Medication Adherence Overview
              </h3>
              <p style={{ fontSize: '0.8rem', color: '#6B7280' }}>Track taken vs missed doses across all patients</p>
            </div>

            {/* Period Selector Buttons */}
            <div style={{ display: 'flex', background: '#F1F5F9', padding: '4px', borderRadius: '10px' }}>
              {['Day', 'Week', 'Month'].map((p) => (
                <button
                  key={p}
                  onClick={() => setPeriod(p)}
                  style={{
                    padding: '6px 14px',
                    fontSize: '0.78rem',
                    fontWeight: '600',
                    border: 'none',
                    borderRadius: '8px',
                    background: period === p ? '#6A4C93' : 'transparent',
                    color: period === p ? 'white' : '#64748B',
                    transition: 'all 0.2s ease',
                  }}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          <div style={{ height: '320px', position: 'relative' }}>
            <Bar data={chartConfig} options={chartOptions} />
          </div>
        </div>

        {/* High Risk AI Alerts Card */}
        <div className="glass-card" style={{ padding: '24px', background: 'white' }}>
          <div className="card-header">
            <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <AlertTriangle size={20} color="#EF4444" />
              AI Risk Watchlist
            </h3>
            <span className="badge badge-danger">{atRiskPatients.length} High Risk</span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', maxHeight: '320px', overflowY: 'auto' }}>
            {atRiskPatients.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px 10px', color: '#6B7280', fontSize: '0.88rem' }}>
                <CheckCircle2 size={36} color="#10B981" style={{ margin: '0 auto 8px auto', display: 'block' }} />
                All patients have healthy adherence levels!
              </div>
            ) : (
              atRiskPatients.map((patient, idx) => (
                <div 
                  key={patient.id || idx}
                  style={{
                    padding: '14px',
                    borderRadius: '12px',
                    background: '#FEF2F2',
                    borderLeft: '4px solid #EF4444',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between'
                  }}
                >
                  <div>
                    <div style={{ fontWeight: '700', fontSize: '0.9rem', color: '#991B1B' }}>
                      {patient.fullname || `Patient #${patient.id}`}
                    </div>
                    <div style={{ fontSize: '0.78rem', color: '#7F1D1D' }}>
                      Predicted Risk Score: <strong>{(patient.risk_score || patient.prediction || 85).toFixed(0)}%</strong>
                    </div>
                  </div>
                  <span className="badge badge-danger">High Risk</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Recent Activity Log Stream */}
      <div className="glass-card" style={{ padding: '24px', background: 'white', marginTop: '24px' }}>
        <div className="card-header">
          <div>
            <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Activity size={20} color="#6A4C93" />
              Live Adherence Activity Feed
            </h3>
            <p style={{ fontSize: '0.8rem', color: '#6B7280' }}>Real-time logs from smart medical kit dispensers</p>
          </div>
        </div>

        <div className="table-container">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Patient Name</th>
                <th>Medication</th>
                <th>Status</th>
                <th>Dispensed Time</th>
                <th>Device ID</th>
              </tr>
            </thead>
            <tbody>
              {recentLogs.length === 0 ? (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '30px', color: '#94A3B8' }}>
                    No recent log entries recorded.
                  </td>
                </tr>
              ) : (
                recentLogs.map((log, i) => (
                  <tr key={log.id || i}>
                    <td style={{ fontWeight: '600', color: '#2D3142' }}>
                      {log.patient_name || log.patient_id || 'Unknown Patient'}
                    </td>
                    <td>{log.medication_name || log.prescription_name || 'Daily Medication'}</td>
                    <td>
                      <span className={`badge ${
                        log.status?.toLowerCase() === 'taken' || log.taken 
                          ? 'badge-success' 
                          : 'badge-danger'
                      }`}>
                        {log.status || (log.taken ? 'Taken' : 'Missed')}
                      </span>
                    </td>
                    <td style={{ color: '#64748B', fontSize: '0.85rem' }}>
                      {log.timestamp || log.scheduled_time || 'Just now'}
                    </td>
                    <td style={{ fontFamily: 'monospace', color: '#6A4C93' }}>
                      {log.device_serial || `KIT-${log.device_id || '01'}`}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

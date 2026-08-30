# services/email_service.py
# Handles sending emails for OTP verification using Mailtrap SMTP.
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from config import MAILTRAP_CONFIG

def send_reset_otp_email(to_email, otp_code):
    """Sends a 6-digit password reset OTP email using Mailtrap SMTP."""
    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = 'Password Reset OTP - My Medical Kit'
        msg['From'] = MAILTRAP_CONFIG['sender_email']
        msg['To'] = to_email

        html_content = f"""
        <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
                <h2 style="color: #6A4C93;">Password Reset Request</h2>
                <p>Hello,</p>
                <p>You requested to reset your password. Use the 6-digit OTP code below:</p>
                <div style="background: #F3E8FF; padding: 15px; text-align: center; border-radius: 8px; margin: 20px 0;">
                    <h1 style="color: #6A4C93; letter-spacing: 6px; margin: 0;">{otp_code}</h1>
                </div>
                <p>This code will expire in 10 minutes.</p>
                <p>If you did not request a password reset, please ignore this email.</p>
            </body>
        </html>
        """

        msg.attach(MIMEText(html_content, 'html'))

        # Connect to Mailtrap SMTP Server
        with smtplib.SMTP(MAILTRAP_CONFIG['smtp_server'], MAILTRAP_CONFIG['port']) as server:
            server.starttls()
            server.login(MAILTRAP_CONFIG['username'], MAILTRAP_CONFIG['password'])
            server.sendmail(MAILTRAP_CONFIG['sender_email'], to_email, msg.as_string())

        print(f"[SUCCESS] OTP email sent via Mailtrap to {to_email}")
        return True

    except Exception as e:
        print(f"[ERROR] Failed to send email via Mailtrap: {e}")
        return False


def send_hardware_ticket_email(ticket_data, to_email=None):
    """
    Sends a hardware technician inspection ticket email notification via Mailtrap SMTP.
    """
    try:
        recipient = to_email or MAILTRAP_CONFIG.get('sender_email', 'hardware.support@smartmedkit.my')
        ticket_id = ticket_data.get('ticket_id', 'HW-0000')
        device_serial = ticket_data.get('device_serial', 'DISP-Unknown')
        issue_category = ticket_data.get('issue_category', 'Other')
        notes = ticket_data.get('notes', 'No additional notes provided.')
        submitted_by = ticket_data.get('submitted_by', 'Caregiver Portal')
        created_at = ticket_data.get('created_at', '')
        technician_name = ticket_data.get('technician_name', 'Ooi Xien Xien')

        msg = MIMEMultipart('alternative')
        msg['Subject'] = f"[Hardware Ticket #{ticket_id}] Inspection Request - {device_serial} ({issue_category})"
        msg['From'] = MAILTRAP_CONFIG['sender_email']
        msg['To'] = recipient

        html_content = f"""
        <html>
            <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 24px; background-color: #F8FAFC; color: #1E293B; margin: 0;">
                <div style="max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #E2E8F0;">
                    
                    <!-- Header -->
                    <div style="background: linear-gradient(135deg, #3B1E54 0%, #6A4C93 100%); padding: 28px 24px; text-align: center; color: white;">
                        <h1 style="margin: 0; font-size: 20px; font-weight: 800; letter-spacing: 0.5px;">SMART MEDICAL KIT HARDWARE SUPPORT</h1>
                        <p style="margin: 6px 0 0 0; font-size: 13px; color: rgba(255,255,255,0.85);">On-Site Hardware Technician Inspection Request</p>
                    </div>

                    <!-- Body Content -->
                    <div style="padding: 24px;">
                        <div style="display: inline-block; background: #FEF3C7; color: #B45309; font-weight: 700; font-size: 12px; padding: 4px 12px; border-radius: 20px; margin-bottom: 16px;">
                            PRIORITY: URGENT ON-SITE INSPECTION
                        </div>

                        <h2 style="font-size: 18px; color: #1E293B; margin: 0 0 16px 0;">
                            Hardware Ticket <span style="color: #6A4C93;">#{ticket_id}</span>
                        </h2>

                        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
                            <tr style="border-bottom: 1px solid #F1F5F9;">
                                <td style="padding: 10px 0; color: #64748B; font-size: 13px; font-weight: 600; width: 38%;">Target Device Serial:</td>
                                <td style="padding: 10px 0; color: #1E293B; font-size: 14px; font-weight: 700;">{device_serial}</td>
                            </tr>
                            <tr style="border-bottom: 1px solid #F1F5F9;">
                                <td style="padding: 10px 0; color: #64748B; font-size: 13px; font-weight: 600;">Issue Category:</td>
                                <td style="padding: 10px 0; color: #6A4C93; font-size: 14px; font-weight: 700;">{issue_category}</td>
                            </tr>
                            <tr style="border-bottom: 1px solid #F1F5F9;">
                                <td style="padding: 10px 0; color: #64748B; font-size: 13px; font-weight: 600;">Assigned Lead Technician:</td>
                                <td style="padding: 10px 0; color: #1E293B; font-size: 14px; font-weight: 700;">{technician_name} (Lead IoT Engineer)</td>
                            </tr>
                            <tr style="border-bottom: 1px solid #F1F5F9;">
                                <td style="padding: 10px 0; color: #64748B; font-size: 13px; font-weight: 600;">Submitted By:</td>
                                <td style="padding: 10px 0; color: #1E293B; font-size: 13px;">{submitted_by}</td>
                            </tr>
                            <tr>
                                <td style="padding: 10px 0; color: #64748B; font-size: 13px; font-weight: 600;">Timestamp:</td>
                                <td style="padding: 10px 0; color: #1E293B; font-size: 13px;">{created_at}</td>
                            </tr>
                        </table>

                        <!-- Notes Box -->
                        <div style="background: #F8FAFC; border: 1px solid #CBD5E1; border-radius: 10px; padding: 14px; margin-bottom: 20px;">
                            <div style="font-size: 12px; font-weight: 700; color: #475569; text-transform: uppercase; margin-bottom: 6px;">
                                Caregiver Notes & Symptoms:
                            </div>
                            <div style="font-size: 13px; color: #1E293B; line-height: 1.5;">
                                {notes if notes else 'No additional details provided.'}
                            </div>
                        </div>

                    </div>

                    <!-- Footer -->
                    <div style="background: #F1F5F9; padding: 14px 24px; text-align: center; font-size: 11px; color: #94A3B8; border-top: 1px solid #E2E8F0;">
                        Smart Medical Kit Admin & Caregiver Portal • Automated Notification Feed
                    </div>
                </div>
            </body>
        </html>
        """

        msg.attach(MIMEText(html_content, 'html'))

        # Connect to Mailtrap SMTP Server
        with smtplib.SMTP(MAILTRAP_CONFIG['smtp_server'], MAILTRAP_CONFIG['port']) as server:
            server.starttls()
            server.login(MAILTRAP_CONFIG['username'], MAILTRAP_CONFIG['password'])
            server.sendmail(MAILTRAP_CONFIG['sender_email'], recipient, msg.as_string())

        print(f"[SUCCESS] Hardware ticket #{ticket_id} email sent via Mailtrap to {recipient}")
        return True

    except Exception as e:
        print(f"[ERROR] Failed to send hardware ticket email via Mailtrap: {e}")
        return False

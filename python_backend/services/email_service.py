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

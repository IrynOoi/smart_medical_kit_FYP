#config.py
import os
from dotenv import load_dotenv

# Load variables from .env file into environment
load_dotenv()

DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'servernew.syokdc.com'),
    'database': os.environ.get('DB_NAME', 'mytrusth_medsmart_db'),
    'user': os.environ.get('DB_USER', 'mytrusth'),
    'password': os.environ.get('DB_PASSWORD', ''),
    'port': int(os.environ.get('DB_PORT', 3306))
}

MODEL_PATHS = {
    'lstm_model': 'smart_pill_lstm_model.h5',
    'rf_model': 'smart_pill_rf_model.pkl'
}

MAILTRAP_CONFIG = {
    # If using Mailtrap Email Testing (Sandbox):
    'smtp_server': os.environ.get('MAILTRAP_HOST', 'sandbox.smtp.mailtrap.io'),
    'port': int(os.environ.get('MAILTRAP_PORT', 2525)),
    'username': os.environ.get('MAILTRAP_USERNAME', 'api'),
    'password': os.environ.get('MAILTRAP_API_TOKEN', ''),
    'sender_email': os.environ.get('MAILTRAP_SENDER_EMAIL', 'no-reply@mymedicalkit.com')
}


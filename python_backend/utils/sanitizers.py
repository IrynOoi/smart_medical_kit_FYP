# sanitizers.py


import re

def normalize_phone_number(phone_str: str) -> str:
    """
     standardise phone no as +601XXXXXXXX format
    """
    if not phone_str:
        return phone_str
    
    # remove all non-digit and non-plus characters (such as spaces, hyphens, parentheses)
    cleaned = re.sub(r'[^\d+]', '', str(phone_str).strip())
    
    if cleaned.startswith('+60'):
        return cleaned
    elif cleaned.startswith('60'):
        return '+' + cleaned
    elif cleaned.startswith('0'):
        return '+60' + cleaned[1:]
    elif cleaned.startswith('1'):
        return '+60' + cleaned
        
    return cleaned

def clean_string(s):
    """Remove invisible character 0x00 sent from IoT hardware"""
    if isinstance(s, str):
        return s.replace('\x00', '').replace('\u0000', '')
    return s
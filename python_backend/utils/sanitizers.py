# sanitizers.py
def clean_string(s):
    """Remove invisible character 0x00 sent from IoT hardware"""
    if isinstance(s, str):
        return s.replace('\x00', '').replace('\u0000', '')
    return s
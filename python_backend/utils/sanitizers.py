#sanitizers.py
def clean_string(s):
    """清除 IoT 硬件传来的不可见字符 0x00"""
    if isinstance(s, str):
        return s.replace('\x00', '').replace('\u0000', '')
    return s

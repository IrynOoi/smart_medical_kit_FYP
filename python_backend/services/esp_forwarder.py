# services/esp_forwarder.py
import requests

def _forward_to_esp(device_ip, endpoint, method='GET', json_data=None):
    """Helper to forward a request to the ESP32."""
    url = f"http://{device_ip}{endpoint}"
    try:
        if method == 'GET':
            resp = requests.get(url, timeout=5)
        else:
            resp = requests.post(url, json=json_data, timeout=5)
        return resp.status_code, resp.text
    except Exception as e:
        return None, str(e)

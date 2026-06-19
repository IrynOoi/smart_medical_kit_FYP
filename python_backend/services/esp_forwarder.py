# services/esp_forwarder.py
import requests  # Library used to make HTTP calls to external devices (the ESP32)

def _forward_to_esp(device_ip, endpoint, method='GET', json_data=None):
    """
    Helper function that acts as a reverse-proxy.
    It forwards incoming server requests to an ESP32 device on the local network.
    
    Args:
        device_ip (str): The local IP address of the ESP32 (e.g., "192.168.1.100").
        endpoint (str): The API route on the ESP32 (e.g., "/actuate" or "/status").
        method (str): HTTP method to use, either 'GET' or 'POST'. Defaults to 'GET'.
        json_data (dict, optional): Payload to send if method is 'POST'.
    
    Returns:
        tuple: (status_code, response_text) if successful, otherwise (None, error_message).
    """
    
    # Construct the full URL for the ESP32 (e.g., http://192.168.1.100/actuate)
    url = f"http://{device_ip}{endpoint}"
    
    try:
        # Branch based on the HTTP method required by the ESP32
        if method == 'GET':
            # GET is typically used for fetching status (battery, WiFi strength, etc.)
            # timeout=5 ensures the server doesn't hang if the ESP32 is offline
            resp = requests.get(url, timeout=5)
        else:
            # POST is used to send commands (e.g., "dispense pill", "open slot 3")
            # json=json_data automatically serializes the dict and sets Content-Type: application/json
            resp = requests.post(url, json=json_data, timeout=5)
        
        # Return the raw HTTP status code (e.g., 200 OK) and the response body (e.g., "OK" or "ERROR")
        return resp.status_code, resp.text
        
    except Exception as e:
        # Catch any networking errors (connection refused, timeout, DNS failure)
        # Return None for status and the stringified exception for debugging
        return None, str(e)

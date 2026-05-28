import requests

url = "http://localhost:5000/register"
payload = {
    "role": "patient",
    "email": "test_patient@example.com",
    "password": "password123",
    "fullname": "Test Patient",
    "gender": "Male",
    "phone_no": "1234567890",
    "date_of_birth": "1990-01-01",
    "address": "123 Test St"
}
headers = {'Content-Type': 'application/json'}

try:
    response = requests.post(url, json=payload)
    print("Status Code:", response.status_code)
    print("Response JSON:", response.json())
except Exception as e:
    print("Exception:", e)

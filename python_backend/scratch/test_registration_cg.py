import requests

url = "http://localhost:5000/register"
payload = {
    "role": "caregiver",
    "email": "test_cg@example.com",
    "password": "password123",
    "fullname": "Test CG",
    "gender": "Female",
    "phone_no": "0987654321",
    "date_of_birth": "1980-01-01",
    "address": "456 CG St"
}
headers = {'Content-Type': 'application/json'}

try:
    response = requests.post(url, json=payload)
    print("Status Code:", response.status_code)
    print("Response JSON:", response.json())
except Exception as e:
    print("Exception:", e)

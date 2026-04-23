import requests

def test_api():
    url = "https://reluctant-scrambled-badge.ngrok-free.dev/patient/2/ai_prediction"
    headers = {"ngrok-skip-browser-warning": "true"}
    try:
        response = requests.get(url, headers=headers)
        print("Status Code:", response.status_code)
        if response.status_code == 200:
            print("Response:", response.json())
        else:
            print("Response Text:", response.text)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    test_api()

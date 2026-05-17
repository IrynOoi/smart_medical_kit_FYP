import os
import re

def replace_with_values(dir_path):
    for root, dirs, files in os.walk(dir_path):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Regex to replace .withOpacity(x) with .withValues(alpha: x)
                new_content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)

                if new_content != content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {file_path}")

if __name__ == "__main__":
    replace_with_values(r"c:\Users\xienx\Desktop\UTEM\SEM 6\FYP\FYP_CODES\my_medical_kit_app\lib")

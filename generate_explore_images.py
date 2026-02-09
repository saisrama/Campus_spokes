import base64
import os

ARTIFACT_DIR = r"C:\Users\mulag\.gemini\antigravity\brain\09a37780-5d87-4b23-8776-bd3625a10cbb"
OUTPUT_FILE = r"c:/Users/mulag/campuspks/lib/data/explore_images.dart"

images_map = {
    # Shamirpet Lake
    "shamirpetLake1": "media__1770646349561.png",
    "shamirpetLake2": "media__1770646388044.png",
    "shamirpetLake3": "media__1770646453463.png",
    
    # Deer Park - Updated with user provided images
    "deerPark1": "media__1770663063539.jpg",
    "deerPark2": "media__1770663063537.jpg",
    "deerPark3": "media__1770663063539.jpg", # Duplicate to keep variable valid
    
    # Utm Lake View Point
    "utmLake1": "media__1770665874522.png",
    "utmLake2": "media__1770665897280.png",
    
    # TSFDC Urban Forest Park
    "tsfdcPark": "media__1770666118123.png",
    
    "eateryTandoor": "media__1770663211853.jpg",
    "eateryUdupi": "media__1770663838855.jpg", 
    "eateryBitsBytes": "media__1770664257485.png",
    # Eateries - Mapping based on file timestamps/sizes guess
    "eateryTaaza": "media__1770664652300.jpg",
    "eateryKatha": "media__1770664885765.jpg",
    # "eateryUdupi": "media__1770662499321.jpg", # Removed duplicate/old
    "eaterySereno": "media__1770665184164.jpg",
    "eateryHaveli": "media__1770665142180.jpg",
    "eateryAalankrita": "media__1770665328245.jpg",
}

dart_content = "// This file is auto-generated\n"

for var_name, filename in images_map.items():
    file_path = os.path.join(ARTIFACT_DIR, filename)
    if os.path.exists(file_path):
        print(f"Processing {filename}...")
        with open(file_path, "rb") as image_file:
            encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
            dart_content += f'const String {var_name} = "{encoded_string}";\n'
    else:
        print(f"Warning: File not found: {filename}")
        dart_content += f'const String {var_name} = ""; // FILE NOT FOUND\n'

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write(dart_content)

print(f"Successfully generated {OUTPUT_FILE} with {len(images_map)} images.")

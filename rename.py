import csv
import os
import shutil

csv_file = "dataset/images.csv"
source_folder = "dataset/images_original"
destination_base = "sorted_images"


os.makedirs(destination_base, exist_ok=True)

with open(csv_file, newline="") as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        image_name = row["image"]
        label = row["label"]
        src = None
        for ext in [".jpg", ".jpeg", ".png", ".gif"]:
            potential_src = os.path.join(source_folder, f"{image_name}{ext}")
            if os.path.exists(potential_src):
                src = potential_src
                break
        if src is None:
            print(f"Image {image_name} not found in {source_folder}")
            continue
        dest_folder = os.path.join(destination_base, label)
        os.makedirs(dest_folder, exist_ok=True)
        if os.path.exists(src):
            shutil.copy(src, dest_folder)

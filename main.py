import os
import random
import uvicorn
from typing import Optional
from fastapi import FastAPI, File, UploadFile, HTTPException
import torch
import torchvision.transforms as transforms
from torchvision.models import resnet50
import faiss
import requests
from PIL import Image
import dotenv
import pickle
import base64
import io


class Closet:
    def __init__(self):
        self.feature_extractor = self._create_feature_extractor()
        self.transform = transforms.Compose(
            [
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
                ),
            ]
        )
        self.vector_db = faiss.IndexFlatL2(2048)
        self.wardrobe = []
        self.pairing_rules = {
            "top_bottom": [
                ("T-Shirt", ["Shorts", "Pants"]),
                ("Shirt", ["Pants", "Jeans"]),
                ("Blouse", ["Skirt", "Pants"]),
            ],
            "weather_mapping": {
                "cold": ["Hoodie", "Jacket", "Long Sleeve"],
                "hot": ["T-Shirt", "Shorts", "Tank Top"],
                "mild": [
                    "Light Sweater",
                    "T-Shirt",
                    "Long Sleeve",
                    "Shirt",
                    "Blouse",
                ],
                "very_cold": ["Winter Coat", "Hoodie", "Sweater", "Long Sleeve"],
                "warm": ["Light Sweater", "T-Shirt", "Shorts"],
                "rainy": ["Rain Jacket", "Hoodie", "Long Sleeve"],
            },
            "occasion_mapping": {
                "casual": {
                    "style": ["T-Shirt", "Jeans", "Shorts", "Sneakers"],
                    "comfort": "high",
                },
                "formal": {
                    "style": ["Shirt", "Dress Pants", "Blazer"],
                    "comfort": "medium",
                },
                "business": {
                    "style": ["Button-down Shirt", "Slacks", "Dress Shoes"],
                    "comfort": "low",
                },
                "workout": {
                    "style": ["Tank Top", "Athletic Shorts", "Leggings"],
                    "comfort": "high",
                },
                "date": {
                    "style": ["Blouse", "Nice Jeans", "Dress"],
                    "comfort": "medium",
                },
            },
        }

    def _create_feature_extractor(self):
        model = resnet50(pretrained=True)
        return torch.nn.Sequential(*list(model.children())[:-1])

    def _extract_features(self, image):
        with torch.no_grad():
            features = self.feature_extractor(image).numpy().flatten()
        return features

    def add_item(self, image_path: str, category: str, color: Optional[str] = None):
        """Add new item to wardrobe and vector DB"""
        image = Image.open(image_path).convert("RGB")
        transformed_image = self.transform(image).unsqueeze(0)
        features = self._extract_features(transformed_image)

        self.vector_db.add(features.reshape(1, -1))
        index = len(self.wardrobe)
        self.wardrobe.append({"path": image_path, "category": category, "color": color})
        return index

    def save_state(self, filepath="wardrobe_state.pkl"):
        """Save both vector DB and wardrobe metadata"""
        state = {"vector_db": self.vector_db, "wardrobe": self.wardrobe}
        with open(filepath, "wb") as f:
            pickle.dump(state, f)

    def load_state(self, filepath="wardrobe_state.pkl"):
        """Load both vector DB and wardrobe metadata"""
        with open(filepath, "rb") as f:
            state = pickle.load(f)
            self.vector_db = state["vector_db"]
            self.wardrobe = state["wardrobe"]

    def remove_item(self, index: int):
        """Remove item from wardrobe and vector DB"""
        if 0 <= index < len(self.wardrobe):
            del self.wardrobe[index]
            self.save_state()
            return True
        return False

    def load_wardrobe_from_directory(self, directory="sorted_images"):
        """Load wardrobe items from a directory and save state"""
        for category in os.listdir(directory):
            category_path = os.path.join(directory, category)
            if os.path.isdir(category_path):
                for image_file in os.listdir(category_path):
                    image_path = os.path.join(category_path, image_file)
                    self.add_item(image_path, category)
        self.save_state()

    def get_weather(self, location: str):
        """Get weather conditions for a location"""
        dotenv.load_dotenv()
        api_key = os.getenv("OPENWEATHER_KEY")
        url = f"http://api.openweathermap.org/data/2.5/weather?q={location}&appid={api_key}&units=metric"

        try:
            response = requests.get(url).json()
            temp = response["main"]["temp"]
            rain = "rain" in response.get("weather", [{}])[0].get("main", "").lower()

            if rain:
                return "rainy"
            elif temp < 5:
                return "very_cold"
            elif 5 <= temp < 15:
                return "cold"
            elif 15 <= temp < 22:
                return "mild"
            elif 22 <= temp < 28:
                return "warm"
            else:
                return "hot"
        except:
            return "mild"

    def recommend_outfit(self, occasion: str, location: str):
        weather = self.get_weather(location)

        occasion = occasion.lower()
        if occasion not in self.pairing_rules["occasion_mapping"]:
            occasion = "casual"

        weather_items = [
            item
            for item in self.wardrobe
            if item["category"]
            in self.pairing_rules["weather_mapping"].get(weather, [])
        ]

        if not weather_items:
            return {"error": f"No suitable clothes for {weather} weather"}

        top_options = [
            top
            for top in weather_items
            if top["category"]
            in self.pairing_rules["occasion_mapping"][occasion]["style"]
        ]

        top = (
            random.choice(top_options) if top_options else random.choice(weather_items)
        )

        matching_bottoms = [
            bottom
            for bottom in self.wardrobe
            if bottom["category"]
            in next(
                (
                    pair[1]
                    for pair in self.pairing_rules["top_bottom"]
                    if pair[0] == top["category"]
                ),
                [],
            )
        ]
        if not matching_bottoms:
            generic_bottoms = [
                b
                for b in self.wardrobe
                if b["category"] in ["Pants", "Jeans", "Shorts"]
            ]
            bottom = (
                random.choice(generic_bottoms)
                if generic_bottoms
                else random.choice(self.wardrobe)
            )
        else:
            bottom = random.choice(matching_bottoms)

        return {
            "top": {
                "category": top["category"],
                "color": top.get("color"),
                "image_path": top["path"],
            },
            "bottom": {
                "category": bottom["category"],
                "color": bottom.get("color"),
                "image_path": bottom["path"],
            },
            "weather": weather,
            "temperature": weather,
            "occasion": occasion,
            "occasion_details": self.pairing_rules["occasion_mapping"][occasion],
        }


app = FastAPI(title="Closet")
recommender = Closet()
recommender.load_state()


@app.post("/add_item")
async def add_clothing_item(
    file: UploadFile = File(...),
    category: str = File(...),
    color: Optional[str] = File(None),
):
    """Endpoint to add a clothing item"""
    temp_path = f"temp_{file.filename}"
    with open(temp_path, "wb") as buffer:
        buffer.write(await file.read())

    index = recommender.add_item(temp_path, category, color)
    os.remove(temp_path)
    return {"index": index, "message": "Item added successfully"}


@app.delete("/remove_item/{index}")
async def remove_clothing_item(index: int):
    """Endpoint to remove a clothing item"""
    if recommender.remove_item(index):
        return {"message": "Item removed successfully"}
    raise HTTPException(status_code=404, detail="Item not found")


@app.get("/recommend")
async def get_outfit_recommendation(
    occasion: str = "casual", location: str = "New York"
):
    """Endpoint to get outfit recommendation"""

    outfit = recommender.recommend_outfit(occasion, location)

    # Add image data to response
    if "top" in outfit:
        img_top = Image.open(outfit["top"]["image_path"])
        buffered = io.BytesIO()
        img_top.save(buffered, format="JPEG")
        outfit["top"]["image"] = base64.b64encode(buffered.getvalue()).decode()
    if "bottom" in outfit:
        img_bottom = Image.open(outfit["bottom"]["image_path"])
        buffered = io.BytesIO()
        img_bottom.save(buffered, format="JPEG")
        outfit["bottom"]["image"] = base64.b64encode(buffered.getvalue()).decode()

    return outfit


@app.get("/wardrobe")
async def get_all_items():
    """Endpoint to get all wardrobe items"""
    return {
        "items": [
            {
                "index": idx,
                "category": item["category"],
                "color": item.get("color"),
                "image": Image.open(item["path"]).tobytes(),
            }
            for idx, item in enumerate(recommender.wardrobe)
        ]
    }


if __name__ == "__main__":
    uvicorn.run(app)

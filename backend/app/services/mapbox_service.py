"""
Mapbox API Integration Service
Handles geocoding, routing, and distance calculations
"""
import httpx
from typing import Optional, Dict, Tuple
from app.config import settings


class MapboxService:
    def __init__(self):
        self.api_key = settings.MAPBOX_API_KEY
        
        self.base_url = "https://api.mapbox.com"
        self.geocoding_url = f"{self.base_url}/geocoding/v5/mapbox.places"
        self.directions_url = f"{self.base_url}/directions/v5/mapbox/driving"
    
    async def geocode_address(self, address: str) -> Optional[Tuple[float, float]]:
        """
        Convert address to coordinates (latitude, longitude)
        
        Args:
            address: Street address to geocode
            
        Returns:
            Tuple of (latitude, longitude) or None if not found
        """
        if not self.api_key:
            print("Warning: MAPBOX_API_KEY not configured. Geocoding disabled.")
            return None
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"{self.geocoding_url}/{address}.json",
                    params={"access_token": self.api_key, "limit": 1}
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get("features"):
                    coordinates = data["features"][0]["geometry"]["coordinates"]
                    # Mapbox returns [longitude, latitude]
                    return (coordinates[1], coordinates[0])
                return None
                
            except Exception as e:
                print(f"Geocoding error: {e}")
                return None
    
    async def reverse_geocode(self, latitude: float, longitude: float) -> Optional[str]:
        """
        Convert coordinates to address
        
        Args:
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            
        Returns:
            Address string or None if not found
        """
        if not self.api_key:
            print("Warning: MAPBOX_API_KEY not configured. Reverse geocoding disabled.")
            return None
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"{self.geocoding_url}/{longitude},{latitude}.json",
                    params={"access_token": self.api_key}
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get("features"):
                    return data["features"][0]["place_name"]
                return None
                
            except Exception as e:
                print(f"Reverse geocoding error: {e}")
                return None
    
    async def get_distance_and_duration(
        self, 
        origin_lat: float, 
        origin_lng: float, 
        dest_lat: float, 
        dest_lng: float
    ) -> Optional[Dict]:
        """
        Calculate distance and duration between two points using Mapbox Directions API
        
        Args:
            origin_lat: Origin latitude
            origin_lng: Origin longitude
            dest_lat: Destination latitude
            dest_lng: Destination longitude
            
        Returns:
            Dict with 'distance' (meters), 'duration' (seconds), 'duration_minutes'
        """
        if not self.api_key:
            print("Warning: MAPBOX_API_KEY not configured. Distance calculation disabled.")
            return None
        
        async with httpx.AsyncClient() as client:
            try:
                coordinates = f"{origin_lng},{origin_lat};{dest_lng},{dest_lat}"
                response = await client.get(
                    f"{self.directions_url}/{coordinates}",
                    params={
                        "access_token": self.api_key,
                        "geometries": "geojson",
                        "overview": "full"
                    }
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get("routes"):
                    route = data["routes"][0]
                    return {
                        "distance": route["distance"],  # meters
                        "duration": route["duration"],  # seconds
                        "duration_minutes": int(route["duration"] / 60),
                        "geometry": route["geometry"]  # GeoJSON for route visualization
                    }
                return None
                
            except Exception as e:
                print(f"Distance calculation error: {e}")
                return None
    
    async def get_route(
        self, 
        origin_lat: float, 
        origin_lng: float, 
        dest_lat: float, 
        dest_lng: float
    ) -> Optional[Dict]:
        """
        Get full route information including geometry for map display
        
        Returns:
            Full route data from Mapbox Directions API
        """
        return await self.get_distance_and_duration(
            origin_lat, origin_lng, dest_lat, dest_lng
        )


# Singleton instance
mapbox_service = MapboxService()

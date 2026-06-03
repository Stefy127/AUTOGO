from __future__ import annotations

from typing import Optional

import httpx

from app.config import settings


class GoogleMapsRoutesService:
    def __init__(self) -> None:
        self.api_key = settings.GOOGLE_MAPS_API_KEY
        self.base_url = "https://routes.googleapis.com/directions/v2:computeRoutes"

    def calculate_route(
        self,
        origin_lat: float,
        origin_lng: float,
        destination_lat: float,
        destination_lng: float,
    ) -> dict:
        if not self.api_key:
            raise RuntimeError("GOOGLE_MAPS_API_KEY is not configured")

        payload = {
            "origin": {
                "location": {
                    "latLng": {
                        "latitude": origin_lat,
                        "longitude": origin_lng,
                    }
                }
            },
            "destination": {
                "location": {
                    "latLng": {
                        "latitude": destination_lat,
                        "longitude": destination_lng,
                    }
                }
            },
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE",
            "computeAlternativeRoutes": False,
            "languageCode": "es-419",
            "units": "METRIC",
        }

        headers = {
            "X-Goog-Api-Key": self.api_key,
            "X-Goog-FieldMask": "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline",
            "Content-Type": "application/json",
        }

        with httpx.Client(timeout=10.0) as client:
            response = client.post(self.base_url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()

        routes = data.get("routes") or []
        if not routes:
            raise RuntimeError("Google Maps Routes API returned no routes")

        route = routes[0]
        duration_seconds = self._parse_duration_seconds(route.get("duration"))

        return {
            "distance_meters": route.get("distanceMeters"),
            "duration_seconds": duration_seconds,
            "polyline": (route.get("polyline") or {}).get("encodedPolyline"),
        }

    @staticmethod
    def _parse_duration_seconds(duration_value: Optional[str]) -> Optional[int]:
        if not duration_value:
            return None
        if isinstance(duration_value, int):
            return duration_value
        if duration_value.endswith("s"):
            duration_value = duration_value[:-1]
        try:
            return int(float(duration_value))
        except (TypeError, ValueError):
            return None


google_maps_routes_service = GoogleMapsRoutesService()
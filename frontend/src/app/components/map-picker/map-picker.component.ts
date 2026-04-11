import { Component, EventEmitter, Input, OnInit, Output, ViewChild } from '@angular/core';
import { GoogleMap, MapMarker } from '@angular/google-maps';

export interface LocationData {
  address: string;
  latitude: number;
  longitude: number;
}

@Component({
  selector: 'app-map-picker',
  templateUrl: './map-picker.component.html',
  styleUrls: ['./map-picker.component.css']
})
export class MapPickerComponent implements OnInit {
  @Input() initialLat: number = 19.432608; // CDMX default
  @Input() initialLng: number = -99.133209;
  @Output() locationSelected = new EventEmitter<LocationData>();

  @ViewChild(GoogleMap) map!: GoogleMap;
  @ViewChild(MapMarker) marker!: MapMarker;

  center: google.maps.LatLngLiteral = { lat: 19.432608, lng: -99.133209 };
  markerPosition: google.maps.LatLngLiteral | null = null;
  zoom = 13;

  mapOptions: google.maps.MapOptions = {
    mapTypeControl: false,
    streetViewControl: false,
    fullscreenControl: true,
    zoomControl: true,
  };

  markerOptions: google.maps.MarkerOptions = {
    draggable: false,
    animation: google.maps.Animation.DROP
  };

  ngOnInit(): void {
    // Set initial position if provided
    if (this.initialLat && this.initialLng) {
      this.center = { lat: this.initialLat, lng: this.initialLng };
      this.markerPosition = { lat: this.initialLat, lng: this.initialLng };
    }
  }

  onMapClick(event: google.maps.MapMouseEvent): void {
    if (event.latLng) {
      const lat = event.latLng.lat();
      const lng = event.latLng.lng();
      
      this.markerPosition = { lat, lng };

      // Reverse geocoding to get address
      this.getAddressFromCoordinates(lat, lng);
    }
  }

  getAddressFromCoordinates(lat: number, lng: number): void {
    const geocoder = new google.maps.Geocoder();
    const latlng = { lat, lng };

    geocoder.geocode({ location: latlng }, (results, status) => {
      if (status === 'OK' && results && results[0]) {
        const address = results[0].formatted_address;
        
        this.locationSelected.emit({
          address: address,
          latitude: lat,
          longitude: lng
        });
      } else {
        console.error('Geocoder failed:', status);
        // Still emit with coordinates but no address
        this.locationSelected.emit({
          address: `${lat.toFixed(6)}, ${lng.toFixed(6)}`,
          latitude: lat,
          longitude: lng
        });
      }
    });
  }

  // Method to programmatically set location (for search autocomplete in future)
  setLocation(lat: number, lng: number): void {
    this.center = { lat, lng };
    this.markerPosition = { lat, lng };
    this.getAddressFromCoordinates(lat, lng);
  }
}

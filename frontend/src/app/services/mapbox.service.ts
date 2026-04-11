import { Injectable } from '@angular/core';
import * as mapboxgl from 'mapbox-gl';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class MapboxService {
  private accessToken = 'pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w';

  constructor() {
    (mapboxgl as any).accessToken = this.accessToken;
  }

  /**
   * Crear un mapa básico
   */
  createMap(container: string, center: [number, number], zoom: number = 12): mapboxgl.Map {
    const map = new mapboxgl.Map({
      container: container,
      style: 'mapbox://styles/mapbox/streets-v12',
      center: center,
      zoom: zoom
    });

    // Agregar controles de navegación
    map.addControl(new mapboxgl.NavigationControl());

    return map;
  }

  /**
   * Agregar un marcador al mapa
   */
  addMarker(
    map: mapboxgl.Map, 
    coordinates: [number, number], 
    color: string = '#FF0000',
    popup?: string
  ): mapboxgl.Marker {
    const marker = new mapboxgl.Marker({ color: color })
      .setLngLat(coordinates);

    if (popup) {
      marker.setPopup(new mapboxgl.Popup().setHTML(popup));
    }

    marker.addTo(map);
    return marker;
  }

  /**
   * Dibujar una ruta en el mapa
   */
  async drawRoute(
    map: mapboxgl.Map, 
    origin: [number, number], 
    destination: [number, number]
  ): Promise<void> {
    const url = `https://api.mapbox.com/directions/v5/mapbox/driving/${origin[0]},${origin[1]};${destination[0]},${destination[1]}?geometries=geojson&access_token=${this.accessToken}`;

    try {
      const response = await fetch(url);
      const data = await response.json();

      if (data.routes && data.routes.length > 0) {
        const route = data.routes[0].geometry;

        // Eliminar source y layer si existen
        if (map.getSource('route')) {
          map.removeLayer('route');
          map.removeSource('route');
        }

        // Agregar la ruta al mapa
        map.addSource('route', {
          type: 'geojson',
          data: {
            type: 'Feature',
            properties: {},
            geometry: route
          }
        });

        map.addLayer({
          id: 'route',
          type: 'line',
          source: 'route',
          layout: {
            'line-join': 'round',
            'line-cap': 'round'
          },
          paint: {
            'line-color': '#3887be',
            'line-width': 5,
            'line-opacity': 0.75
          }
        });

        // Ajustar el mapa para mostrar toda la ruta
        const bounds = new mapboxgl.LngLatBounds();
        bounds.extend(origin);
        bounds.extend(destination);
        map.fitBounds(bounds, { padding: 50 });
      }
    } catch (error) {
      console.error('Error al dibujar la ruta:', error);
    }
  }

  /**
   * Geocodificar una dirección
   */
  async geocode(address: string): Promise<[number, number] | null> {
    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(address)}.json?access_token=${this.accessToken}&limit=1`;

    try {
      const response = await fetch(url);
      const data = await response.json();

      if (data.features && data.features.length > 0) {
        const coordinates = data.features[0].geometry.coordinates;
        return [coordinates[0], coordinates[1]];
      }
      return null;
    } catch (error) {
      console.error('Error al geocodificar:', error);
      return null;
    }
  }

  /**
   * Reverse geocoding (coordenadas a dirección)
   */
  async reverseGeocode(coordinates: [number, number]): Promise<string | null> {
    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${coordinates[0]},${coordinates[1]}.json?access_token=${this.accessToken}`;

    try {
      const response = await fetch(url);
      const data = await response.json();

      if (data.features && data.features.length > 0) {
        return data.features[0].place_name;
      }
      return null;
    } catch (error) {
      console.error('Error en reverse geocoding:', error);
      return null;
    }
  }
}

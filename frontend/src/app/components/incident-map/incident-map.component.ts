import { Component, Input, OnInit, AfterViewInit } from '@angular/core';
import * as mapboxgl from 'mapbox-gl';
import { MapboxService } from '../../services/mapbox.service';

@Component({
  selector: 'app-incident-map',
  templateUrl: './incident-map.component.html',
  styleUrls: ['./incident-map.component.css']
})
export class IncidentMapComponent implements OnInit, AfterViewInit {
  @Input() incident: any;
  @Input() height: string = '400px';

  map!: mapboxgl.Map;
  private mapInitialized = false;

  constructor(private mapboxService: MapboxService) { }

  ngOnInit(): void {
  }

  ngAfterViewInit(): void {
    this.initializeMap();
  }

  private initializeMap(): void {
    if (!this.incident || !this.incident.latitude || !this.incident.longitude) {
      console.warn('No hay coordenadas para mostrar en el mapa');
      return;
    }

    const center: [number, number] = [this.incident.longitude, this.incident.latitude];

    // Crear el mapa
    this.map = this.mapboxService.createMap('incident-map', center, 14);

    // Esperar a que el mapa se cargue
    this.map.on('load', () => {
      this.mapInitialized = true;

      // Agregar marcador del incidente
      this.mapboxService.addMarker(
        this.map,
        center,
        '#FF0000',
        `<strong>Incidente #${this.incident.id}</strong><br>${this.incident.description}`
      );

      // Si hay un taller asignado, agregar marcador y ruta
      if (this.incident.workshop) {
        const workshopCoords: [number, number] = [
          this.incident.workshop.longitude,
          this.incident.workshop.latitude
        ];

        this.mapboxService.addMarker(
          this.map,
          workshopCoords,
          '#00FF00',
          `<strong>${this.incident.workshop.name}</strong><br>${this.incident.workshop.address}`
        );

        // Dibujar ruta
        this.mapboxService.drawRoute(this.map, workshopCoords, center);
      }
    });
  }

  ngOnDestroy(): void {
    if (this.map) {
      this.map.remove();
    }
  }
}

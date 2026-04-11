import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { IncidentService } from '../../services/incident.service';
import { AuthService } from '../../services/auth.service';
import { Incident } from '../../models/models';

@Component({
  selector: 'app-incident-list',
  templateUrl: './incident-list.component.html',
  styleUrls: ['./incident-list.component.css']
})
export class IncidentListComponent implements OnInit {
  incidents: Incident[] = [];
  loading = true;
  error = '';
  selectedStatus = '';

  constructor(
    private incidentService: IncidentService,
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.loadIncidents();
  }

  loadIncidents(): void {
    this.loading = true;
    this.error = '';
    
    this.incidentService.getIncidents(this.selectedStatus || undefined).subscribe({
      next: (incidents) => {
        this.incidents = incidents;
        this.loading = false;
      },
      error: (error) => {
        this.error = 'Error al cargar incidentes';
        this.loading = false;
      }
    });
  }

  filterByStatus(status: string): void {
    this.selectedStatus = status;
    this.loadIncidents();
  }

  getStatusClass(status: string): string {
    const statusMap: { [key: string]: string } = {
      'pending': 'badge-pending',
      'accepted': 'badge-accepted',
      'in_progress': 'badge-in-progress',
      'completed': 'badge-completed',
      'cancelled': 'badge-cancelled'
    };
    return statusMap[status] || 'badge-pending';
  }

  getStatusText(status: string): string {
    const statusMap: { [key: string]: string } = {
      'pending': 'Pendiente',
      'accepted': 'Aceptada',
      'in_progress': 'En Proceso',
      'completed': 'Completada',
      'cancelled': 'Cancelada'
    };
    return statusMap[status] || status;
  }

  getPriorityClass(priority: string): string {
    const priorityMap: { [key: string]: string } = {
      'low': 'priority-low',
      'medium': 'priority-medium',
      'high': 'priority-high'
    };
    return priorityMap[priority] || 'priority-medium';
  }

  getPriorityText(priority: string): string {
    const priorityMap: { [key: string]: string } = {
      'low': '🟢 Baja',
      'medium': '🟡 Media',
      'high': '🔴 Alta'
    };
    return priorityMap[priority] || '🟡 Media';
  }

  updateStatus(incident: Incident, newStatus: string): void {
    this.incidentService.updateIncident(incident.id, { status: newStatus }).subscribe({
      next: () => {
        this.loadIncidents();
      },
      error: (error) => {
        console.error('Error updating incident:', error);
        this.error = 'Error al actualizar el estado del incidente';
      }
    });
  }

  cancelIncident(incident: Incident): void {
    if (confirm('¿Estás seguro de que deseas cancelar esta emergencia?')) {
      this.incidentService.cancelIncident(incident.id).subscribe({
        next: () => {
          this.loadIncidents();
        },
        error: (error) => {
          console.error('Error canceling incident:', error);
          this.error = 'Error al cancelar el incidente';
        }
      });
    }
  }

  viewDetails(incident: Incident): void {
    // Navigate to incident details page
    this.router.navigate(['/incidents', incident.id]);
  }

  isClient(): boolean {
    const user = this.authService.currentUserValue;
    return user?.role === 'client';
  }
}

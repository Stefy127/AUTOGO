import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { WorkshopService } from '../../services/workshop.service';
import { IncidentService } from '../../services/incident.service';
import { Workshop, Technician, Incident, WorkshopStats } from '../../models/models';
import { LocationData } from '../map-picker/map-picker.component';

@Component({
  selector: 'app-workshop-dashboard',
  templateUrl: './workshop-dashboard.component.html',
  styleUrls: ['./workshop-dashboard.component.css']
})
export class WorkshopDashboardComponent implements OnInit {
  workshop: Workshop | null = null;
  technicians: Technician[] = [];
  availableIncidents: Incident[] = [];
  myIncidents: Incident[] = [];
  incidentHistory: Incident[] = [];
  stats: WorkshopStats | null = null;
  
  loading = true;
  error = '';

  workshopForm = {
    name: '',
    address: '',
    phone: '',
    latitude: undefined as number | undefined,
    longitude: undefined as number | undefined
  };

  technicianForm = {
    name: '',
    phone: ''
  };

  // Accept incident modal state
  showAcceptModal = false;
  selectedIncident: Incident | null = null;
  acceptForm = {
    technician_id: undefined as number | undefined,
    estimated_amount: undefined as number | undefined
  };

  // Navigation state
  currentView: 'dashboard' | 'edit-info' | 'add-technician' | 'incidents-available' | 'incidents-history' = 'dashboard';

  constructor(
    private authService: AuthService,
    private workshopService: WorkshopService,
    private incidentService: IncidentService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.loadAllData();
  }

  loadAllData(): void {
    this.loading = true;
    this.error = '';

    // Load workshop info
    this.workshopService.getMyWorkshop().subscribe({
      next: (workshop) => {
        this.workshop = workshop;
        this.workshopForm = {
          name: workshop.name,
          address: workshop.address || '',
          phone: workshop.phone || '',
          latitude: workshop.latitude,
          longitude: workshop.longitude
        };
        this.loadTechnicians();
        this.loadStats();
        this.loadAvailableIncidents();
        this.loadMyIncidents();
        this.loading = false;
      },
      error: (error) => {
        if (error.status === 404) {
          // No workshop profile yet - show edit form with defaults
          this.workshop = null;
          this.workshopForm = {
            name: '',
            address: '',
            phone: '',
            latitude: 19.432608,
            longitude: -99.133209
          };
          this.currentView = 'edit-info';
          this.error = '⚠️ Completa la información de tu taller para comenzar';
        } else {
          this.error = 'Error al cargar datos del taller';
        }
        this.loading = false;
      }
    });
  }

  loadTechnicians(): void {
    this.workshopService.getMyTechnicians().subscribe({
      next: (technicians) => {
        this.technicians = technicians;
      },
      error: (error) => {
        console.error('Error loading technicians:', error);
      }
    });
  }

  loadStats(): void {
    this.workshopService.getMyStats().subscribe({
      next: (stats) => {
        this.stats = stats;
      },
      error: (error) => {
        console.error('Error loading stats:', error);
      }
    });
  }

  loadAvailableIncidents(): void {
    this.workshopService.getAvailableIncidents().subscribe({
      next: (incidents) => {
        this.availableIncidents = incidents;
        this.loading = false;
      },
      error: (error) => {
        console.error('Error loading available incidents:', error);
        this.loading = false;
      }
    });
  }

  loadMyIncidents(): void {
    // Get all incidents assigned to this workshop
    this.workshopService.getMyIncidents().subscribe({
      next: (incidents) => {
        this.myIncidents = incidents.filter(i => i.workshop_id != null);
      },
      error: (error) => {
        console.error('Error loading my incidents:', error);
      }
    });
  }

  loadIncidentHistory(): void {
    // Load complete history of all incidents
    this.incidentService.getIncidents().subscribe({
      next: (incidents) => {
        // Filter only completed/cancelled incidents with this workshop
        this.incidentHistory = incidents.filter(i => 
          i.workshop_id === this.workshop?.id && 
          (i.status === 'completed' || i.status === 'cancelled')
        );
      },
      error: (error) => {
        console.error('Error loading incident history:', error);
      }
    });
  }

  navigateTo(view: 'dashboard' | 'edit-info' | 'add-technician' | 'incidents-available' | 'incidents-history'): void {
    this.currentView = view;
    if (view === 'incidents-history') {
      this.loadIncidentHistory();
    }
  }

  saveWorkshopInfo(): void {
    if (!this.workshopForm.name || !this.workshopForm.address) {
      this.error = 'Nombre y dirección son obligatorios';
      return;
    }

    const workshopData = {
      name: this.workshopForm.name,
      address: this.workshopForm.address,
      phone: this.workshopForm.phone,
      latitude: this.workshopForm.latitude,
      longitude: this.workshopForm.longitude
    };

    if (this.workshop) {
      // Update existing
      this.workshopService.updateMyWorkshop(workshopData).subscribe({
        next: (workshop) => {
          this.workshop = workshop;
          this.currentView = 'dashboard';
          this.error = '';
          this.loadAllData(); // Reload all data
        },
        error: (error) => {
          this.error = 'Error al actualizar el taller';
        }
      });
    } else {
      // Create new
      this.workshopService.createWorkshop(workshopData).subscribe({
        next: (workshop) => {
          this.workshop = workshop;
          this.currentView = 'dashboard';
          this.error = '';
          this.loadAllData(); // Reload all data
        },
        error: (error) => {
          this.error = 'Error al crear el taller';
        }
      });
    }
  }

  onLocationSelected(location: LocationData): void {
    this.workshopForm.address = location.address;
    this.workshopForm.latitude = location.latitude;
    this.workshopForm.longitude = location.longitude;
  }

  addTechnician(): void {
    if (!this.technicianForm.name) {
      this.error = 'El nombre del mecánico es obligatorio';
      return;
    }

    this.workshopService.addTechnician(this.technicianForm).subscribe({
      next: (technician) => {
        this.technicians.push(technician);
        this.technicianForm = { name: '', phone: '' };
        this.currentView = 'dashboard';
        this.error = '';
        this.loadStats(); // Refresh stats
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al agregar mecánico';
        console.error('Error detail:', error);
      }
    });
  }

  // Calculate total earnings from completed incidents
  getTotalEarnings(): number {
    return this.myIncidents
      .filter(i => i.status === 'completed' && i.payment)
      .reduce((sum, i) => sum + (i.payment?.workshop_earnings || 0), 0);
  }

  // Get technician stats for progress bars
  getTechnicianStats(): Array<{name: string, incidents: number, percentage: number}> {
    if (this.technicians.length === 0 || this.myIncidents.length === 0) {
      return [];
    }

    const total = this.myIncidents.filter(i => i.status === 'completed').length;
    
    return this.technicians.map(tech => {
      const techIncidents = this.myIncidents.filter(
        i => i.technician_id === tech.id && i.status === 'completed'
      ).length;
      
      return {
        name: tech.name,
        incidents: techIncidents,
        percentage: total > 0 ? (techIncidents / total) * 100 : 0
      };
    }).sort((a, b) => b.incidents - a.incidents);
  }

  acceptIncident(incident: Incident): void {
    // Open modal to select technician and set estimated amount
    this.selectedIncident = incident;
    this.showAcceptModal = true;
    
    // Reset form
    this.acceptForm = {
      technician_id: this.technicians.length > 0 ? this.technicians[0].id : undefined,
      estimated_amount: undefined
    };
  }

  confirmAcceptIncident(): void {
    if (!this.selectedIncident?.id || !this.acceptForm.technician_id || !this.acceptForm.estimated_amount) {
      this.error = 'Debes seleccionar un mecánico e ingresar el monto estimado';
      return;
    }

    // Asegurar que estimated_amount sea un número
    const amount = typeof this.acceptForm.estimated_amount === 'string' 
      ? parseFloat(this.acceptForm.estimated_amount) 
      : this.acceptForm.estimated_amount;

    if (isNaN(amount) || amount <= 0) {
      this.error = 'El monto debe ser un número válido mayor que 0';
      return;
    }

    this.workshopService.acceptIncident(
      this.selectedIncident.id, 
      this.acceptForm.technician_id,
      amount
    ).subscribe({
      next: () => {
        // Remove from available and add to my incidents
        this.availableIncidents = this.availableIncidents.filter(i => i.id !== this.selectedIncident?.id);
        this.loadMyIncidents();
        this.loadStats();
        
        // Close modal
        this.showAcceptModal = false;
        this.selectedIncident = null;
        this.error = '';
      },
      error: (error) => {
        console.error('Error al aceptar incidente:', error);
        this.error = error.error?.detail || 'Error al aceptar la emergencia';
      }
    });
  }

  cancelAcceptIncident(): void {
    this.showAcceptModal = false;
    this.selectedIncident = null;
    this.acceptForm = {
      technician_id: undefined,
      estimated_amount: undefined
    };
  }

  rejectIncident(incident: Incident): void {
    if (!incident.id) return;

    this.workshopService.rejectIncident(incident.id).subscribe({
      next: () => {
        this.availableIncidents = this.availableIncidents.filter(i => i.id !== incident.id);
      },
      error: (error) => {
        this.error = 'Error al rechazar la emergencia';
      }
    });
  }

  startIncident(incident: Incident): void {
    if (!incident.id) return;
    
    if (confirm('¿Iniciar esta emergencia? El mecánico comenzará el servicio.')) {
      this.incidentService.startIncident(incident.id).subscribe({
        next: () => {
          this.loadMyIncidents();
          this.loadStats();
        },
        error: (error) => {
          this.error = error.error?.detail || 'Error al iniciar la emergencia';
        }
      });
    }
  }

  completeIncident(incident: Incident): void {
    if (!incident.id) return;
    
    if (confirm('¿Marcar como completada? El mecánico quedará disponible nuevamente.')) {
      this.incidentService.completeIncident(incident.id).subscribe({
        next: () => {
          // Reload all data
          this.loadMyIncidents();
          this.loadIncidentHistory();
          this.loadStats();
          this.loadTechnicians();
        },
        error: (error) => {
          this.error = error.error?.detail || 'Error al completar la emergencia';
        }
      });
    }
  }

  getStatusClass(status: string): string {
    const statusMap: { [key: string]: string } = {
      pending: 'badge-pending',
      accepted: 'badge-accepted',
      in_progress: 'badge-progress',
      completed: 'badge-completed',
      cancelled: 'badge-cancelled'
    };
    return statusMap[status] || 'badge-pending';
  }

  getStatusText(status: string): string {
    const statusMap: { [key: string]: string } = {
      pending: 'Pendiente',
      accepted: 'Aceptada',
      in_progress: 'En Proceso',
      completed: 'Completada',
      cancelled: 'Cancelada'
    };
    return statusMap[status] || status;
  }

  getPriorityClass(priority: string): string {
    return `priority-${priority}`;
  }

  getPriorityText(priority: string): string {
    const priorityMap: { [key: string]: string } = {
      low: '🟢 Baja',
      medium: '🟡 Media',
      high: '🔴 Alta'
    };
    return priorityMap[priority] || priority;
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  deleteMyAccount(): void {
    const ok = confirm('¿Seguro que deseas eliminar tu cuenta? Esta acción no se puede deshacer.');
    if (!ok) return;

    this.authService.deleteMyAccount().subscribe({
      next: () => {
        this.authService.logout();
        this.router.navigate(['/login']);
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo eliminar la cuenta';
      }
    });
  }
}

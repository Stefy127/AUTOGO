import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { WorkshopService } from '../../services/workshop.service';
import { IncidentService } from '../../services/incident.service';
import { PaymentService } from '../../services/payment.service';
import { Workshop, Technician, Incident, WorkshopStats, AppNotification, CancellationPaymentPending, IncidentZoneStat } from '../../models/models';
import { LocationData } from '../map-picker/map-picker.component';

interface ServiceCategoryOption {
  value: string;
  label: string;
}

const SERVICE_CATEGORY_OPTIONS: ServiceCategoryOption[] = [
  { value: 'general_mechanics', label: 'Mecánica general' },
  { value: 'automotive_electricity', label: 'Electricidad automotriz' },
  { value: 'battery_start', label: 'Batería y arranque' },
  { value: 'tires', label: 'Llantería / Neumáticos' },
  { value: 'towing', label: 'Grúa / Remolque' },
  { value: 'locksmith', label: 'Cerrajería automotriz' },
  { value: 'fuel', label: 'Combustible' },
  { value: 'brakes', label: 'Frenos' },
  { value: 'engine', label: 'Motor' },
  { value: 'cooling', label: 'Refrigeración' },
  { value: 'transmission', label: 'Transmisión / Caja' },
  { value: 'suspension_steering', label: 'Suspensión y dirección' },
  { value: 'electronic_diagnosis', label: 'Diagnóstico electrónico' },
  { value: 'body_paint', label: 'Chaperío y pintura' },
  { value: 'roadside_assistance', label: 'Auxilio rápido en carretera' },
  { value: 'preventive_maintenance', label: 'Mantenimiento preventivo' },
  { value: 'air_conditioning', label: 'Aire acondicionado' },
  { value: 'spare_parts', label: 'Repuestos' },
];

@Component({
  selector: 'app-workshop-dashboard',
  templateUrl: './workshop-dashboard.component.html',
  styleUrls: ['./workshop-dashboard.component.css']
})
export class WorkshopDashboardComponent implements OnInit, OnDestroy {
  sidebarOpen = true;
  workshop: Workshop | null = null;
  technicians: Technician[] = [];
  availableIncidents: Incident[] = [];
  myIncidents: Incident[] = [];
  incidentHistory: Incident[] = [];
  stats: WorkshopStats | null = null;
  
  loading = true;
  error = '';
  successMessage = '';

  workshopForm = {
    name: '',
    address: '',
    phone: '',
    latitude: undefined as number | undefined,
    longitude: undefined as number | undefined,
    categories: [] as string[]
  };

  serviceCategories = SERVICE_CATEGORY_OPTIONS;

  technicianForm = {
    name: '',
    phone: ''
  };

  editingTechnicianId: number | null = null;
  technicianEditForm = {
    name: '',
    phone: '',
    is_available: true
  };

  workshopQrImageUrl = '';
  workshopQrPreviewData = '';

  notifications: AppNotification[] = [];
  unreadNotificationsCount = 0;
  loadingNotifications = false;
  cancellationPayments: CancellationPaymentPending[] = [];
  loadingCancellationPayments = false;
  private notificationPollTimer: number | null = null;

  // Accept incident modal state
  showAcceptModal = false;
  selectedIncident: Incident | null = null;
  acceptForm = {
    technician_id: undefined as number | undefined,
    diagnosis_cost: undefined as number | undefined,
    labor_cost: undefined as number | undefined,
    parts_cost: undefined as number | undefined,
    transport_cost: undefined as number | undefined,
    additional_cost: undefined as number | undefined,
    repair_time_minutes: undefined as number | undefined,
    price_explanation: '',
    notes: ''
  };

  // Navigation state
  currentView: 'dashboard' | 'edit-info' | 'add-technician' | 'incidents-available' | 'incidents-history' | 'reports' | 'notifications' | 'cancellation-payments' = 'dashboard';

  reportFilters = {
    startDate: '',
    endDate: '',
    technicianId: undefined as number | undefined
  };
  downloadingReport = false;

  constructor(
    private authService: AuthService,
    private workshopService: WorkshopService,
    private incidentService: IncidentService,
    private paymentService: PaymentService,
    private route: ActivatedRoute,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.sidebarOpen = typeof window !== 'undefined' ? window.innerWidth > 768 : true;
    this.loadAllData();
    this.route.queryParamMap.subscribe(params => {
      const requested = params.get('view');
      const allowedViews: Array<typeof this.currentView> = [
        'dashboard',
        'edit-info',
        'add-technician',
        'incidents-available',
        'incidents-history',
        'reports',
        'notifications',
        'cancellation-payments',
      ];
      if (requested && allowedViews.includes(requested as typeof this.currentView)) {
        this.navigateTo(requested as typeof this.currentView);
      }
    });
    this.startNotificationPolling();
  }

  ngOnDestroy(): void {
    this.stopNotificationPolling();
  }

  toggleSidebar(): void {
    this.sidebarOpen = !this.sidebarOpen;
  }

  loadAllData(): void {
    this.loading = true;
    this.error = '';
    this.loadNotifications(true);

    // Load workshop info
    this.workshopService.getMyWorkshop().subscribe({
      next: (workshop) => {
        this.workshop = workshop;
        this.workshopForm = {
          name: workshop.name,
          address: workshop.address || '',
          phone: workshop.phone || '',
          latitude: workshop.latitude,
          longitude: workshop.longitude,
          categories: workshop.categories || []
        };
        this.loadTechnicians();
        this.loadStats();
        this.loadAvailableIncidents();
        this.loadMyIncidents();
        this.loadPaymentQr();
        this.loadCancellationPayments(true);
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
            longitude: -99.133209,
            categories: []
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
    this.workshopService.getMyStatsWithFilters().subscribe({
      next: (stats) => {
        this.stats = stats;
      },
      error: (error) => {
        console.error('Error loading stats:', error);
      }
    });
  }

  loadPaymentQr(): void {
    this.workshopService.getMyPaymentQr().subscribe({
      next: (qrConfig) => {
        this.workshopQrImageUrl = qrConfig.qr_image_url || '';
        this.workshopQrPreviewData = this.workshopQrImageUrl;
      },
      error: () => {
        this.workshopQrImageUrl = '';
        this.workshopQrPreviewData = '';
      }
    });
  }

  onQrFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files && input.files.length > 0 ? input.files[0] : null;

    if (!file) {
      return;
    }

    if (!file.type.startsWith('image/')) {
      this.error = 'Solo se permiten archivos de imagen (PNG, JPG, WEBP, etc.)';
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const base64Image = reader.result?.toString() || '';
      if (!base64Image) {
        this.error = 'No se pudo leer la imagen seleccionada';
        return;
      }
      this.workshopQrImageUrl = base64Image;
      this.workshopQrPreviewData = base64Image;
      this.error = '';
      this.successMessage = '✅ Imagen QR lista para guardar';
      setTimeout(() => this.successMessage = '', 3000);
    };
    reader.readAsDataURL(file);
  }

  savePaymentQr(): void {
    if (!this.workshopQrImageUrl.trim()) {
      this.error = 'Selecciona o ingresa una imagen QR para el taller';
      return;
    }

    this.workshopService.saveMyPaymentQr(this.workshopQrImageUrl.trim()).subscribe({
      next: () => {
        this.error = '';
        this.workshopQrPreviewData = this.workshopQrImageUrl;
        this.successMessage = '✅ QR del taller guardado correctamente';
        setTimeout(() => this.successMessage = '', 3000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo guardar el QR del taller';
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

  navigateTo(view: typeof this.currentView): void {
    this.currentView = view;
    if (view === 'incidents-history') {
      this.loadIncidentHistory();
    }
    if (view === 'notifications') {
      this.loadNotifications();
    }
    if (view === 'cancellation-payments') {
      this.loadCancellationPayments();
    }
  }

  startNotificationPolling(): void {
    this.loadNotifications(true);
    this.stopNotificationPolling();
    this.notificationPollTimer = window.setInterval(() => {
      this.loadNotifications(true);
    }, 15000);
  }

  stopNotificationPolling(): void {
    if (this.notificationPollTimer !== null) {
      window.clearInterval(this.notificationPollTimer);
      this.notificationPollTimer = null;
    }
  }

  loadNotifications(silent = false): void {
    if (!silent) {
      this.loadingNotifications = true;
    }

    this.workshopService.getNotifications(false, 100).subscribe({
      next: (notifications) => {
        this.notifications = notifications;
        this.unreadNotificationsCount = notifications.filter(n => !n.is_read).length;
        this.loadingNotifications = false;
      },
      error: () => {
        this.loadingNotifications = false;
      }
    });
  }

  markNotificationAsRead(notification: AppNotification): void {
    if (notification.is_read) {
      return;
    }

    this.workshopService.markNotificationAsRead(notification.id).subscribe({
      next: (updated) => {
        this.notifications = this.notifications.map(item =>
          item.id === updated.id ? updated : item
        );
        this.unreadNotificationsCount = this.notifications.filter(n => !n.is_read).length;
      }
    });
  }

  markAllNotificationsAsRead(): void {
    this.workshopService.markAllNotificationsAsRead().subscribe({
      next: () => {
        this.notifications = this.notifications.map(item => ({ ...item, is_read: true }));
        this.unreadNotificationsCount = 0;
      }
    });
  }

  getNotificationTypeLabel(notificationType: string): string {
    const typeMap: { [key: string]: string } = {
      offer_received: 'Oferta',
      service_accepted_by_client: 'Aceptacion',
      technician_on_the_way: 'En camino',
      technician_started_service: 'Inicio',
      technician_completed_service: 'Finalizacion'
    };
    return typeMap[notificationType] || 'General';
  }

  hasIncidentImage(incident: Incident): boolean {
    const value = incident.image_url || '';
    return value.startsWith('data:image/') || /^https?:\/\//i.test(value);
  }

  getMyPendingOffer(incident: Incident) {
    if (!this.workshop?.id || !incident.offers?.length) {
      return null;
    }

    return incident.offers.find(offer =>
      offer.workshop_id === this.workshop?.id && offer.status === 'pending'
    ) || null;
  }

  hasMyPendingOffer(incident: Incident): boolean {
    return this.getMyPendingOffer(incident) !== null;
  }

  downloadReportPdf(): void {
    if (this.reportFilters.startDate && this.reportFilters.endDate && this.reportFilters.startDate > this.reportFilters.endDate) {
      this.error = 'La fecha inicial no puede ser mayor que la fecha final';
      return;
    }

    this.downloadingReport = true;
    this.error = '';

    this.workshopService.downloadIncidentsReportPdf({
      startDate: this.reportFilters.startDate || undefined,
      endDate: this.reportFilters.endDate || undefined,
      technicianId: this.reportFilters.technicianId || undefined
    }).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `reporte_emergencias_${new Date().toISOString().slice(0, 10)}.pdf`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);

        this.successMessage = '✅ Reporte PDF descargado';
        setTimeout(() => this.successMessage = '', 3000);
        this.downloadingReport = false;
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo generar el reporte PDF';
        this.downloadingReport = false;
      }
    });
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
      longitude: this.workshopForm.longitude,
      categories: this.workshopForm.categories
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

  toggleWorkshopCategory(categoryValue: string, checked: boolean): void {
    const current = new Set(this.workshopForm.categories);
    if (checked) {
      current.add(categoryValue);
    } else {
      current.delete(categoryValue);
    }
    this.workshopForm.categories = Array.from(current);
  }

  isWorkshopCategorySelected(categoryValue: string): boolean {
    return this.workshopForm.categories.includes(categoryValue);
  }

  getServiceCategoryLabel(categoryValue: string): string {
    return SERVICE_CATEGORY_OPTIONS.find(option => option.value === categoryValue)?.label || categoryValue;
  }

  formatServiceCategories(categories: string[] | null | undefined): string {
    if (!categories || categories.length === 0) {
      return '';
    }
    return categories.map((category) => this.getServiceCategoryLabel(category)).join(', ');
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

  startEditTechnician(technician: Technician): void {
    this.editingTechnicianId = technician.id;
    this.technicianEditForm = {
      name: technician.name,
      phone: technician.phone || '',
      is_available: technician.is_available
    };
  }

  cancelEditTechnician(): void {
    this.editingTechnicianId = null;
    this.technicianEditForm = {
      name: '',
      phone: '',
      is_available: true
    };
  }

  saveTechnician(technicianId: number): void {
    if (!this.technicianEditForm.name.trim()) {
      this.error = 'El nombre del mecánico es obligatorio';
      return;
    }

    this.workshopService.updateTechnician(technicianId, {
      name: this.technicianEditForm.name.trim(),
      phone: this.technicianEditForm.phone.trim() || undefined,
      is_available: this.technicianEditForm.is_available
    }).subscribe({
      next: () => {
        this.cancelEditTechnician();
        this.loadTechnicians();
        this.loadStats();
        this.error = '';
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo actualizar el técnico';
      }
    });
  }

  toggleTechnicianAvailability(technician: Technician): void {
    this.workshopService.updateTechnician(technician.id, {
      is_available: !technician.is_available
    }).subscribe({
      next: () => {
        this.loadTechnicians();
        this.loadStats();
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo cambiar disponibilidad';
      }
    });
  }

  deleteTechnician(technician: Technician): void {
    const ok = confirm(`¿Eliminar al mecánico ${technician.name}?`);
    if (!ok) return;

    this.workshopService.deleteTechnician(technician.id).subscribe({
      next: () => {
        this.loadTechnicians();
        this.loadStats();
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo eliminar el técnico';
      }
    });
  }

  copyAccessCode(code: string): void {
    navigator.clipboard.writeText(code).then(() => {
      this.successMessage = '✅ Código copiado al portapapeles';
      setTimeout(() => this.successMessage = '', 3000);
    });
  }

  regenerateAccessCode(technician: Technician): void {
    const ok = confirm(`¿Regenerar el código de acceso de ${technician.name}? El código anterior dejará de funcionar.`);
    if (!ok) return;

    this.workshopService.regenerateAccessCode(technician.id).subscribe({
      next: (updated) => {
        const idx = this.technicians.findIndex(t => t.id === technician.id);
        if (idx !== -1) {
          this.technicians[idx] = { ...this.technicians[idx], ...updated };
        }
        this.successMessage = `✅ Código regenerado para ${technician.name}`;
        setTimeout(() => this.successMessage = '', 4000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo regenerar el código';
      }
    });
  }

  // Calculate total earnings from completed incidents
  getTotalEarnings(): number {
    return this.stats?.total_earnings_usd || 0;
  }

  getIncidentStatusEntries(): Array<{ status: string; count: number }> {
    if (!this.stats?.incidents_by_status) {
      return [];
    }

    return Object.entries(this.stats.incidents_by_status)
      .map(([status, count]) => ({ status, count: count || 0 }))
      .sort((a, b) => a.status.localeCompare(b.status));
  }

  getIncidentTypeEntries(): Array<{ type: string; count: number }> {
    if (!this.stats?.incidents_by_type) {
      return [];
    }

    return Object.entries(this.stats.incidents_by_type)
      .map(([type, count]) => ({ type, count: count || 0 }))
      .sort((a, b) => b.count - a.count || a.type.localeCompare(b.type));
  }

  getTopIncidentZones(): IncidentZoneStat[] {
    return this.stats?.top_incident_zones || [];
  }

  getWorkshopEfficiencySummary(): {
    completed_incidents: number;
    average_arrival_time_minutes: number;
    average_service_time_minutes: number;
    efficiency_score: number;
  } {
    return this.stats?.workshop_efficiency_summary || {
      completed_incidents: 0,
      average_arrival_time_minutes: 0,
      average_service_time_minutes: 0,
      efficiency_score: 0,
    };
  }

  formatMinutes(value?: number | null): string {
    const minutes = value || 0;
    if (!minutes || Number.isNaN(minutes)) {
      return '0 min';
    }
    return `${minutes.toFixed(1)} min`;
  }

  formatPercent(value?: number | null): string {
    const percentage = value || 0;
    if (!percentage || Number.isNaN(percentage)) {
      return '0%';
    }
    return `${percentage.toFixed(1)}%`;
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
      diagnosis_cost: undefined,
      labor_cost: undefined,
      parts_cost: undefined,
      transport_cost: undefined,
      additional_cost: undefined,
      repair_time_minutes: undefined,
      price_explanation: '',
      notes: ''
    };
  }

  private parseQuoteAmount(value: number | string | undefined): number {
    if (value === undefined || value === null || value === '') {
      return 0;
    }
    const parsed = typeof value === 'string' ? parseFloat(value) : value;
    return isNaN(parsed) ? 0 : parsed;
  }

  getQuoteTotal(): number {
    return [
      this.acceptForm.diagnosis_cost,
      this.acceptForm.labor_cost,
      this.acceptForm.parts_cost,
      this.acceptForm.transport_cost,
      this.acceptForm.additional_cost
    ].reduce<number>((total, value) => total + this.parseQuoteAmount(value), 0);
  }

  confirmAcceptIncident(): void {
    if (!this.selectedIncident?.id || !this.acceptForm.technician_id) {
      this.error = 'Debes seleccionar un mecanico';
      return;
    }

    const quotePayload = {
      technician_id: this.acceptForm.technician_id,
      diagnosis_cost: this.parseQuoteAmount(this.acceptForm.diagnosis_cost),
      labor_cost: this.parseQuoteAmount(this.acceptForm.labor_cost),
      parts_cost: this.parseQuoteAmount(this.acceptForm.parts_cost),
      transport_cost: this.parseQuoteAmount(this.acceptForm.transport_cost),
      additional_cost: this.parseQuoteAmount(this.acceptForm.additional_cost),
      repair_time_minutes: this.acceptForm.repair_time_minutes
        ? Number(this.acceptForm.repair_time_minutes)
        : undefined,
      price_explanation: this.acceptForm.price_explanation?.trim() || undefined,
      notes: this.acceptForm.notes?.trim() || undefined
    };

    if (this.getQuoteTotal() <= 0) {
      this.error = 'La cotizacion debe tener un monto total mayor a 0';
      return;
    }

    this.workshopService.createOffer(
      this.selectedIncident.id,
      quotePayload
    ).subscribe({
      next: () => {
        this.loadAvailableIncidents();
        this.loadMyIncidents();
        this.loadStats();
        this.loadTechnicians();
        
        // Close modal
        this.showAcceptModal = false;
        this.selectedIncident = null;
        this.error = '';
      },
      error: (error) => {
        console.error('Error al aceptar incidente:', error);
        this.error = error.error?.detail || 'Error al enviar la oferta';
      }
    });
  }

  loadCancellationPayments(silent = false): void {
    if (!silent) {
      this.loadingCancellationPayments = true;
    }

    this.paymentService.getPendingCancellationPayments().subscribe({
      next: (payments) => {
        this.cancellationPayments = payments;
        this.loadingCancellationPayments = false;
      },
      error: (error) => {
        console.error('Error loading cancellation payments:', error);
        this.loadingCancellationPayments = false;
      }
    });
  }

  verifyCancellationPayment(payment: CancellationPaymentPending, approved: boolean): void {
    const notes = approved ? 'Pago verificado correctamente' : prompt('Motivo del rechazo') || undefined;
    if (!approved && !notes) {
      return;
    }

    this.paymentService.verifyCancellationQrPayment(payment.payment_id, approved, notes).subscribe({
      next: (response) => {
        this.successMessage = response.message;
        this.error = '';
        this.loadCancellationPayments(true);
        this.loadNotifications(true);
        setTimeout(() => this.successMessage = '', 3000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo actualizar el pago por cancelacion';
      }
    });
  }
  cancelAcceptIncident(): void {
    this.showAcceptModal = false;
    this.selectedIncident = null;
    this.acceptForm = {
      technician_id: undefined,
      diagnosis_cost: undefined,
      labor_cost: undefined,
      parts_cost: undefined,
      transport_cost: undefined,
      additional_cost: undefined,
      repair_time_minutes: undefined,
      price_explanation: '',
      notes: ''
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

  cancelAssignedService(incident: Incident): void {
    if (!incident.id) return;

    const reason = prompt('Motivo opcional de cancelacion') || undefined;
    this.incidentService.cancelIncident(incident.id, reason).subscribe({
      next: (response) => {
        this.successMessage = response.message || 'Servicio cancelado. La emergencia volvera a espera de cotizaciones.';
        this.error = '';
        this.loadMyIncidents();
        this.loadAvailableIncidents();
        this.loadTechnicians();
        this.loadNotifications(true);
        setTimeout(() => this.successMessage = '', 4000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo cancelar el servicio';
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
      waiting_offers: 'badge-pending',
      assigned: 'badge-accepted',
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
      waiting_offers: 'Esperando Ofertas',
      assigned: 'Asignada',
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

  getPaymentMethodText(method?: string): string {
    const paymentMethod = method || '';
    const methodMap: { [key: string]: string } = {
      cash: 'Efectivo',
      transfer: 'Transferencia',
      qr: 'QR'
    };
    return methodMap[paymentMethod] || 'No definido';
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


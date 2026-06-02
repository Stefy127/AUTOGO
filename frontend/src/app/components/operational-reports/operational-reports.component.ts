import { Component, NgZone, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../services/auth.service';
import { ReportsService } from '../../services/reports.service';
import { WorkshopService } from '../../services/workshop.service';
import {
  AppNotification,
  OperationalReportItem,
  OperationalReportRequest,
  OperationalReportResponse,
  OperationalReportSummary,
  User,
  VoiceReportParseResponse,
  Workshop,
} from '../../models/models';

@Component({
  selector: 'app-operational-reports',
  templateUrl: './operational-reports.component.html',
  styleUrls: ['./operational-reports.component.css']
})
export class OperationalReportsComponent implements OnInit {
  private recognition: any = null;
  private voiceSessionId = 0;
  private voiceHadResult = false;
  private voiceTimeout: any = null;

  currentUser: User | null = null;
  workshop: Workshop | null = null;
  sidebarOpen = true;
  loading = false;
  exportingPdf = false;
  exportingExcel = false;
  error = '';
  successMessage = '';

  voiceSupported = false;
  voiceListening = false;
  voiceProcessing = false;
  voiceError: string | null = null;
  lastVoiceErrorRaw: string | null = null;
  recognizedVoiceText: string | null = null;
  voiceWarnings: string[] = [];
  typedCommand = '';
  commandProcessing = false;

  notifications: AppNotification[] = [];
  unreadNotificationsCount = 0;

  report: OperationalReportResponse | null = null;
  items: OperationalReportItem[] = [];

  readonly statusOptions = [
    { value: '', label: 'Todos' },
    { value: 'pending', label: 'Pendiente' },
    { value: 'waiting_offers', label: 'Esperando ofertas' },
    { value: 'assigned', label: 'Asignado' },
    { value: 'accepted', label: 'Aceptado' },
    { value: 'in_progress', label: 'En progreso' },
    { value: 'completed', label: 'Completado' },
    { value: 'cancelled', label: 'Cancelado' }
  ];

  readonly paymentMethodOptions = [
    { value: '', label: 'Todos' },
    { value: 'cash', label: 'Efectivo' },
    { value: 'transfer', label: 'Transferencia' },
    { value: 'qr', label: 'QR' }
  ];

  filters = {
    start_date: '',
    end_date: '',
    incident_type: '',
    status: '',
    payment_method: '',
    workshop_id: undefined as number | undefined,
    technician_id: undefined as number | undefined,
    client_id: undefined as number | undefined,
    vehicle_id: undefined as number | undefined,
  };

  constructor(
    private authService: AuthService,
    private reportsService: ReportsService,
    private workshopService: WorkshopService,
    private router: Router,
    private ngZone: NgZone
  ) {}

  ngOnInit(): void {
    this.sidebarOpen = typeof window !== 'undefined' ? window.innerWidth > 900 : true;
    this.authService.currentUser.subscribe(user => {
      this.currentUser = user;
      if (user && user.role !== 'admin' && user.role !== 'workshop') {
        this.router.navigate(['/dashboard']);
      }
      if (user?.role === 'workshop') {
        this.loadWorkshopProfile();
        this.loadWorkshopNotifications();
      }
    });
    this.initVoiceSupport();
  }

  isAdmin(): boolean {
    return this.currentUser?.role === 'admin';
  }

  isWorkshop(): boolean {
    return this.currentUser?.role === 'workshop';
  }

  get workshopName(): string {
    return this.workshop?.name || 'Mi Taller';
  }

  get roleDescription(): string {
    if (this.isAdmin()) {
      return 'Consulta reportes globales del sistema con filtros avanzados.';
    }
    return 'Consulta reportes operacionales de tu taller con filtros por estado, tipo y técnico.';
  }

  get summary(): OperationalReportSummary {
    return this.report?.summary ?? {
      total_incidents: 0,
      pending: 0,
      waiting_offers: 0,
      assigned: 0,
      accepted: 0,
      in_progress: 0,
      completed: 0,
      cancelled: 0,
      total_amount: 0,
      total_workshop_earnings: 0,
      total_paid: 0,
      total_unpaid: 0,
    };
  }

  buildPayload(): OperationalReportRequest {
    const toPositiveIntOrUndefined = (value: unknown): number | undefined => {
      if (value === null || value === undefined || value === '') return undefined;
      const num = Number(value);
      return Number.isInteger(num) && num > 0 ? num : undefined;
    };

    const technicianId = toPositiveIntOrUndefined(this.filters.technician_id);
    const vehicleId = toPositiveIntOrUndefined(this.filters.vehicle_id);
    const workshopId = toPositiveIntOrUndefined(this.filters.workshop_id);
    const clientId = toPositiveIntOrUndefined(this.filters.client_id);

    if (
      (this.filters.technician_id !== undefined && technicianId === undefined) ||
      (this.filters.vehicle_id !== undefined && vehicleId === undefined) ||
      (this.isAdmin() && this.filters.workshop_id !== undefined && workshopId === undefined) ||
      (this.isAdmin() && this.filters.client_id !== undefined && clientId === undefined)
    ) {
      this.error = 'Los filtros por ID deben ser enteros positivos mayores a 0.';
    }

    const payload: OperationalReportRequest = {
      start_date: this.filters.start_date || undefined,
      end_date: this.filters.end_date || undefined,
      incident_type: this.filters.incident_type.trim() || undefined,
      status: this.filters.status || undefined,
      payment_method: (this.filters.payment_method || undefined) as OperationalReportRequest['payment_method'],
      technician_id: technicianId,
      vehicle_id: vehicleId,
    };

    if (this.isAdmin()) {
      payload.workshop_id = workshopId;
      payload.client_id = clientId;
    }

    console.log('report payload:', payload);

    return payload;
  }

  queryReports(onDone?: () => void): void {
    this.loading = true;
    this.error = '';
    this.successMessage = '';

    this.reportsService.queryOperationalReport(this.buildPayload()).subscribe({
      next: (response) => {
        this.report = response;
        this.items = response.items || [];
        this.loading = false;
        onDone?.();
      },
      error: (err) => {
        this.error = err?.error?.detail || 'No se pudo consultar el reporte operacional.';
        this.loading = false;
        onDone?.();
      }
    });
  }

  clearFilters(): void {
    this.filters = {
      start_date: '',
      end_date: '',
      incident_type: '',
      status: '',
      payment_method: '',
      workshop_id: undefined,
      technician_id: undefined,
      client_id: undefined,
      vehicle_id: undefined,
    };
    this.report = null;
    this.items = [];
    this.error = '';
    this.successMessage = '';
  }

  exportPdf(onDone?: () => void): void {
    this.exportingPdf = true;
    this.error = '';

    this.reportsService.exportOperationalReportPdf(this.buildPayload()).subscribe({
      next: (blob) => {
        this.downloadBlob(blob, 'reporte_operacional.pdf');
        this.exportingPdf = false;
        this.successMessage = 'Reporte PDF descargado correctamente.';
        setTimeout(() => this.successMessage = '', 3000);
        onDone?.();
      },
      error: (err) => {
        this.error = err?.error?.detail || 'No se pudo descargar el PDF.';
        this.exportingPdf = false;
        onDone?.();
      }
    });
  }

  exportExcel(onDone?: () => void): void {
    this.exportingExcel = true;
    this.error = '';

    this.reportsService.exportOperationalReportExcel(this.buildPayload()).subscribe({
      next: (blob) => {
        this.downloadBlob(blob, 'reporte_operacional.xlsx');
        this.exportingExcel = false;
        this.successMessage = 'Reporte Excel descargado correctamente.';
        setTimeout(() => this.successMessage = '', 3000);
        onDone?.();
      },
      error: (err) => {
        this.error = err?.error?.detail || 'No se pudo descargar el Excel.';
        this.exportingExcel = false;
        onDone?.();
      }
    });
  }

  startVoiceCommand(): void {
    if (!this.voiceSupported) {
      this.voiceError = 'Tu navegador no soporta reconocimiento de voz. Usa Chrome o Edge.';
      return;
    }

    if (this.voiceListening || this.voiceProcessing) {
      return;
    }

    const sessionId = ++this.voiceSessionId;
    this.cleanupRecognition();

    this.voiceListening = true;
    this.voiceProcessing = false;
    this.voiceError = null;
    this.lastVoiceErrorRaw = null;
    this.voiceHadResult = false;
    this.recognizedVoiceText = null;
    this.voiceWarnings = [];

    const Recognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    const recognition = new Recognition();
    this.recognition = recognition;

    recognition.lang = 'es-ES';
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    recognition.continuous = false;

    recognition.onstart = () => {
      if (this.voiceSessionId !== sessionId) return;
      this.ngZone.run(() => {
        console.log('voice start');
        this.voiceListening = true;
        this.voiceProcessing = false;
      });
    };

    recognition.onresult = (event: any) => {
      if (this.voiceSessionId !== sessionId) return;
      this.ngZone.run(async () => {
        const text = event?.results?.[0]?.[0]?.transcript?.toString().trim() ?? '';
        console.log('voice result:', text);
        this.voiceHadResult = true;
        this.voiceListening = false;
        this.voiceProcessing = true;
        this.recognizedVoiceText = text;
        if (this.voiceTimeout) {
          clearTimeout(this.voiceTimeout);
          this.voiceTimeout = null;
        }
        await this.processReportCommand(text, sessionId);
      });
    };

    recognition.onerror = (event: any) => {
      if (this.voiceSessionId !== sessionId) return;
      this.ngZone.run(() => {
        const rawError = event?.error?.toString() ?? 'unknown';
        console.log('voice error:', rawError);
        this.lastVoiceErrorRaw = rawError;
        if (this.voiceTimeout) {
          clearTimeout(this.voiceTimeout);
          this.voiceTimeout = null;
        }

        const hadResultOrProcessing = this.voiceHadResult || this.voiceProcessing;
        this.voiceListening = false;
        this.voiceProcessing = false;

        if (rawError === 'aborted' && hadResultOrProcessing) {
          this.cleanupRecognition();
          return;
        }

        this.voiceError = this.mapSpeechError(rawError);
        this.cleanupRecognition();
      });
    };

    recognition.onend = () => {
      if (this.voiceSessionId !== sessionId) return;
      this.ngZone.run(() => {
        console.log('voice end');
        if (this.voiceTimeout) {
          clearTimeout(this.voiceTimeout);
          this.voiceTimeout = null;
        }
        if (!this.voiceProcessing) {
          this.voiceListening = false;
        }
        this.cleanupRecognition();
      });
    };

    this.voiceTimeout = setTimeout(() => {
      if (this.voiceListening && !this.voiceProcessing && this.voiceSessionId === sessionId) {
        try {
          this.recognition?.stop();
        } catch {}
        this.ngZone.run(() => {
          this.voiceListening = false;
          this.voiceProcessing = false;
          this.voiceError = 'No se recibió audio a tiempo. Intenta nuevamente.';
          this.cleanupRecognition();
        });
      }
    }, 12000);

    recognition.start();
  }

  private initVoiceSupport(): void {
    const SpeechRecognitionConstructor =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    this.voiceSupported = !!SpeechRecognitionConstructor;
  }

  async applyTypedCommand(): Promise<void> {
    const text = (this.typedCommand || '').trim();
    if (!text || this.commandProcessing || this.voiceProcessing || this.voiceListening) {
      return;
    }
    const sessionId = ++this.voiceSessionId;
    this.commandProcessing = true;
    this.voiceError = null;
    this.lastVoiceErrorRaw = null;
    this.voiceWarnings = [];
    this.recognizedVoiceText = null;

    try {
      await this.processReportCommand(text, sessionId);
    } finally {
      this.commandProcessing = false;
    }
  }

  private async processReportCommand(text: string, sessionId: number): Promise<void> {
    try {
      const res = await firstValueFrom(this.reportsService.voiceParse({ text }));
      if (this.voiceSessionId !== sessionId) return;
      console.log('voice-parse response filters:', res.filters);

      this.recognizedVoiceText = text;
      this.applyVoiceFilters(res);
      console.log('filters after applying command:', this.filters);
      this.voiceWarnings = res.warnings || [];

      if (res.action === 'query') {
        const response = await firstValueFrom(this.reportsService.queryOperationalReport(this.buildPayload()));
        if (this.voiceSessionId !== sessionId) return;
        this.report = response;
        this.items = response.items || [];
      } else if (res.action === 'pdf') {
        const blob = await firstValueFrom(this.reportsService.exportOperationalReportPdf(this.buildPayload()));
        if (this.voiceSessionId !== sessionId) return;
        this.downloadBlob(blob, 'reporte_operacional.pdf');
      } else if (res.action === 'excel') {
        const blob = await firstValueFrom(this.reportsService.exportOperationalReportExcel(this.buildPayload()));
        if (this.voiceSessionId !== sessionId) return;
        this.downloadBlob(blob, 'reporte_operacional.xlsx');
      } else {
        this.successMessage = 'Comando de voz aplicado. Revisa los filtros.';
        setTimeout(() => (this.successMessage = ''), 3000);
      }
    } catch (err: any) {
      if (this.voiceSessionId !== sessionId) return;
      this.voiceError = err?.error?.detail || 'No se pudo procesar el comando de voz.';
    } finally {
      if (this.voiceSessionId === sessionId) {
        this.voiceListening = false;
        this.voiceProcessing = false;
        this.cleanupRecognition();
      }
    }
  }

  private cleanupRecognition(): void {
    if (this.voiceTimeout) {
      clearTimeout(this.voiceTimeout);
      this.voiceTimeout = null;
    }

    if (this.recognition) {
      this.recognition.onstart = null;
      this.recognition.onresult = null;
      this.recognition.onerror = null;
      this.recognition.onend = null;
      this.recognition = null;
    }
  }

  private mapSpeechError(error: string): string {
    switch (error) {
      case 'not-allowed':
        return 'Permiso de micrófono denegado. Activa el micrófono para localhost.';
      case 'service-not-allowed':
        return 'El navegador bloqueó el servicio de reconocimiento de voz.';
      case 'no-speech':
        return 'No se detectó voz. Intenta hablar más cerca del micrófono.';
      case 'audio-capture':
        return 'No se encontró un micrófono disponible.';
      case 'network':
        return 'El servicio de reconocimiento de voz del navegador falló. Puedes reintentar o escribir el comando manualmente.';
      case 'aborted':
        return 'La escucha fue cancelada. Intenta nuevamente.';
      case 'language-not-supported':
        return 'El idioma de reconocimiento no está soportado.';
      default:
        return `No se pudo capturar la voz. Error: ${error}`;
    }
  }

  private applyVoiceFilters(res: VoiceReportParseResponse): void {
    const f = res.filters || {};
    this.filters.start_date = (f.start_date || '').toString();
    this.filters.end_date = (f.end_date || '').toString();
    this.filters.incident_type = (f.incident_type || '').toString();
    this.filters.status = (f.status || '').toString();
    this.filters.payment_method = (f.payment_method || '').toString();

    // IDs: mapear explícitamente con null/undefined-safe.
    const toPositiveIntOrUndefined = (value: unknown): number | undefined => {
      if (value === null || value === undefined || value === '') return undefined;
      const num = Number(value);
      return Number.isInteger(num) && num > 0 ? num : undefined;
    };

    const parsedTechnicianId = toPositiveIntOrUndefined(f.technician_id);
    const parsedVehicleId = toPositiveIntOrUndefined(f.vehicle_id);
    const parsedWorkshopId = toPositiveIntOrUndefined(f.workshop_id);
    const parsedClientId = toPositiveIntOrUndefined(f.client_id);

    if (parsedTechnicianId !== undefined) {
      this.filters.technician_id = parsedTechnicianId;
    }
    if (parsedVehicleId !== undefined) {
      this.filters.vehicle_id = parsedVehicleId;
    }

    if (this.isAdmin()) {
      if (parsedWorkshopId !== undefined) {
        this.filters.workshop_id = parsedWorkshopId;
      }
      if (parsedClientId !== undefined) {
        this.filters.client_id = parsedClientId;
      }
    } else {
      this.filters.workshop_id = undefined;
      this.filters.client_id = undefined;
    }
  }

  getStatusLabel(status: string): string {
    const labels: Record<string, string> = {
      pending: 'Pendiente',
      waiting_offers: 'Esperando ofertas',
      assigned: 'Asignado',
      accepted: 'Aceptado',
      in_progress: 'En progreso',
      completed: 'Completado',
      cancelled: 'Cancelado'
    };
    return labels[status] || status;
  }

  getPaymentMethodLabel(method?: string | null): string {
    if (!method) return '-';
    const labels: Record<string, string> = {
      cash: 'Efectivo',
      transfer: 'Transferencia',
      qr: 'QR'
    };
    return labels[method] || method;
  }

  toggleSidebar(): void {
    this.sidebarOpen = !this.sidebarOpen;
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
      error: () => {
        this.error = 'No se pudo eliminar la cuenta.';
      }
    });
  }

  goWorkshopView(view: 'dashboard' | 'edit-info' | 'add-technician' | 'incidents-available' | 'incidents-history' | 'reports' | 'notifications'): void {
    this.router.navigate(['/workshop'], { queryParams: { view } });
  }

  private loadWorkshopProfile(): void {
    this.workshopService.getMyWorkshop().subscribe({
      next: (workshop) => {
        this.workshop = workshop;
      },
      error: () => {
        this.workshop = null;
      }
    });
  }

  private loadWorkshopNotifications(): void {
    this.workshopService.getNotifications(true, 100).subscribe({
      next: (notifications) => {
        this.notifications = notifications;
        this.unreadNotificationsCount = notifications.filter(n => !n.is_read).length;
      },
      error: () => {
        this.notifications = [];
        this.unreadNotificationsCount = 0;
      }
    });
  }

  private downloadBlob(blob: Blob, filename: string): void {
    const url = window.URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = filename;
    document.body.appendChild(anchor);
    anchor.click();
    document.body.removeChild(anchor);
    window.URL.revokeObjectURL(url);
  }
}

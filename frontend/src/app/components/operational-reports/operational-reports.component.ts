import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { ReportsService } from '../../services/reports.service';
import {
  OperationalReportItem,
  OperationalReportRequest,
  OperationalReportResponse,
  OperationalReportSummary,
  User
} from '../../models/models';

@Component({
  selector: 'app-operational-reports',
  templateUrl: './operational-reports.component.html',
  styleUrls: ['./operational-reports.component.css']
})
export class OperationalReportsComponent implements OnInit {
  currentUser: User | null = null;
  sidebarOpen = true;
  loading = false;
  exportingPdf = false;
  exportingExcel = false;
  error = '';
  successMessage = '';

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
  };

  constructor(
    private authService: AuthService,
    private reportsService: ReportsService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.sidebarOpen = typeof window !== 'undefined' ? window.innerWidth > 900 : true;
    this.authService.currentUser.subscribe(user => {
      this.currentUser = user;
      if (user && user.role !== 'admin' && user.role !== 'workshop') {
        this.router.navigate(['/dashboard']);
      }
    });
  }

  isAdmin(): boolean {
    return this.currentUser?.role === 'admin';
  }

  isWorkshop(): boolean {
    return this.currentUser?.role === 'workshop';
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
    const payload: OperationalReportRequest = {
      start_date: this.filters.start_date || undefined,
      end_date: this.filters.end_date || undefined,
      incident_type: this.filters.incident_type.trim() || undefined,
      status: this.filters.status || undefined,
      payment_method: (this.filters.payment_method || undefined) as OperationalReportRequest['payment_method'],
      technician_id: this.filters.technician_id,
    };

    if (this.isAdmin()) {
      payload.workshop_id = this.filters.workshop_id;
      payload.client_id = this.filters.client_id;
    }

    return payload;
  }

  queryReports(): void {
    this.loading = true;
    this.error = '';
    this.successMessage = '';

    this.reportsService.queryOperationalReport(this.buildPayload()).subscribe({
      next: (response) => {
        this.report = response;
        this.items = response.items || [];
        this.loading = false;
      },
      error: (err) => {
        this.error = err?.error?.detail || 'No se pudo consultar el reporte operacional.';
        this.loading = false;
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
    };
    this.report = null;
    this.items = [];
    this.error = '';
    this.successMessage = '';
  }

  exportPdf(): void {
    this.exportingPdf = true;
    this.error = '';

    this.reportsService.exportOperationalReportPdf(this.buildPayload()).subscribe({
      next: (blob) => {
        this.downloadBlob(blob, 'reporte_operacional.pdf');
        this.exportingPdf = false;
        this.successMessage = 'Reporte PDF descargado correctamente.';
        setTimeout(() => this.successMessage = '', 3000);
      },
      error: (err) => {
        this.error = err?.error?.detail || 'No se pudo descargar el PDF.';
        this.exportingPdf = false;
      }
    });
  }

  exportExcel(): void {
    this.exportingExcel = true;
    this.error = '';

    this.reportsService.exportOperationalReportExcel(this.buildPayload()).subscribe({
      next: (blob) => {
        this.downloadBlob(blob, 'reporte_operacional.xlsx');
        this.exportingExcel = false;
        this.successMessage = 'Reporte Excel descargado correctamente.';
        setTimeout(() => this.successMessage = '', 3000);
      },
      error: (err) => {
        this.error = err?.error?.detail || 'No se pudo descargar el Excel.';
        this.exportingExcel = false;
      }
    });
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

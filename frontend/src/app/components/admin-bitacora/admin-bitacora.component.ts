import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';

import { AuditLog } from '../../models/models';
import { AuditLogService } from '../../services/audit-log.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-admin-bitacora',
  templateUrl: './admin-bitacora.component.html',
  styleUrls: ['./admin-bitacora.component.css']
})
export class AdminBitacoraComponent implements OnInit {
  logs: AuditLog[] = [];
  loading = false;
  error = '';
  sidebarOpen = true;
  filterEventType = '';
  filterSection = '';

  constructor(
    private authService: AuthService,
    private auditLogService: AuditLogService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.sidebarOpen = typeof window !== 'undefined' ? window.innerWidth > 900 : true;

    if (this.authService.currentUserValue?.role !== 'admin') {
      this.router.navigate(['/dashboard']);
      return;
    }

    this.loadLogs();
  }

  loadLogs(): void {
    this.loading = true;
    this.error = '';

    const filters = {
      event_type: this.filterEventType || undefined,
      section: this.filterSection || undefined
    };

    this.auditLogService.listLogs(filters).subscribe({
      next: (logs) => {
        this.logs = logs;
        this.loading = false;
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo cargar la bitácora';
        this.loading = false;
      }
    });
  }

  clearFilters(): void {
    this.filterEventType = '';
    this.filterSection = '';
    this.loadLogs();
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  toggleSidebar(): void {
    this.sidebarOpen = !this.sidebarOpen;
  }

  get currentUser() {
    return this.authService.currentUserValue;
  }
}

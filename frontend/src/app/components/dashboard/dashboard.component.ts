import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { IncidentService } from '../../services/incident.service';
import { AdminService } from '../../services/admin.service';
import { User, Incident, AdminStats, EfficientWorkshopStat, IncidentZoneStat } from '../../models/models';

interface DashboardStats {
  total: number;
  pending: number;
  inProgress: number;
  resolved: number;
  cancelled: number;
}

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.css']
})
export class DashboardComponent implements OnInit {
  currentUser: User | null = null;
  adminStats: AdminStats | null = null;
  stats: DashboardStats = {
    total: 0,
    pending: 0,
    inProgress: 0,
    resolved: 0,
    cancelled: 0
  };
  sidebarOpen = true;

  constructor(
    private authService: AuthService,
    private incidentService: IncidentService,
    private adminService: AdminService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.authService.currentUser.subscribe(user => {
      this.currentUser = user;
      if (user) {
        this.loadStats();
      }
    });
  }

  loadStats(): void {
    if (this.isAdmin()) {
      this.adminService.getPlatformStats().subscribe({
        next: (stats) => {
          this.adminStats = stats;
          this.stats.total = stats.total_incidents;
          this.stats.pending = stats.incidents_by_status?.['pending'] || 0;
          this.stats.inProgress = stats.active_incidents;
          this.stats.resolved = stats.completed_incidents;
          this.stats.cancelled = stats.cancelled_incidents;
        },
        error: (error) => {
          console.error('Error loading admin stats:', error);
        }
      });
      return;
    }

    this.incidentService.getIncidents().subscribe({
      next: (incidents: Incident[]) => {
        this.adminStats = null;
        this.stats.total = incidents.length;
        this.stats.pending = incidents.filter(i => i.status === 'pending').length;
        this.stats.inProgress = incidents.filter(i => i.status === 'in_progress').length;
        this.stats.resolved = incidents.filter(i => i.status === 'completed').length;
        this.stats.cancelled = incidents.filter(i => i.status === 'cancelled').length;
      },
      error: (error) => {
        console.error('Error loading stats:', error);
      }
    });
  }

  getAdminIncidentStatusEntries(): Array<{ status: string; count: number }> {
    if (!this.adminStats?.incidents_by_status) {
      return [];
    }

    return Object.entries(this.adminStats.incidents_by_status)
      .map(([status, count]) => ({ status, count: count || 0 }))
      .sort((a, b) => a.status.localeCompare(b.status));
  }

  getAdminIncidentTypeEntries(): Array<{ type: string; count: number }> {
    if (!this.adminStats?.incidents_by_type) {
      return [];
    }

    return Object.entries(this.adminStats.incidents_by_type)
      .map(([type, count]) => ({ type, count: count || 0 }))
      .sort((a, b) => b.count - a.count || a.type.localeCompare(b.type));
  }

  getTopIncidentZones(): IncidentZoneStat[] {
    return this.adminStats?.top_incident_zones || [];
  }

  getMostEfficientWorkshops(): EfficientWorkshopStat[] {
    return this.adminStats?.most_efficient_workshops || [];
  }

  getStatusText(status: string): string {
    const statusMap: { [key: string]: string } = {
      pending: 'Pendiente',
      waiting_offers: 'Esperando Ofertas',
      assigned: 'Asignada',
      accepted: 'Aceptada',
      on_route: 'En Camino',
      in_service: 'En Servicio',
      in_progress: 'En Proceso',
      completed: 'Completada',
      cancelled: 'Cancelada'
    };
    return statusMap[status] || status;
  }

  formatPercent(value?: number | null): string {
    const percentage = value || 0;
    if (!percentage || Number.isNaN(percentage)) {
      return '0%';
    }
    return `${percentage.toFixed(1)}%`;
  }

  formatMinutes(value?: number | null): string {
    const minutes = value || 0;
    if (!minutes || Number.isNaN(minutes)) {
      return '0 min';
    }
    return `${minutes.toFixed(1)} min`;
  }

  toggleSidebar(): void {
    this.sidebarOpen = !this.sidebarOpen;
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  isWorkshop(): boolean {
    return this.currentUser?.role === 'workshop';
  }

  isClient(): boolean {
    return this.currentUser?.role === 'client';
  }

  isAdmin(): boolean {
    return this.currentUser?.role === 'admin';
  }
}

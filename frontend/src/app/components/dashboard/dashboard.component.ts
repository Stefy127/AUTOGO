import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { IncidentService } from '../../services/incident.service';
import { User, Incident } from '../../models/models';

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
    this.incidentService.getIncidents().subscribe({
      next: (incidents: Incident[]) => {
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

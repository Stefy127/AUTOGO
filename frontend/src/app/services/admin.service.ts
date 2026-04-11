import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { Workshop, Incident, IncidentHistory, Payment, User } from '../models/models';

@Injectable({
  providedIn: 'root'
})
export class AdminService {
  private apiUrl = 'http://localhost:8000/admin';

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) { }

  private getHeaders(): HttpHeaders {
    const token = this.authService.getToken();
    return new HttpHeaders({
      'Authorization': `Bearer ${token}`
    });
  }

  // Workshops Management
  getAllWorkshops(isActive?: boolean): Observable<Workshop[]> {
    const url = isActive !== undefined 
      ? `${this.apiUrl}/workshops?is_active=${isActive}` 
      : `${this.apiUrl}/workshops`;
    return this.http.get<Workshop[]>(url, { headers: this.getHeaders() });
  }

  activateWorkshop(workshopId: number, isActive: boolean): Observable<any> {
    return this.http.patch(
      `${this.apiUrl}/workshops/${workshopId}/activate?is_active=${isActive}`,
      {},
      { headers: this.getHeaders() }
    );
  }

  // Incidents Management
  getAllIncidents(filters?: {
    status?: string;
    priority?: string;
    workshop_id?: number;
  }): Observable<Incident[]> {
    let url = `${this.apiUrl}/incidents`;
    const params = new URLSearchParams();
    
    if (filters) {
      if (filters.status) params.append('status', filters.status);
      if (filters.priority) params.append('priority', filters.priority);
      if (filters.workshop_id) params.append('workshop_id', filters.workshop_id.toString());
    }
    
    const queryString = params.toString();
    if (queryString) url += `?${queryString}`;
    
    return this.http.get<Incident[]>(url, { headers: this.getHeaders() });
  }

  deleteIncident(incidentId: number): Observable<any> {
    return this.http.delete(
      `${this.apiUrl}/incidents/${incidentId}`,
      { headers: this.getHeaders() }
    );
  }

  // History
  getFullHistory(incidentId?: number): Observable<IncidentHistory[]> {
    const url = incidentId 
      ? `${this.apiUrl}/history?incident_id=${incidentId}` 
      : `${this.apiUrl}/history`;
    return this.http.get<IncidentHistory[]>(url, { headers: this.getHeaders() });
  }

  // Payments
  getAllPayments(filters?: {
    is_paid?: boolean;
    workshop_id?: number;
  }): Observable<Payment[]> {
    let url = `${this.apiUrl}/payments`;
    const params = new URLSearchParams();
    
    if (filters) {
      if (filters.is_paid !== undefined) params.append('is_paid', filters.is_paid.toString());
      if (filters.workshop_id) params.append('workshop_id', filters.workshop_id.toString());
    }
    
    const queryString = params.toString();
    if (queryString) url += `?${queryString}`;
    
    return this.http.get<Payment[]>(url, { headers: this.getHeaders() });
  }

  getCommissionsReport(filters?: {
    workshop_id?: number;
    start_date?: string;
    end_date?: string;
  }): Observable<any> {
    let url = `${this.apiUrl}/payments/commissions`;
    const params = new URLSearchParams();
    
    if (filters) {
      if (filters.workshop_id) params.append('workshop_id', filters.workshop_id.toString());
      if (filters.start_date) params.append('start_date', filters.start_date);
      if (filters.end_date) params.append('end_date', filters.end_date);
    }
    
    const queryString = params.toString();
    if (queryString) url += `?${queryString}`;
    
    return this.http.get(url, { headers: this.getHeaders() });
  }

  // Statistics
  getPlatformStats(): Observable<any> {
    return this.http.get(`${this.apiUrl}/stats`, { headers: this.getHeaders() });
  }

  // Users Management
  getAllUsers(role?: string): Observable<User[]> {
    const url = role 
      ? `${this.apiUrl}/users?role=${role}` 
      : `${this.apiUrl}/users`;
    return this.http.get<User[]>(url, { headers: this.getHeaders() });
  }

  deleteUser(userId: number): Observable<any> {
    return this.http.delete(
      `${this.apiUrl}/users/${userId}`,
      { headers: this.getHeaders() }
    );
  }
}

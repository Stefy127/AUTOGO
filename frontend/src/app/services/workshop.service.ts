import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { AuthService } from './auth.service';
import { Workshop, Technician, Incident, WorkshopStats } from '../models/models';

@Injectable({
  providedIn: 'root'
})
export class WorkshopService {
  private apiUrl = environment.apiUrl;

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) { }

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('token');
    return new HttpHeaders({
      'Authorization': `Bearer ${token}`
    });
  }

  // ==================== WORKSHOP MANAGEMENT ====================

  createWorkshop(workshop: Partial<Workshop>): Observable<Workshop> {
    return this.http.post<Workshop>(
      `${this.apiUrl}/workshops`,
      workshop,
      { headers: this.getHeaders() }
    );
  }

  getMyWorkshop(): Observable<Workshop> {
    return this.http.get<Workshop>(
      `${this.apiUrl}/workshops/me`,
      { headers: this.getHeaders() }
    );
  }

  updateMyWorkshop(workshop: Partial<Workshop>): Observable<Workshop> {
    return this.http.patch<Workshop>(
      `${this.apiUrl}/workshops/me`,
      workshop,
      { headers: this.getHeaders() }
    );
  }

  // ==================== TECHNICIAN MANAGEMENT ====================

  addTechnician(technician: Partial<Technician>): Observable<Technician> {
    // Get workshop ID first, then add technician
    // The backend expects workshop_id in the URL, which is extracted from the token
    return this.http.post<Technician>(
      `${this.apiUrl}/workshops/me/technicians`,
      technician,
      { headers: this.getHeaders() }
    );
  }

  getMyTechnicians(): Observable<Technician[]> {
    return this.http.get<Technician[]>(
      `${this.apiUrl}/workshops/me/technicians`,
      { headers: this.getHeaders() }
    );
  }

  // ==================== INCIDENT MANAGEMENT ====================

  getAvailableIncidents(): Observable<Incident[]> {
    return this.http.get<Incident[]>(
      `${this.apiUrl}/workshops/incidents/available`,
      { headers: this.getHeaders() }
    );
  }

  acceptIncident(incidentId: number, technicianId: number, estimatedAmount: number): Observable<Incident> {
    const body = {
      technician_id: technicianId,
      estimated_amount: estimatedAmount
    };
    return this.http.post<Incident>(
      `${this.apiUrl}/workshops/incidents/${incidentId}/accept`,
      body,
      { headers: this.getHeaders() }
    );
  }

  rejectIncident(incidentId: number): Observable<any> {
    return this.http.post<any>(
      `${this.apiUrl}/workshops/incidents/${incidentId}/reject`,
      {},
      { headers: this.getHeaders() }
    );
  }

  getMyIncidents(): Observable<Incident[]> {
    // Get all incidents assigned to this workshop
    return this.http.get<Incident[]>(
      `${this.apiUrl}/incidents`,
      { headers: this.getHeaders() }
    );
  }

  // ==================== STATS ====================

  getMyStats(): Observable<WorkshopStats> {
    return this.http.get<WorkshopStats>(
      `${this.apiUrl}/workshops/me/stats`,
      { headers: this.getHeaders() }
    );
  }
}

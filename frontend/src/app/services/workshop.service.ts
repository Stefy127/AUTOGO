import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { AuthService } from './auth.service';
import { Workshop, Technician, Incident, WorkshopStats, WorkshopPaymentQr, Offer } from '../models/models';

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

  getMyPaymentQr(): Observable<WorkshopPaymentQr> {
    return this.http.get<WorkshopPaymentQr>(
      `${this.apiUrl}/workshops/me/payment-qr`,
      { headers: this.getHeaders() }
    );
  }

  saveMyPaymentQr(qrImageUrl: string): Observable<WorkshopPaymentQr> {
    return this.http.put<WorkshopPaymentQr>(
      `${this.apiUrl}/workshops/me/payment-qr`,
      { qr_image_url: qrImageUrl },
      { headers: this.getHeaders() }
    );
  }

  // ==================== TECHNICIAN MANAGEMENT ====================

  addTechnician(technician: Partial<Technician>): Observable<Technician> {
    return this.http.post<Technician>(
      `${this.apiUrl}/technicians`,
      technician,
      { headers: this.getHeaders() }
    );
  }

  getMyTechnicians(): Observable<Technician[]> {
    return this.http.get<Technician[]>(
      `${this.apiUrl}/technicians`,
      { headers: this.getHeaders() }
    );
  }

  updateTechnician(technicianId: number, technician: Partial<Technician>): Observable<Technician> {
    return this.http.put<Technician>(
      `${this.apiUrl}/technicians/${technicianId}`,
      technician,
      { headers: this.getHeaders() }
    );
  }

  deleteTechnician(technicianId: number): Observable<any> {
    return this.http.delete<any>(
      `${this.apiUrl}/technicians/${technicianId}`,
      { headers: this.getHeaders() }
    );
  }

  regenerateAccessCode(technicianId: number): Observable<Technician> {
    return this.http.post<Technician>(
      `${this.apiUrl}/technicians/${technicianId}/access-code/regenerate`,
      {},
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

  createOffer(incidentId: number, technicianId: number, amount: number): Observable<Offer> {
    const body = {
      technician_id: technicianId,
      amount,
      incident_id: incidentId
    };
    return this.http.post<Offer>(
      `${this.apiUrl}/offers`,
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

  downloadIncidentsReportPdf(filters: {
    startDate?: string;
    endDate?: string;
    technicianId?: number;
  }): Observable<Blob> {
    let params = new HttpParams();
    if (filters.startDate) {
      params = params.set('start_date', filters.startDate);
    }
    if (filters.endDate) {
      params = params.set('end_date', filters.endDate);
    }
    if (filters.technicianId) {
      params = params.set('technician_id', String(filters.technicianId));
    }

    return this.http.get(
      `${this.apiUrl}/workshops/me/reports/incidents/pdf`,
      {
        headers: this.getHeaders(),
        params,
        responseType: 'blob'
      }
    );
  }
}

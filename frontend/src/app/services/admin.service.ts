import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import {
  AdminWorkshopUser,
  Incident,
  IncidentHistory,
  Payment,
  Technician,
  TenantWorkshop,
  TenantWorkshopCreateRequest,
  TenantWorkshopOwnerOption,
  TenantWorkshopStatusRequest,
  TenantTechnicianCreateRequest,
  TenantTechnicianStatusRequest,
  TenantTechnicianUpdateRequest,
  TenantWorkshopUpdateRequest,
  TenantWorkshopUserRow,
  TenantWorkshopWithOwnerCreateRequest,
  User,
  Workshop
} from '../models/models';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class AdminService {
  private apiUrl = `${environment.apiUrl}/admin`;

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
  getTenantWorkshops(params?: {
    search?: string;
    is_active?: boolean;
    skip?: number;
    limit?: number;
  }): Observable<TenantWorkshop[]> {
    let httpParams = new HttpParams();
    if (params?.search) httpParams = httpParams.set('search', params.search);
    if (params?.is_active !== undefined) httpParams = httpParams.set('is_active', String(params.is_active));
    if (params?.skip !== undefined) httpParams = httpParams.set('skip', String(params.skip));
    if (params?.limit !== undefined) httpParams = httpParams.set('limit', String(params.limit));

    return this.http.get<TenantWorkshop[]>(`${this.apiUrl}/tenant/workshops`, {
      headers: this.getHeaders(),
      params: httpParams
    });
  }

  getTenantWorkshopById(workshopId: number): Observable<TenantWorkshop> {
    return this.http.get<TenantWorkshop>(`${this.apiUrl}/tenant/workshops/${workshopId}`, { headers: this.getHeaders() });
  }

  getTenantWorkshopUsers(workshopId: number): Observable<TenantWorkshopUserRow[]> {
    return this.http.get<TenantWorkshopUserRow[]>(`${this.apiUrl}/tenant/workshops/${workshopId}/users`, { headers: this.getHeaders() });
  }

  getTenantWorkshopOwners(): Observable<TenantWorkshopOwnerOption[]> {
    return this.http.get<TenantWorkshopOwnerOption[]>(`${this.apiUrl}/tenant/workshop-owners`, { headers: this.getHeaders() });
  }

  createTenantWorkshop(payload: TenantWorkshopCreateRequest): Observable<TenantWorkshop> {
    return this.http.post<TenantWorkshop>(`${this.apiUrl}/tenant/workshops`, payload, { headers: this.getHeaders() });
  }

  createTenantWorkshopWithOwner(payload: TenantWorkshopWithOwnerCreateRequest): Observable<TenantWorkshop> {
    return this.http.post<TenantWorkshop>(`${this.apiUrl}/tenant/workshops/with-owner`, payload, { headers: this.getHeaders() });
  }

  updateTenantWorkshop(workshopId: number, payload: TenantWorkshopUpdateRequest): Observable<TenantWorkshop> {
    return this.http.put<TenantWorkshop>(`${this.apiUrl}/tenant/workshops/${workshopId}`, payload, { headers: this.getHeaders() });
  }

  setTenantWorkshopStatus(workshopId: number, isActive: boolean): Observable<TenantWorkshop> {
    const payload: TenantWorkshopStatusRequest = { is_active: isActive };
    return this.http.patch<TenantWorkshop>(`${this.apiUrl}/tenant/workshops/${workshopId}/status`, payload, { headers: this.getHeaders() });
  }

  createTenantTechnician(workshopId: number, payload: TenantTechnicianCreateRequest): Observable<TenantWorkshopUserRow> {
    return this.http.post<TenantWorkshopUserRow>(`${this.apiUrl}/tenant/workshops/${workshopId}/technicians`, payload, { headers: this.getHeaders() });
  }

  updateTenantTechnician(technicianId: number, payload: TenantTechnicianUpdateRequest): Observable<TenantWorkshopUserRow> {
    return this.http.put<TenantWorkshopUserRow>(`${this.apiUrl}/tenant/technicians/${technicianId}`, payload, { headers: this.getHeaders() });
  }

  setTenantTechnicianStatus(technicianId: number, isActive: boolean): Observable<TenantWorkshopUserRow> {
    const payload: TenantTechnicianStatusRequest = { is_active: isActive };
    return this.http.patch<TenantWorkshopUserRow>(`${this.apiUrl}/tenant/technicians/${technicianId}/status`, payload, { headers: this.getHeaders() });
  }

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

  getWorkshopById(workshopId: number): Observable<Workshop> {
    return this.http.get<Workshop>(`${this.apiUrl}/workshops/${workshopId}`, { headers: this.getHeaders() });
  }

  createWorkshop(payload: {
    owner_id: number;
    name: string;
    address: string;
    latitude: number;
    longitude: number;
    commission_percentage: number;
    is_active: boolean;
  }): Observable<Workshop> {
    return this.http.post<Workshop>(`${this.apiUrl}/workshops`, payload, { headers: this.getHeaders() });
  }

  updateWorkshop(workshopId: number, payload: Partial<Workshop>): Observable<Workshop> {
    return this.http.put<Workshop>(`${this.apiUrl}/workshops/${workshopId}`, payload, { headers: this.getHeaders() });
  }

  getWorkshopUsers(workshopId: number): Observable<AdminWorkshopUser[]> {
    return this.http.get<AdminWorkshopUser[]>(`${this.apiUrl}/workshops/${workshopId}/users`, { headers: this.getHeaders() });
  }

  createWorkshopUser(workshopId: number, payload: {
    full_name: string;
    email: string;
    password: string;
    phone?: string;
    role: 'workshop' | 'technician';
  }): Observable<AdminWorkshopUser> {
    return this.http.post<AdminWorkshopUser>(`${this.apiUrl}/workshops/${workshopId}/users`, payload, { headers: this.getHeaders() });
  }

  updateUserStatus(userId: number, isActive: boolean): Observable<any> {
    return this.http.patch(`${this.apiUrl}/users/${userId}/status`, { is_active: isActive }, { headers: this.getHeaders() });
  }

  updateTechnician(technicianId: number, payload: Partial<Technician>): Observable<Technician> {
    return this.http.put<Technician>(`${this.apiUrl}/technicians/${technicianId}`, payload, { headers: this.getHeaders() });
  }

  setTechnicianStatus(technicianId: number, isActive: boolean): Observable<Technician> {
    return this.http.patch<Technician>(`${this.apiUrl}/technicians/${technicianId}/status`, { is_active: isActive }, { headers: this.getHeaders() });
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

  updateUser(userId: number, payload: Partial<User>): Observable<any> {
    return this.http.patch(
      `${this.apiUrl}/users/${userId}`,
      payload,
      { headers: this.getHeaders() }
    );
  }
}

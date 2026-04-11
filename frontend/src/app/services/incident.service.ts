import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Incident, IncidentHistory } from '../models/models';

@Injectable({
  providedIn: 'root'
})
export class IncidentService {
  private apiUrl = `${environment.apiUrl}/incidents`;

  constructor(private http: HttpClient) { }

  getIncidents(status?: string): Observable<Incident[]> {
    const url = status ? `${this.apiUrl}?status=${status}` : this.apiUrl;
    return this.http.get<Incident[]>(url);
  }

  getIncident(id: number): Observable<Incident> {
    return this.http.get<Incident>(`${this.apiUrl}/${id}`);
  }

  createIncident(data: any): Observable<Incident> {
    return this.http.post<Incident>(this.apiUrl, data);
  }

  updateIncident(id: number, data: any): Observable<Incident> {
    return this.http.patch<Incident>(`${this.apiUrl}/${id}`, data);
  }

  getIncidentHistory(id: number): Observable<IncidentHistory[]> {
    return this.http.get<IncidentHistory[]>(`${this.apiUrl}/${id}/history`);
  }

  cancelIncident(id: number): Observable<Incident> {
    return this.updateIncident(id, { status: 'cancelled' });
  }

  completeIncident(id: number): Observable<Incident> {
    return this.updateIncident(id, { status: 'completed' });
  }

  startIncident(id: number): Observable<Incident> {
    return this.updateIncident(id, { status: 'in_progress' });
  }
}

import { HttpBackend, HttpClient, HttpHeaders } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../environments/environment';
import { AuditLog } from '../models/models';

export interface AuditLogCreate {
  event_type: string;
  action: string;
  section?: string;
  endpoint?: string;
  http_method?: string;
  details?: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuditLogService {
  private httpNoInterceptors: HttpClient;
  private apiUrl = `${environment.apiUrl}/audit-logs`;

  constructor(private httpBackend: HttpBackend) {
    this.httpNoInterceptors = new HttpClient(httpBackend);
  }

  private getHeaders(): HttpHeaders | null {
    const token = localStorage.getItem('token');
    if (!token) {
      return null;
    }

    return new HttpHeaders({
      Authorization: `Bearer ${token}`
    });
  }

  listLogs(filters?: { event_type?: string; user_id?: number; section?: string }): Observable<AuditLog[]> {
    let url = this.apiUrl;

    if (filters) {
      const params = new URLSearchParams();
      if (filters.event_type) params.append('event_type', filters.event_type);
      if (filters.user_id) params.append('user_id', String(filters.user_id));
      if (filters.section) params.append('section', filters.section);
      const query = params.toString();
      if (query) {
        url = `${url}?${query}`;
      }
    }

    return this.httpNoInterceptors.get<AuditLog[]>(url, { headers: this.getHeaders() || undefined });
  }

  logEvent(event: AuditLogCreate): void {
    const headers = this.getHeaders();
    if (!headers) {
      return;
    }

    this.httpNoInterceptors.post<AuditLog>(this.apiUrl, event, { headers }).subscribe({
      error: () => {
        // Intencionalmente silencioso para no interrumpir UX.
      }
    });
  }
}

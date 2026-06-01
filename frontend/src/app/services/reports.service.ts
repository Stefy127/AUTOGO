import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import {
  OperationalReportRequest,
  OperationalReportResponse,
  VoiceReportParseRequest,
  VoiceReportParseResponse,
} from '../models/models';

@Injectable({
  providedIn: 'root'
})
export class ReportsService {
  private apiUrl = `${environment.apiUrl}/reports/operational`;

  constructor(private http: HttpClient) {}

  queryOperationalReport(payload: OperationalReportRequest): Observable<OperationalReportResponse> {
    return this.http.post<OperationalReportResponse>(`${this.apiUrl}/query`, payload);
  }

  exportOperationalReportPdf(payload: OperationalReportRequest): Observable<Blob> {
    return this.http.post(`${this.apiUrl}/export/pdf`, payload, {
      responseType: 'blob'
    });
  }

  exportOperationalReportExcel(payload: OperationalReportRequest): Observable<Blob> {
    return this.http.post(`${this.apiUrl}/export/excel`, payload, {
      responseType: 'blob'
    });
  }

  voiceParse(payload: VoiceReportParseRequest): Observable<VoiceReportParseResponse> {
    return this.http.post<VoiceReportParseResponse>(`${this.apiUrl}/voice-parse`, payload);
  }
}

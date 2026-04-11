import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { Payment } from '../models/models';

@Injectable({
  providedIn: 'root'
})
export class PaymentService {
  private apiUrl = 'http://localhost:8000/payments';

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

  createPayment(data: {
    incident_id: number;
    amount: number;
    payment_method: 'cash' | 'transfer';
    reference_number?: string;
    notes?: string;
  }): Observable<Payment> {
    return this.http.post<Payment>(
      this.apiUrl,
      data,
      { headers: this.getHeaders() }
    );
  }

  getPayment(id: number): Observable<Payment> {
    return this.http.get<Payment>(
      `${this.apiUrl}/${id}`,
      { headers: this.getHeaders() }
    );
  }

  getPaymentByIncident(incidentId: number): Observable<Payment> {
    return this.http.get<Payment>(
      `${this.apiUrl}/incident/${incidentId}`,
      { headers: this.getHeaders() }
    );
  }

  updatePayment(id: number, data: {
    is_paid?: boolean;
    paid_at?: string;
    reference_number?: string;
    notes?: string;
  }): Observable<Payment> {
    return this.http.patch<Payment>(
      `${this.apiUrl}/${id}`,
      data,
      { headers: this.getHeaders() }
    );
  }

  getPayments(): Observable<Payment[]> {
    return this.http.get<Payment[]>(
      this.apiUrl,
      { headers: this.getHeaders() }
    );
  }

  markAsPaid(id: number, reference?: string): Observable<Payment> {
    return this.updatePayment(id, {
      is_paid: true,
      paid_at: new Date().toISOString(),
      reference_number: reference
    });
  }
}

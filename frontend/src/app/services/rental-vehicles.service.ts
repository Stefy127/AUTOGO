import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { environment } from '../../environments/environment';

export interface RentalVehicle {
  id: number;
  company_name: string;
  vehicle_type: 'automovil' | 'camioneta';
  vehicle_name: string;
  characteristics: string;
  photo_url?: string;
  whatsapp_number: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface RentalVehicleCreate {
  company_name: string;
  vehicle_type: 'automovil' | 'camioneta';
  vehicle_name: string;
  characteristics: string;
  photo_url?: string;
  whatsapp_number: string;
}

export interface RentalVehicleUpdate {
  company_name?: string;
  vehicle_type?: 'automovil' | 'camioneta';
  vehicle_name?: string;
  characteristics?: string;
  photo_url?: string;
  whatsapp_number?: string;
  is_active?: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class RentalVehiclesService {
  private apiUrl = `${environment.apiUrl}/rental-vehicles`;

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

  // Get all rental vehicles
  getAllRentalVehicles(isActive?: boolean): Observable<RentalVehicle[]> {
    let url = this.apiUrl;
    if (isActive !== undefined) {
      url += `?is_active=${isActive}`;
    }
    return this.http.get<RentalVehicle[]>(url, { headers: this.getHeaders() });
  }

  // Get single rental vehicle by id
  getRentalVehicleById(id: number): Observable<RentalVehicle> {
    return this.http.get<RentalVehicle>(`${this.apiUrl}/${id}`, { headers: this.getHeaders() });
  }

  // Create rental vehicle
  createRentalVehicle(data: RentalVehicleCreate): Observable<RentalVehicle> {
    return this.http.post<RentalVehicle>(this.apiUrl, data, { headers: this.getHeaders() });
  }

  // Update rental vehicle
  updateRentalVehicle(id: number, data: RentalVehicleUpdate): Observable<RentalVehicle> {
    return this.http.patch<RentalVehicle>(`${this.apiUrl}/${id}`, data, { headers: this.getHeaders() });
  }

  // Delete rental vehicle
  deleteRentalVehicle(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`, { headers: this.getHeaders() });
  }
}

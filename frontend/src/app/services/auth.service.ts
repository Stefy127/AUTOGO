import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';
import { LoginRequest, LoginResponse, User } from '../models/models';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = environment.apiUrl;
  private currentUserSubject: BehaviorSubject<User | null>;
  public currentUser: Observable<User | null>;

  constructor(private http: HttpClient) {
    const storedUser = localStorage.getItem('currentUser');
    this.currentUserSubject = new BehaviorSubject<User | null>(
      storedUser ? JSON.parse(storedUser) : null
    );
    this.currentUser = this.currentUserSubject.asObservable();
  }

  public get currentUserValue(): User | null {
    return this.currentUserSubject.value;
  }

  login(credentials: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.apiUrl}/auth/login/json`, credentials)
      .pipe(
        tap(response => {
          localStorage.setItem('token', response.access_token);
          this.loadUserProfile();
        })
      );
  }

  loadUserProfile(): void {
    this.http.get<User>(`${this.apiUrl}/users/profile`).subscribe({
      next: (user) => {
        localStorage.setItem('currentUser', JSON.stringify(user));
        this.currentUserSubject.next(user);
      },
      error: (error) => {
        console.error('Error loading user profile:', error);
      }
    });
  }

  logout(): void {
    this.http.post(`${this.apiUrl}/auth/logout`, {}).subscribe({
      error: () => {
        // Intencionalmente silencioso.
      }
    });

    localStorage.removeItem('token');
    localStorage.removeItem('currentUser');
    this.currentUserSubject.next(null);
  }

  isLoggedIn(): boolean {
    return !!localStorage.getItem('token');
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  deleteMyAccount(): Observable<any> {
    return this.http.delete(`${this.apiUrl}/users/me`);
  }
}

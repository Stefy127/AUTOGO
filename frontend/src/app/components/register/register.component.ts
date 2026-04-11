import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';
import { AuthService } from '../../services/auth.service';
import { LocationData } from '../map-picker/map-picker.component';

@Component({
  selector: 'app-register',
  templateUrl: './register.component.html',
  styleUrls: ['./register.component.css']
})
export class RegisterComponent {
  registerForm: FormGroup;
  loading = false;
  error = '';

  constructor(
    private formBuilder: FormBuilder,
    private http: HttpClient,
    private authService: AuthService,
    private router: Router
  ) {
    this.registerForm = this.formBuilder.group({
      workshopName: ['', Validators.required],
      fullName: ['', Validators.required],
      email: ['', [Validators.required, Validators.email]],
      phone: ['', Validators.required],
      address: ['', Validators.required],
      latitude: [null],
      longitude: [null],
      password: ['', [Validators.required, Validators.minLength(6)]]
    });

    // Redirect if already logged in
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/workshop']);
    }
  }

  onLocationSelected(location: LocationData): void {
    this.registerForm.patchValue({
      address: location.address,
      latitude: location.latitude,
      longitude: location.longitude
    });
  }

  onSubmit(): void {
    if (this.registerForm.invalid) {
      return;
    }

    this.loading = true;
    this.error = '';

    // First, register the user as workshop
    const registerData = {
      email: this.registerForm.value.email,
      password: this.registerForm.value.password,
      full_name: this.registerForm.value.fullName,
      phone: this.registerForm.value.phone,
      role: 'workshop'
    };

    this.http.post(`${environment.apiUrl}/auth/register`, registerData).subscribe({
      next: () => {
        // Auto login after register
        this.authService.login({
          email: this.registerForm.value.email,
          password: this.registerForm.value.password
        }).subscribe({
          next: () => {
            // Create workshop profile
            const workshopData: any = {
              name: this.registerForm.value.workshopName,
              address: this.registerForm.value.address,
              phone: this.registerForm.value.phone
            };

            // Add GPS coordinates if provided
            if (this.registerForm.value.latitude !== null && this.registerForm.value.latitude !== '') {
              workshopData.latitude = parseFloat(this.registerForm.value.latitude);
            }
            if (this.registerForm.value.longitude !== null && this.registerForm.value.longitude !== '') {
              workshopData.longitude = parseFloat(this.registerForm.value.longitude);
            }
            
            this.http.post(`${environment.apiUrl}/workshops`, workshopData, {
              headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }
            }).subscribe({
              next: () => {
                // Workshop created successfully
                this.loading = false;
                this.router.navigate(['/workshop']);
              },
              error: (error) => {
                console.error('Error creating workshop:', error);
                this.error = error.error?.detail || 'Error al crear el perfil del taller. Por favor, completa tu información en el dashboard.';
                this.loading = false;
                // Wait 2 seconds before redirecting
                setTimeout(() => {
                  this.router.navigate(['/workshop']);
                }, 2000);
              }
            });
          },
          error: (error) => {
            this.error = 'Registro exitoso, pero error al iniciar sesión';
            this.loading = false;
          }
        });
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al registrar. El correo podría estar en uso.';
        this.loading = false;
      }
    });
  }
}

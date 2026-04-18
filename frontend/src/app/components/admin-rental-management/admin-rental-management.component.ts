import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { RentalVehiclesService, RentalVehicle, RentalVehicleCreate } from '../../services/rental-vehicles.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-admin-rental-management',
  templateUrl: './admin-rental-management.component.html',
  styleUrls: ['./admin-rental-management.component.css']
})
export class AdminRentalManagementComponent implements OnInit {
  vehicles: RentalVehicle[] = [];
  loading = false;
  error = '';
  successMessage = '';
  editingVehicleId: number | null = null;
  editForm: Partial<RentalVehicle> = {};
  showForm = false;
  newVehicleForm: RentalVehicleCreate = {
    company_name: '',
    vehicle_type: 'automovil',
    vehicle_name: '',
    characteristics: '',
    photo_url: '',
    whatsapp_number: ''
  };

  vehicleTypeOptions = [
    { value: 'automovil', label: 'Automóvil' },
    { value: 'camioneta', label: 'Camioneta' }
  ];

  constructor(
    private rentalVehiclesService: RentalVehiclesService,
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    if (this.authService.currentUserValue?.role !== 'admin') {
      this.router.navigate(['/dashboard']);
      return;
    }
    this.loadVehicles();
  }

  loadVehicles(): void {
    this.loading = true;
    this.rentalVehiclesService.getAllRentalVehicles().subscribe({
      next: (vehicles) => {
        this.vehicles = vehicles;
        this.loading = false;
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al cargar vehículos de alquiler';
        this.loading = false;
      }
    });
  }

  toggleForm(): void {
    this.showForm = !this.showForm;
    if (!this.showForm) {
      this.resetNewVehicleForm();
    }
  }

  resetNewVehicleForm(): void {
    this.newVehicleForm = {
      company_name: '',
      vehicle_type: 'automovil',
      vehicle_name: '',
      characteristics: '',
      photo_url: '',
      whatsapp_number: ''
    };
  }

  createVehicle(): void {
    if (!this.newVehicleForm.company_name || !this.newVehicleForm.vehicle_name ||
        !this.newVehicleForm.characteristics || !this.newVehicleForm.whatsapp_number) {
      this.error = 'Por favor completa todos los campos requeridos';
      return;
    }

    this.rentalVehiclesService.createRentalVehicle(this.newVehicleForm).subscribe({
      next: () => {
        this.successMessage = 'Vehículo de alquiler creado exitosamente';
        this.resetNewVehicleForm();
        this.showForm = false;
        this.loadVehicles();
        setTimeout(() => this.successMessage = '', 3000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al crear vehículo de alquiler';
      }
    });
  }

  startEdit(vehicle: RentalVehicle): void {
    this.editingVehicleId = vehicle.id;
    this.editForm = {
      company_name: vehicle.company_name,
      vehicle_type: vehicle.vehicle_type,
      vehicle_name: vehicle.vehicle_name,
      characteristics: vehicle.characteristics,
      photo_url: vehicle.photo_url,
      whatsapp_number: vehicle.whatsapp_number,
      is_active: vehicle.is_active
    };
  }

  cancelEdit(): void {
    this.editingVehicleId = null;
    this.editForm = {};
  }

  saveEdit(vehicleId: number): void {
    this.rentalVehiclesService.updateRentalVehicle(vehicleId, this.editForm).subscribe({
      next: () => {
        this.successMessage = 'Vehículo actualizado exitosamente';
        this.cancelEdit();
        this.loadVehicles();
        setTimeout(() => this.successMessage = '', 3000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al actualizar vehículo de alquiler';
      }
    });
  }

  deleteVehicle(vehicle: RentalVehicle): void {
    if (!confirm(`¿Eliminar el vehículo "${vehicle.vehicle_name}" de ${vehicle.company_name}?`)) {
      return;
    }

    this.rentalVehiclesService.deleteRentalVehicle(vehicle.id).subscribe({
      next: () => {
        this.successMessage = 'Vehículo eliminado exitosamente';
        this.loadVehicles();
        setTimeout(() => this.successMessage = '', 3000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al eliminar vehículo de alquiler';
      }
    });
  }

  toggleActive(vehicle: RentalVehicle): void {
    this.rentalVehiclesService.updateRentalVehicle(vehicle.id, {
      is_active: !vehicle.is_active
    }).subscribe({
      next: () => {
        this.loadVehicles();
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al actualizar estado del vehículo';
      }
    });
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}

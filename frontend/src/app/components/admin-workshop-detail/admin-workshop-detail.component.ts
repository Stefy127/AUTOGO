import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { forkJoin } from 'rxjs';
import { AdminService } from '../../services/admin.service';
import { AuthService } from '../../services/auth.service';
import {
  TenantTechnicianCreateRequest,
  TenantTechnicianUpdateRequest,
  TenantWorkshop,
  TenantWorkshopUserRow
} from '../../models/models';

@Component({
  selector: 'app-admin-workshop-detail',
  templateUrl: './admin-workshop-detail.component.html',
  styleUrls: ['./admin-workshop-detail.component.css']
})
export class AdminWorkshopDetailComponent implements OnInit {
  sidebarOpen = true;
  isLoading = false;
  isSubmitting = false;
  errorMessage = '';
  successMessage = '';

  workshopId!: number;
  workshop: TenantWorkshop | null = null;
  users: TenantWorkshopUserRow[] = [];

  isCreateModalOpen = false;
  isEditModalOpen = false;
  selectedTechnician: TenantWorkshopUserRow | null = null;

  createForm = this.buildEmptyCreateForm();
  editForm = {
    full_name: '',
    phone: '',
    is_active: true,
    is_available: true
  };

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private adminService: AdminService,
    private authService: AuthService
  ) {}

  ngOnInit(): void {
    this.sidebarOpen = typeof window !== 'undefined' ? window.innerWidth > 900 : true;

    if (this.authService.currentUserValue?.role !== 'admin') {
      this.router.navigate(['/dashboard']);
      return;
    }

    this.workshopId = Number(this.route.snapshot.paramMap.get('id'));
    if (!this.workshopId) {
      this.errorMessage = 'ID de taller invalido';
      return;
    }

    this.loadData();
  }

  loadData(): void {
    this.isLoading = true;
    this.errorMessage = '';

    forkJoin({
      workshop: this.adminService.getTenantWorkshopById(this.workshopId),
      users: this.adminService.getTenantWorkshopUsers(this.workshopId)
    }).subscribe({
      next: ({ workshop, users }) => {
        this.workshop = workshop;
        this.users = users || [];
        this.isLoading = false;
      },
      error: (error) => {
        this.errorMessage = error?.error?.detail || 'No se pudo cargar el detalle del taller';
        this.isLoading = false;
      }
    });
  }

  refreshAfterChange(message: string): void {
    this.successMessage = message;
    this.errorMessage = '';
    this.loadData();
  }

  openCreateTechnicianModal(): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.createForm = this.buildEmptyCreateForm();
    this.isCreateModalOpen = true;
  }

  createTechnician(): void {
    if (!this.validateCreateForm()) return;

    const isActive = this.createForm.is_active;
    const payload: TenantTechnicianCreateRequest = {
      full_name: this.createForm.full_name.trim(),
      email: this.createForm.email.trim().toLowerCase(),
      password: this.createForm.password,
      phone: this.createForm.phone?.trim() || null,
      is_active: isActive,
      is_available: isActive ? this.createForm.is_available : false
    };

    this.isSubmitting = true;
    this.adminService.createTenantTechnician(this.workshopId, payload).subscribe({
      next: () => {
        this.isSubmitting = false;
        this.isCreateModalOpen = false;
        this.refreshAfterChange('Tecnico creado correctamente');
      },
      error: (error) => {
        this.isSubmitting = false;
        this.errorMessage = error?.error?.detail || 'No se pudo crear el tecnico';
      }
    });
  }

  openEditTechnicianModal(row: TenantWorkshopUserRow): void {
    if (row.row_type !== 'technician' || !row.technician_id) {
      this.errorMessage = 'Solo se pueden editar filas de tecnico con technician_id';
      return;
    }

    this.errorMessage = '';
    this.successMessage = '';
    this.selectedTechnician = row;
    this.editForm = {
      full_name: row.full_name || '',
      phone: row.phone || '',
      is_active: row.is_active,
      is_available: row.is_available ?? false
    };
    this.isEditModalOpen = true;
  }

  saveTechnicianEdit(): void {
    if (!this.selectedTechnician?.technician_id) return;
    if (!this.validateEditForm()) return;

    const isActive = this.editForm.is_active;
    const payload: TenantTechnicianUpdateRequest = {
      full_name: this.editForm.full_name.trim(),
      phone: this.editForm.phone?.trim() || null,
      is_active: isActive,
      is_available: isActive ? this.editForm.is_available : false
    };

    this.isSubmitting = true;
    this.adminService.updateTenantTechnician(this.selectedTechnician.technician_id, payload).subscribe({
      next: () => {
        this.isSubmitting = false;
        this.isEditModalOpen = false;
        this.selectedTechnician = null;
        this.refreshAfterChange('Tecnico actualizado correctamente');
      },
      error: (error) => {
        this.isSubmitting = false;
        this.errorMessage = error?.error?.detail || 'No se pudo editar el tecnico';
      }
    });
  }

  toggleTechnicianStatus(row: TenantWorkshopUserRow): void {
    if (row.row_type !== 'technician' || !row.technician_id) {
      this.errorMessage = 'Solo se puede cambiar estado de tecnicos con technician_id';
      return;
    }

    const nextState = !row.is_active;
    const confirmed = nextState || confirm(`Desactivar el tecnico "${row.full_name || row.technician_id}"?`);
    if (!confirmed) return;

    this.errorMessage = '';
    this.adminService.setTenantTechnicianStatus(row.technician_id, nextState).subscribe({
      next: () => this.refreshAfterChange(nextState ? 'Tecnico activado correctamente' : 'Tecnico desactivado correctamente'),
      error: (error) => {
        this.errorMessage = error?.error?.detail || 'No se pudo actualizar el estado del tecnico';
      }
    });
  }

  onCreateActiveChange(): void {
    if (!this.createForm.is_active) {
      this.createForm.is_available = false;
    }
  }

  onEditActiveChange(): void {
    if (!this.editForm.is_active) {
      this.editForm.is_available = false;
    }
  }

  closeModals(): void {
    if (this.isSubmitting) return;
    this.isCreateModalOpen = false;
    this.isEditModalOpen = false;
    this.selectedTechnician = null;
  }

  get ownerRow(): TenantWorkshopUserRow | undefined {
    return this.users.find((row) => row.row_type === 'owner');
  }

  get technicianRows(): TenantWorkshopUserRow[] {
    return this.users.filter((row) => row.row_type === 'technician');
  }

  getRelationLabel(row: TenantWorkshopUserRow): string {
    if (row.row_type === 'owner') return 'Dueno del taller';
    if (row.row_type === 'technician') return 'Tecnico del taller';
    return row.relation;
  }

  backToList(): void {
    this.router.navigate(['/admin/gestion-talleres']);
  }

  toggleSidebar(): void {
    this.sidebarOpen = !this.sidebarOpen;
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  get currentUser() {
    return this.authService.currentUserValue;
  }

  private buildEmptyCreateForm() {
    return {
      full_name: '',
      email: '',
      password: '',
      phone: '',
      is_active: true,
      is_available: true
    };
  }

  private validateCreateForm(): boolean {
    if (!this.createForm.full_name.trim()) {
      this.errorMessage = 'El nombre completo del tecnico es obligatorio';
      return false;
    }
    if (!this.isValidEmail(this.createForm.email)) {
      this.errorMessage = 'Ingresa un correo valido para el tecnico';
      return false;
    }
    if (!this.createForm.password || this.createForm.password.length < 6) {
      this.errorMessage = 'La contrasena temporal debe tener al menos 6 caracteres';
      return false;
    }
    this.errorMessage = '';
    return true;
  }

  private validateEditForm(): boolean {
    if (!this.editForm.full_name.trim()) {
      this.errorMessage = 'El nombre completo del tecnico es obligatorio';
      return false;
    }
    this.errorMessage = '';
    return true;
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
  }
}

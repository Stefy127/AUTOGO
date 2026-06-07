import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AdminService } from '../../services/admin.service';
import { AuthService } from '../../services/auth.service';
import {
  TenantWorkshop,
  TenantWorkshopUpdateRequest,
  TenantWorkshopWithOwnerCreateRequest
} from '../../models/models';
import { LocationData } from '../map-picker/map-picker.component';

type TenantStatusFilter = 'all' | 'active' | 'inactive';

interface ServiceCategoryOption {
  value: string;
  label: string;
}

const SERVICE_CATEGORY_OPTIONS: ServiceCategoryOption[] = [
  { value: 'general_mechanics', label: 'Mecánica general' },
  { value: 'automotive_electricity', label: 'Electricidad automotriz' },
  { value: 'battery_start', label: 'Batería y arranque' },
  { value: 'tires', label: 'Llantería / Neumáticos' },
  { value: 'towing', label: 'Grúa / Remolque' },
  { value: 'locksmith', label: 'Cerrajería automotriz' },
  { value: 'fuel', label: 'Combustible' },
  { value: 'brakes', label: 'Frenos' },
  { value: 'engine', label: 'Motor' },
  { value: 'cooling', label: 'Refrigeración' },
  { value: 'transmission', label: 'Transmisión / Caja' },
  { value: 'suspension_steering', label: 'Suspensión y dirección' },
  { value: 'electronic_diagnosis', label: 'Diagnóstico electrónico' },
  { value: 'body_paint', label: 'Chaperío y pintura' },
  { value: 'roadside_assistance', label: 'Auxilio rápido en carretera' },
  { value: 'preventive_maintenance', label: 'Mantenimiento preventivo' },
  { value: 'air_conditioning', label: 'Aire acondicionado' },
  { value: 'spare_parts', label: 'Repuestos' },
];

@Component({
  selector: 'app-admin-workshop-management',
  templateUrl: './admin-workshop-management.component.html',
  styleUrls: ['./admin-workshop-management.component.css']
})
export class AdminWorkshopManagementComponent implements OnInit {
  workshops: TenantWorkshop[] = [];
  filteredWorkshops: TenantWorkshop[] = [];

  stats = {
    totalWorkshops: 0,
    activeWorkshops: 0,
    inactiveWorkshops: 0,
    technicians: 0
  };

  sidebarOpen = true;
  isLoading = false;
  isSubmitting = false;
  errorMessage = '';
  successMessage = '';

  search = '';
  statusFilter: TenantStatusFilter = 'all';

  isCreateModalOpen = false;
  isEditModalOpen = false;
  selectedWorkshop: TenantWorkshop | null = null;

  createForm = this.buildEmptyCreateForm();

  editForm = {
    name: '',
    address: '',
    latitude: null as number | null,
    longitude: null as number | null,
    categories: [] as string[],
    commission_percentage: 10,
    is_active: true
  };

  serviceCategories = SERVICE_CATEGORY_OPTIONS;

  constructor(
    private adminService: AdminService,
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.sidebarOpen = typeof window !== 'undefined' ? window.innerWidth > 900 : true;

    if (this.authService.currentUserValue?.role !== 'admin') {
      this.router.navigate(['/dashboard']);
      return;
    }

    this.loadData();
  }

  loadData(): void {
    this.isLoading = true;
    this.errorMessage = '';

    this.adminService.getTenantWorkshops().subscribe({
      next: (workshops) => {
        this.workshops = workshops || [];
        this.recalculateStats();
        this.applyFilters();
        this.isLoading = false;
      },
      error: (error) => {
        this.errorMessage = error?.error?.detail || 'No se pudo cargar la gestion de talleres';
        this.isLoading = false;
      }
    });
  }

  applyFilters(): void {
    const term = this.search.trim().toLowerCase();

    this.filteredWorkshops = this.workshops.filter((workshop) => {
      const searchable = [
        workshop.name,
        workshop.address,
        workshop.owner_name || '',
        workshop.owner_email || ''
      ].join(' ').toLowerCase();

      const matchesSearch = !term || searchable.includes(term);
      const matchesStatus =
        this.statusFilter === 'all' ||
        (this.statusFilter === 'active' && workshop.is_active) ||
        (this.statusFilter === 'inactive' && !workshop.is_active);

      return matchesSearch && matchesStatus;
    });
  }

  clearFilters(): void {
    this.search = '';
    this.statusFilter = 'all';
    this.applyFilters();
  }

  openCreateWorkshopModal(): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.createForm = this.buildEmptyCreateForm();
    this.isCreateModalOpen = true;
  }

  openEditWorkshopModal(workshop: TenantWorkshop): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.selectedWorkshop = workshop;
    this.editForm = {
      name: workshop.name,
      address: workshop.address,
      latitude: workshop.latitude,
      longitude: workshop.longitude,
      categories: workshop.categories || [],
      commission_percentage: workshop.commission_percentage,
      is_active: workshop.is_active
    };
    this.isEditModalOpen = true;
  }

  closeModals(): void {
    if (this.isSubmitting) return;
    this.isCreateModalOpen = false;
    this.isEditModalOpen = false;
    this.selectedWorkshop = null;
  }

  createWorkshop(): void {
    if (!this.validateCreateForm()) return;

    const payload: TenantWorkshopWithOwnerCreateRequest = {
      owner: {
        full_name: this.createForm.owner.full_name.trim(),
        email: this.createForm.owner.email.trim().toLowerCase(),
        phone: this.createForm.owner.phone?.trim() || null,
        password: this.createForm.owner.password
      },
      workshop: {
        name: this.createForm.workshop.name.trim(),
        address: this.createForm.workshop.address.trim(),
        latitude: this.createForm.workshop.latitude as number,
        longitude: this.createForm.workshop.longitude as number,
        categories: this.createForm.workshop.categories,
        commission_percentage: Number(this.createForm.workshop.commission_percentage),
        is_active: this.createForm.workshop.is_active
      }
    };

    this.isSubmitting = true;
    this.adminService.createTenantWorkshopWithOwner(payload).subscribe({
      next: () => {
        this.isSubmitting = false;
        this.isCreateModalOpen = false;
        this.successMessage = 'Taller y dueno workshop creados correctamente';
        this.loadData();
      },
      error: (error) => {
        this.isSubmitting = false;
        this.errorMessage = error?.error?.detail || 'No se pudo crear el taller con dueno';
      }
    });
  }

  saveWorkshopEdit(): void {
    if (!this.selectedWorkshop || !this.validateEditForm()) return;

    const payload: TenantWorkshopUpdateRequest = {
      name: this.editForm.name.trim(),
      address: this.editForm.address.trim(),
      latitude: this.editForm.latitude as number,
      longitude: this.editForm.longitude as number,
      categories: this.editForm.categories,
      commission_percentage: Number(this.editForm.commission_percentage),
      is_active: this.editForm.is_active
    };

    this.isSubmitting = true;
    this.adminService.updateTenantWorkshop(this.selectedWorkshop.id, payload).subscribe({
      next: () => {
        this.isSubmitting = false;
        this.isEditModalOpen = false;
        this.selectedWorkshop = null;
        this.successMessage = 'Taller actualizado correctamente';
        this.loadData();
      },
      error: (error) => {
        this.isSubmitting = false;
        this.errorMessage = error?.error?.detail || 'No se pudo actualizar el taller';
      }
    });
  }

  toggleWorkshopStatus(workshop: TenantWorkshop): void {
    const nextState = !workshop.is_active;
    const confirmed = nextState || confirm(`Desactivar el taller "${workshop.name}"?`);
    if (!confirmed) return;

    this.errorMessage = '';
    this.adminService.setTenantWorkshopStatus(workshop.id, nextState).subscribe({
      next: (updatedWorkshop) => {
        this.successMessage = nextState ? 'Taller activado correctamente' : 'Taller desactivado correctamente';
        this.workshops = this.workshops.map((item) => item.id === updatedWorkshop.id ? updatedWorkshop : item);
        this.recalculateStats();
        this.applyFilters();
      },
      error: (error) => {
        this.errorMessage = error?.error?.detail || 'No se pudo actualizar el estado del taller';
      }
    });
  }

  onCreateWorkshopLocationSelected(location: LocationData): void {
    this.createForm.workshop.address = location.address || this.createForm.workshop.address;
    this.createForm.workshop.latitude = location.latitude;
    this.createForm.workshop.longitude = location.longitude;
  }

  onEditWorkshopLocationSelected(location: LocationData): void {
    this.editForm.address = location.address || this.editForm.address;
    this.editForm.latitude = location.latitude;
    this.editForm.longitude = location.longitude;
  }

  toggleCreateCategory(categoryValue: string, checked: boolean): void {
    const current = new Set(this.createForm.workshop.categories);
    if (checked) {
      current.add(categoryValue);
    } else {
      current.delete(categoryValue);
    }
    this.createForm.workshop.categories = Array.from(current);
  }

  toggleEditCategory(categoryValue: string, checked: boolean): void {
    const current = new Set(this.editForm.categories);
    if (checked) {
      current.add(categoryValue);
    } else {
      current.delete(categoryValue);
    }
    this.editForm.categories = Array.from(current);
  }

  isCreateCategorySelected(categoryValue: string): boolean {
    return this.createForm.workshop.categories.includes(categoryValue);
  }

  isEditCategorySelected(categoryValue: string): boolean {
    return this.editForm.categories.includes(categoryValue);
  }

  getServiceCategoryLabel(categoryValue: string): string {
    return SERVICE_CATEGORY_OPTIONS.find(option => option.value === categoryValue)?.label || categoryValue;
  }

  goToDetail(workshopId: number): void {
    this.router.navigate(['/admin/gestion-talleres', workshopId]);
  }

  private buildEmptyCreateForm() {
    return {
      owner: {
        full_name: '',
        email: '',
        phone: '',
        password: ''
      },
      workshop: {
        name: '',
        address: '',
        latitude: null as number | null,
        longitude: null as number | null,
        categories: [] as string[],
        commission_percentage: 10,
        is_active: true
      }
    };
  }

  private validateCreateForm(): boolean {
    const owner = this.createForm.owner;
    const workshop = this.createForm.workshop;

    if (!owner.full_name.trim()) {
      this.errorMessage = 'El nombre del dueno es obligatorio';
      return false;
    }
    if (!this.isValidEmail(owner.email)) {
      this.errorMessage = 'Ingresa un correo valido para el dueno';
      return false;
    }
    if (!owner.password || owner.password.length < 6) {
      this.errorMessage = 'La contrasena temporal debe tener al menos 6 caracteres';
      return false;
    }

    return this.validateWorkshopPayload(
      workshop.name,
      workshop.address,
      workshop.latitude,
      workshop.longitude,
      workshop.commission_percentage
    );
  }

  private validateEditForm(): boolean {
    return this.validateWorkshopPayload(
      this.editForm.name,
      this.editForm.address,
      this.editForm.latitude,
      this.editForm.longitude,
      this.editForm.commission_percentage
    );
  }

  private validateWorkshopPayload(
    name: string,
    address: string,
    latitude: number | null,
    longitude: number | null,
    commission: number
  ): boolean {
    if (!name?.trim()) {
      this.errorMessage = 'El nombre del taller es obligatorio';
      return false;
    }
    if (!address?.trim()) {
      this.errorMessage = 'Selecciona una ubicacion en el mapa';
      return false;
    }
    if (latitude === null || Number.isNaN(Number(latitude))) {
      this.errorMessage = 'Selecciona una latitud valida en el mapa';
      return false;
    }
    if (longitude === null || Number.isNaN(Number(longitude))) {
      this.errorMessage = 'Selecciona una longitud valida en el mapa';
      return false;
    }
    if (commission === null || Number.isNaN(Number(commission)) || commission < 0 || commission > 100) {
      this.errorMessage = 'La comision debe estar entre 0 y 100';
      return false;
    }
    this.errorMessage = '';
    return true;
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
  }

  private recalculateStats(): void {
    this.stats = {
      totalWorkshops: this.workshops.length,
      activeWorkshops: this.workshops.filter((workshop) => workshop.is_active).length,
      inactiveWorkshops: this.workshops.filter((workshop) => !workshop.is_active).length,
      technicians: this.workshops.reduce((total, workshop) => total + (workshop.technician_count || 0), 0)
    };
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
}

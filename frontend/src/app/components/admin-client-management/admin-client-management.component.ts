import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AdminService } from '../../services/admin.service';
import { AuthService } from '../../services/auth.service';
import { User } from '../../models/models';

@Component({
  selector: 'app-admin-client-management',
  templateUrl: './admin-client-management.component.html',
  styleUrls: ['./admin-client-management.component.css']
})
export class AdminClientManagementComponent implements OnInit {
  users: User[] = [];
  loading = false;
  error = '';
  sidebarOpen = true;
  editingUserId: number | null = null;
  editForm: Partial<User> = {};

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
    this.loadUsers();
  }

  loadUsers(): void {
    this.loading = true;
    this.adminService.getAllUsers('client').subscribe({
      next: (users) => {
        this.users = users;
        this.loading = false;
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al cargar clientes';
        this.loading = false;
      }
    });
  }

  startEdit(user: User): void {
    this.editingUserId = user.id;
    this.editForm = {
      email: user.email,
      full_name: user.full_name,
      phone: user.phone,
      role: user.role
    };
  }

  cancelEdit(): void {
    this.editingUserId = null;
    this.editForm = {};
  }

  saveEdit(userId: number): void {
    this.adminService.updateUser(userId, this.editForm).subscribe({
      next: () => {
        this.cancelEdit();
        this.loadUsers();
      },
      error: (error) => {
        this.error = error.error?.detail || 'Error al actualizar usuario';
      }
    });
  }

  deleteUser(user: User): void {
    if (!confirm(`¿Eliminar el cliente ${user.full_name}?`)) {
      return;
    }

    this.adminService.deleteUser(user.id).subscribe({
      next: () => this.loadUsers(),
      error: (error) => {
        this.error = error.error?.detail || 'Error al eliminar usuario';
      }
    });
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  toggleSidebar(): void {
    this.sidebarOpen = !this.sidebarOpen;
  }

  get currentUser() {
    return this.authService.currentUserValue;
  }
}

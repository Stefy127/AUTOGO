import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { RegisterComponent } from './components/register/register.component';
import { DashboardComponent } from './components/dashboard/dashboard.component';
import { WorkshopDashboardComponent } from './components/workshop-dashboard/workshop-dashboard.component';
import { OperationalReportsComponent } from './components/operational-reports/operational-reports.component';
import { AdminWorkshopManagementComponent } from './components/admin-workshop-management/admin-workshop-management.component';
import { AdminClientManagementComponent } from './components/admin-client-management/admin-client-management.component';
import { AdminRentalManagementComponent } from './components/admin-rental-management/admin-rental-management.component';
import { AdminBitacoraComponent } from './components/admin-bitacora/admin-bitacora.component';
import { AuthGuard } from './guards/auth.guard';

const routes: Routes = [
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },
  { path: 'dashboard', component: DashboardComponent, canActivate: [AuthGuard] },
  { path: 'workshop', component: WorkshopDashboardComponent, canActivate: [AuthGuard] },
  { path: 'reports/operational', component: OperationalReportsComponent, canActivate: [AuthGuard] },
  { path: 'admin/gestion-talleres', component: AdminWorkshopManagementComponent, canActivate: [AuthGuard] },
  { path: 'admin/gestion-clientes', component: AdminClientManagementComponent, canActivate: [AuthGuard] },
  { path: 'admin/alquiler-autos', component: AdminRentalManagementComponent, canActivate: [AuthGuard] },
  { path: 'admin/bitacora', component: AdminBitacoraComponent, canActivate: [AuthGuard] },
  { path: '**', redirectTo: '/login' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }

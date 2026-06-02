import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { HttpClientModule, HTTP_INTERCEPTORS } from '@angular/common/http';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { GoogleMapsModule } from '@angular/google-maps';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { LoginComponent } from './components/login/login.component';
import { RegisterComponent } from './components/register/register.component';
import { DashboardComponent } from './components/dashboard/dashboard.component';
import { IncidentListComponent } from './components/incident-list/incident-list.component';
import { IncidentMapComponent } from './components/incident-map/incident-map.component';
import { WorkshopDashboardComponent } from './components/workshop-dashboard/workshop-dashboard.component';
import { MapPickerComponent } from './components/map-picker/map-picker.component';
import { AdminWorkshopManagementComponent } from './components/admin-workshop-management/admin-workshop-management.component';
import { AdminClientManagementComponent } from './components/admin-client-management/admin-client-management.component';
import { AdminRentalManagementComponent } from './components/admin-rental-management/admin-rental-management.component';
import { AdminBitacoraComponent } from './components/admin-bitacora/admin-bitacora.component';
import { OperationalReportsComponent } from './components/operational-reports/operational-reports.component';
import { AuthInterceptor } from './interceptors/auth.interceptor';
import { AuditInterceptor } from './interceptors/audit.interceptor';

@NgModule({
  declarations: [
    AppComponent,
    LoginComponent,
    RegisterComponent,
    DashboardComponent,
    IncidentListComponent,
    IncidentMapComponent,
    WorkshopDashboardComponent,
    MapPickerComponent,
    AdminWorkshopManagementComponent,
    AdminClientManagementComponent,
    AdminRentalManagementComponent,
    AdminBitacoraComponent,
    OperationalReportsComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    HttpClientModule,
    FormsModule,
    ReactiveFormsModule,
    GoogleMapsModule
  ],
  providers: [
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuthInterceptor,
      multi: true
    },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuditInterceptor,
      multi: true
    }
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }

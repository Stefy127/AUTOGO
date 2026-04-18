import { Component } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';
import { filter } from 'rxjs/operators';

import { AuditLogService } from './services/audit-log.service';
import { AuthService } from './services/auth.service';

@Component({
  selector: 'app-root',
  template: '<router-outlet></router-outlet>',
  styles: []
})
export class AppComponent {
  title = 'AutoGo - Panel de Talleres';

  private lastRoute = '';

  constructor(
    private router: Router,
    private authService: AuthService,
    private auditLogService: AuditLogService
  ) {
    this.router.events
      .pipe(filter((event) => event instanceof NavigationEnd))
      .subscribe((event) => {
        const nav = event as NavigationEnd;
        const url = nav.urlAfterRedirects;

        if (this.lastRoute === url) {
          return;
        }

        this.lastRoute = url;

        if (!this.authService.getToken()) {
          return;
        }

        this.auditLogService.logEvent({
          event_type: 'section_visit',
          action: 'Visitó sección',
          section: url,
          endpoint: url,
          http_method: 'NAV',
          details: 'Navegación registrada desde frontend'
        });
      });
  }
}

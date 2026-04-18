import { Injectable } from '@angular/core';
import {
  HttpEvent,
  HttpHandler,
  HttpInterceptor,
  HttpRequest,
  HttpResponse
} from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { environment } from '../../environments/environment';
import { AuditLogService } from '../services/audit-log.service';

@Injectable()
export class AuditInterceptor implements HttpInterceptor {
  constructor(private auditLogService: AuditLogService) {}

  intercept(request: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const isApiCall = request.url.startsWith(environment.apiUrl);
    const isMutatingMethod = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method);
    const isAuditEndpoint = request.url.includes('/audit-logs');
    const isAuthLogin = request.url.includes('/auth/login');
    const isAuthLogout = request.url.includes('/auth/logout');

    if (!isApiCall || !isMutatingMethod || isAuditEndpoint || isAuthLogin || isAuthLogout) {
      return next.handle(request);
    }

    return next.handle(request).pipe(
      tap((event) => {
        if (event instanceof HttpResponse && event.status >= 200 && event.status < 300) {
          const endpoint = request.url.replace(environment.apiUrl, '');
          this.auditLogService.logEvent({
            event_type: 'action',
            action: `Acción ${request.method} en ${endpoint}`,
            section: endpoint,
            endpoint,
            http_method: request.method,
            details: 'Acción registrada automáticamente desde frontend'
          });
        }
      })
    );
  }
}

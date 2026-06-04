import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { PaymentService } from '../../services/payment.service';

@Component({
  selector: 'app-payment-cancel',
  templateUrl: './payment-cancel.component.html',
  styleUrls: ['./payment-cancel.component.css']
})
export class PaymentCancelComponent implements OnInit {
  paymentId = 0;
  incidentId = 0;
  qrImageUrl = '';
  amountUsd = 0;
  amountBob = 0;
  paymentType = '';
  paymentStatus = '';

  referenceNumber = '';
  proofFile: File | null = null;
  proofPreviewUrl = '';
  proofImageUrl = '';
  loading = false;
  error = '';
  successMessage = '';

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private paymentService: PaymentService
  ) {}

  ngOnInit(): void {
    this.route.queryParamMap.subscribe(params => {
      this.paymentId = Number(params.get('payment_id') || 0);
      this.incidentId = Number(params.get('incident_id') || 0);
      this.qrImageUrl = params.get('qr_image_url') || '';
      this.amountUsd = Number(params.get('amount_usd') || 0);
      this.amountBob = Number(params.get('amount_bob') || 0);
      this.paymentType = params.get('payment_type') || '';
      this.paymentStatus = params.get('payment_status') || '';
    });
  }

  onProofSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files && input.files.length > 0 ? input.files[0] : null;

    if (!file) {
      return;
    }

    if (!file.type.startsWith('image/')) {
      this.error = 'Solo se permiten imágenes para el comprobante';
      return;
    }

    if (this.proofPreviewUrl) {
      URL.revokeObjectURL(this.proofPreviewUrl);
    }

    this.proofFile = file;
    this.proofPreviewUrl = URL.createObjectURL(file);
    this.proofImageUrl = '';
    this.error = '';
  }

  private readProofAsDataUrl(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result?.toString() || '');
      reader.onerror = () => reject(new Error('No se pudo leer el comprobante'));
      reader.readAsDataURL(file);
    });
  }

  async confirmPayment(): Promise<void> {
    if (!this.paymentId) {
      this.error = 'No se encontró el pago de cancelación';
      return;
    }

    if (!this.referenceNumber.trim()) {
      this.error = 'Ingresa la referencia del pago';
      return;
    }

    this.loading = true;
    this.error = '';

    if (this.proofFile) {
      try {
        this.proofImageUrl = await this.readProofAsDataUrl(this.proofFile);
      } catch {
        this.loading = false;
        this.error = 'No se pudo adjuntar el comprobante';
        return;
      }
    }

    this.paymentService.confirmCancellationQrPayment(
      this.paymentId,
      this.referenceNumber.trim(),
      this.proofImageUrl || undefined
    ).subscribe({
      next: (response) => {
        this.successMessage = response.message;
        this.loading = false;
        setTimeout(() => this.router.navigate(['/dashboard']), 2000);
      },
      error: (error) => {
        this.error = error.error?.detail || 'No se pudo confirmar el pago';
        this.loading = false;
      }
    });
  }

  clearProof(): void {
    if (this.proofPreviewUrl) {
      URL.revokeObjectURL(this.proofPreviewUrl);
    }
    this.proofFile = null;
    this.proofPreviewUrl = '';
    this.proofImageUrl = '';
  }

  backToLogin(): void {
    this.router.navigate(['/login']);
  }
}

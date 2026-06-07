class ServiceCategoryOption {
  final String value;
  final String label;

  const ServiceCategoryOption(this.value, this.label);
}

const List<ServiceCategoryOption> serviceCategoryOptions = [
  ServiceCategoryOption('general_mechanics', 'Mecánica general'),
  ServiceCategoryOption('automotive_electricity', 'Electricidad automotriz'),
  ServiceCategoryOption('battery_start', 'Batería y arranque'),
  ServiceCategoryOption('tires', 'Llantería / Neumáticos'),
  ServiceCategoryOption('towing', 'Grúa / Remolque'),
  ServiceCategoryOption('locksmith', 'Cerrajería automotriz'),
  ServiceCategoryOption('fuel', 'Combustible'),
  ServiceCategoryOption('brakes', 'Frenos'),
  ServiceCategoryOption('engine', 'Motor'),
  ServiceCategoryOption('cooling', 'Refrigeración'),
  ServiceCategoryOption('transmission', 'Transmisión / Caja'),
  ServiceCategoryOption('suspension_steering', 'Suspensión y dirección'),
  ServiceCategoryOption('electronic_diagnosis', 'Diagnóstico electrónico'),
  ServiceCategoryOption('body_paint', 'Chaperío y pintura'),
  ServiceCategoryOption('roadside_assistance', 'Auxilio rápido en carretera'),
  ServiceCategoryOption('preventive_maintenance', 'Mantenimiento preventivo'),
  ServiceCategoryOption('air_conditioning', 'Aire acondicionado'),
  ServiceCategoryOption('spare_parts', 'Repuestos'),
];

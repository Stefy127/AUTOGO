from __future__ import annotations

from collections.abc import Iterable

SERVICE_CATEGORIES = [
    {"value": "general_mechanics", "label": "Mecánica general"},
    {"value": "automotive_electricity", "label": "Electricidad automotriz"},
    {"value": "battery_start", "label": "Batería y arranque"},
    {"value": "tires", "label": "Llantería / Neumáticos"},
    {"value": "towing", "label": "Grúa / Remolque"},
    {"value": "locksmith", "label": "Cerrajería automotriz"},
    {"value": "fuel", "label": "Combustible"},
    {"value": "brakes", "label": "Frenos"},
    {"value": "engine", "label": "Motor"},
    {"value": "cooling", "label": "Refrigeración"},
    {"value": "transmission", "label": "Transmisión / Caja"},
    {"value": "suspension_steering", "label": "Suspensión y dirección"},
    {"value": "electronic_diagnosis", "label": "Diagnóstico electrónico"},
    {"value": "body_paint", "label": "Chaperío y pintura"},
    {"value": "roadside_assistance", "label": "Auxilio rápido en carretera"},
    {"value": "preventive_maintenance", "label": "Mantenimiento preventivo"},
    {"value": "air_conditioning", "label": "Aire acondicionado"},
    {"value": "spare_parts", "label": "Repuestos"},
]

SERVICE_CATEGORY_VALUES = {item["value"] for item in SERVICE_CATEGORIES}
SERVICE_CATEGORY_LABELS = {item["value"]: item["label"] for item in SERVICE_CATEGORIES}


def normalize_service_categories(values, *, required: bool = False) -> list[str]:
    if values is None:
        normalized: list[str] = []
    elif isinstance(values, (str, bytes)):
        raise ValueError("categories debe ser una lista de categorías")
    else:
        normalized = []
        if not isinstance(values, Iterable):
            raise ValueError("categories debe ser una lista de categorías")

        for raw_value in values:
            if raw_value is None:
                continue

            category = str(raw_value).strip().lower()
            if not category:
                continue
            if category not in SERVICE_CATEGORY_VALUES:
                allowed = ", ".join(sorted(SERVICE_CATEGORY_VALUES))
                raise ValueError(f"Categoría inválida: {category}. Valores permitidos: {allowed}")
            if category not in normalized:
                normalized.append(category)

    if required and not normalized:
        raise ValueError("Debes seleccionar al menos una categoría")

    return normalized


def categories_overlap(left: Iterable[str] | None, right: Iterable[str] | None) -> bool:
    if not left or not right:
        return False
    return bool(set(left).intersection(right))
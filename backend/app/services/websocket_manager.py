from __future__ import annotations

from collections import defaultdict
from typing import DefaultDict, Set

from fastapi import WebSocket


class WebSocketManager:
    def __init__(self) -> None:
        self._incident_connections: DefaultDict[int, Set[WebSocket]] = defaultdict(set)

    async def connect(self, incident_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._incident_connections[incident_id].add(websocket)

    def disconnect(self, incident_id: int, websocket: WebSocket) -> None:
        connections = self._incident_connections.get(incident_id)
        if not connections:
            return
        connections.discard(websocket)
        if not connections:
            self._incident_connections.pop(incident_id, None)

    async def broadcast_to_incident(self, incident_id: int, payload: dict) -> None:
        connections = list(self._incident_connections.get(incident_id, set()))
        for websocket in connections:
            try:
                await websocket.send_json(payload)
            except Exception:
                self.disconnect(incident_id, websocket)


websocket_manager = WebSocketManager()
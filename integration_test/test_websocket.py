#!/usr/bin/env python3
"""
WebSocket integration tests for AudioControl system.

These tests verify that the WebSocket event endpoints accept connections,
send a welcome message, and forward player events to subscribed clients.
"""

import json
import time
import threading
import websocket
import pytest


class WebSocketListener:
    """Helper that connects to the AudioControl WebSocket and collects messages."""

    def __init__(self, url: str):
        self.url = url
        self.messages = []
        self.errors = []
        self.ws = None
        self.thread = None
        self.connected = threading.Event()

    def on_message(self, _ws, message):
        try:
            self.messages.append(json.loads(message))
        except json.JSONDecodeError:
            self.messages.append(message)

    def on_error(self, _ws, error):
        self.errors.append(str(error))

    def on_close(self, _ws, _code, _reason):
        pass

    def on_open(self, ws):
        self.connected.set()
        # Subscribe to all events for all players
        ws.send(json.dumps({"players": None, "event_types": None}))

    def connect(self):
        self.ws = websocket.WebSocketApp(
            self.url,
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close,
        )
        self.thread = threading.Thread(target=self.ws.run_forever)
        self.thread.daemon = True
        self.thread.start()
        assert self.connected.wait(5.0), "WebSocket did not connect within timeout"

    def close(self):
        if self.ws:
            self.ws.close()
        if self.thread:
            self.thread.join(timeout=2.0)

    def wait_for(self, predicate, timeout=5.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            for msg in self.messages:
                if predicate(msg):
                    return msg
            time.sleep(0.05)
        return None


def test_websocket_connection_and_welcome(websocket_server):
    """The WebSocket endpoint should accept a connection and send a welcome."""
    url = f"ws://localhost:{websocket_server.port}/api/events/ws"
    listener = WebSocketListener(url)
    try:
        listener.connect()
        welcome = listener.wait_for(lambda m: m.get("type") == "welcome")
        assert welcome is not None, f"No welcome message received: {listener.messages}"
        assert "message" in welcome
    finally:
        listener.close()


def test_websocket_state_changed_event(websocket_server):
    """A player state change should be delivered to the WebSocket."""
    url = f"ws://localhost:{websocket_server.port}/api/events/ws"
    listener = WebSocketListener(url)
    try:
        listener.connect()
        # Wait for the subscription to be acknowledged
        assert listener.wait_for(lambda m: m.get("type") == "subscription_updated")

        websocket_server.reset_player_state("test_player")
        event = {"type": "state_changed", "state": "playing"}
        response = websocket_server.send_generic_player_event("test_player", event)
        assert response.get("success"), response.get("message")

        state_event = listener.wait_for(
            lambda m: m.get("type") == "state_changed"
            and m.get("player_name") == "test_player"
        )
        assert state_event is not None, f"No state_changed event received: {listener.messages}"
        assert state_event.get("state") == "playing"
    finally:
        listener.close()


def test_websocket_song_changed_event(websocket_server):
    """A song change should be delivered to the WebSocket."""
    url = f"ws://localhost:{websocket_server.port}/api/events/ws"
    listener = WebSocketListener(url)
    try:
        listener.connect()
        assert listener.wait_for(lambda m: m.get("type") == "subscription_updated")

        websocket_server.reset_player_state("test_player")
        event = {
            "type": "song_changed",
            "song": {
                "title": "WebSocket Test Song",
                "artist": "WebSocket Test Artist",
                "album": "WebSocket Test Album",
                "duration": 200.0,
            },
        }
        response = websocket_server.send_generic_player_event("test_player", event)
        assert response.get("success"), response.get("message")

        song_event = listener.wait_for(
            lambda m: m.get("type") == "song_changed"
            and m.get("player_name") == "test_player"
        )
        assert song_event is not None, f"No song_changed event received: {listener.messages}"
        assert song_event["song"]["title"] == "WebSocket Test Song"
        assert song_event["song"]["artist"] == "WebSocket Test Artist"
    finally:
        listener.close()

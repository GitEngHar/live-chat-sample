import { createCable, Channel } from "@anycable/web";
import type { Message } from "./types";

const CABLE_URL = import.meta.env.VITE_CABLE_URL ?? "ws://localhost:8080/cable";

type ChatChannelParams = { room_id: number };

export class ChatChannel extends Channel<ChatChannelParams, Message> {
  static readonly identifier = "ChatChannel";
}

// Lazily create the cable connection on first use (after login), not at module load.
// This module is statically imported from the very top of the app (main -> App ->
// MainScreen -> ChatScreen -> cable), so a module-level `createCable()` call would
// connect immediately on page load — before the user has authenticated and the
// (subdomain-shared) auth cookie exists. That premature connection gets rejected
// ("unauthorized", reconnect: false) and never retries, so every subscribeToRoom()
// call afterward silently rides a dead connection until the page is reloaded.
let cable: ReturnType<typeof createCable> | null = null;

function getCable() {
  if (!cable) {
    cable = createCable(CABLE_URL, { protocol: "actioncable-v1-ext-json" });
  }
  return cable;
}

export function subscribeToRoom(roomId: number, onMessage: (message: Message) => void): ChatChannel {
  const channel = getCable().subscribeTo(ChatChannel, { room_id: roomId });
  channel.on("message", onMessage);
  return channel;
}

export function unsubscribeFromChannel(channel: ChatChannel | null | undefined): void {
  channel?.disconnect();
}

export function disconnectCable(): void {
  cable?.disconnect();
  cable = null;
}

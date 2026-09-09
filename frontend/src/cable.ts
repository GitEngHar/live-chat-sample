import { createConsumer } from "@rails/actioncable";
import type { Consumer, Subscription } from "@rails/actioncable";

const CABLE_URL = import.meta.env.VITE_CABLE_URL ?? "ws://localhost:8080/cable";

let consumer: Consumer | null = null;

function getConsumer(): Consumer {
  if (!consumer) {
    consumer = createConsumer(CABLE_URL);
  }
  return consumer;
}

export function connectCable(): void {
  getConsumer().connect();
}

export function subscribeToChannel<T>(
  channel: string,
  params: Record<string, unknown>,
  onReceived: (data: T) => void,
): Subscription {
  return getConsumer().subscriptions.create({ channel, ...params }, { received: onReceived });
}

export function unsubscribeFromChannel(subscription: Subscription | null | undefined): void {
  subscription?.unsubscribe();
}

export function disconnectCable(): void {
  consumer?.disconnect();
  consumer = null;
}

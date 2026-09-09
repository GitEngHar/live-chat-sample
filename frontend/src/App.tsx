import { useState } from "react";
import { AuthScreen } from "./AuthScreen";
import { Main } from "./MainScreen";
import type { User } from "./types";

const STORAGE_KEY = "live-chat-sample:user";

function loadStoredUser(): User | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as User) : null;
  } catch {
    return null;
  }
}

function App() {
  const [user, setUser] = useState<User | null>(loadStoredUser);

  function handleAuthenticated(nextUser: User) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(nextUser));
    setUser(nextUser);
  }

  function handleLogout() {
    localStorage.removeItem(STORAGE_KEY);
    setUser(null);
  }

  return user ? <Main user={user} onLogout={handleLogout} /> : <AuthScreen onAuthenticated={handleAuthenticated} />;
}

export default App;

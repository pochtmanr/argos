// /Users/roman/Developer/iosbrowser/apps/desktop/src/renderer/App.tsx
import { useEffect, useState } from "react";
import type { BrowserProfile } from "@browser/api-contracts";
import { ProfileSidebar } from "./components/ProfileSidebar";
import { demoProfile } from "./state/fixtures";
import "./styles/app.css";

export default function App() {
  const [profiles] = useState<BrowserProfile[]>([demoProfile]);
  const [activeProfile, setActiveProfile] = useState<BrowserProfile>(demoProfile);
  const [assistantOpen, setAssistantOpen] = useState(true);
  const [status, setStatus] = useState("Initializing profile session");

  useEffect(() => {
    let cancelled = false;
    async function activate() {
      const container = await window.browserPlatform.activateProfile(activeProfile);
      if (!cancelled) {
        setStatus(`Active partition: ${container.storagePartition}`);
        await window.browserPlatform.createTab({
          tabId: "initial-tab",
          partition: container.storagePartition,
          url: "https://example.com"
        });
      }
    }
    activate().catch((error) => setStatus(error instanceof Error ? error.message : "Profile activation failed"));
    return () => {
      cancelled = true;
    };
  }, [activeProfile]);

  return (
    <main className="appShell">
      <ProfileSidebar
        profiles={profiles}
        activeProfileId={activeProfile.id}
        onSelect={setActiveProfile}
        onAskAi={() => setAssistantOpen((value) => !value)}
      />
      <section className="browserSurface" aria-label="Browser surface">
        <div className="topBar">{status}</div>
      </section>
      {assistantOpen ? (
        <aside className="assistant" aria-label="AI assistant">
          <h1>Assistant</h1>
          <p>Profile-aware page summaries and approved browser actions will appear here.</p>
        </aside>
      ) : null}
    </main>
  );
}

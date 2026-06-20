// /Users/roman/Developer/iosbrowser/apps/desktop/src/renderer/components/ProfileSidebar.tsx
import type { BrowserProfile } from "@browser/api-contracts";

type Props = {
  profiles: BrowserProfile[];
  activeProfileId: string;
  onSelect(profile: BrowserProfile): void;
  onAskAi(): void;
};

export function ProfileSidebar({ profiles, activeProfileId, onSelect, onAskAi }: Props) {
  return (
    <aside className="sidebar" aria-label="Browser profiles">
      <div className="brand">AI Browser</div>
      <nav className="profiles">
        {profiles.map((profile) => (
          <button
            key={profile.id}
            className={profile.id === activeProfileId ? "profile active" : "profile"}
            onClick={() => onSelect(profile)}
            style={{ borderLeftColor: profile.color }}
          >
            {profile.displayName}
          </button>
        ))}
      </nav>
      <button className="aiButton" onClick={onAskAi}>AI Sidebar</button>
    </aside>
  );
}

import {
  PanelSection,
  PanelSectionRow,
  ButtonItem,
  DropdownItem,
  Field,
} from "@decky/ui";
import { callable, definePlugin } from "@decky/api";
import { useEffect, useState } from "react";
import { FaHdd } from "react-icons/fa";

interface Status {
  os?: string;
  installed?: boolean;
  resolution?: string;
  theme?: string;
  timeout?: string;
  default_os?: string;
  service?: string;
  windows_active?: boolean;
  error?: string;
}

const getStatus = callable<[], Status>("get_status");
const listThemes = callable<[], string[]>("list_themes");
const setDefaultOs = callable<[string], { ok: boolean; message: string }>("set_default_os");
const setResolution = callable<[string], { ok: boolean; message: string }>("set_resolution");
const setTheme = callable<[string], { ok: boolean; message: string }>("set_theme");
const setTimeoutSecs = callable<[number], { ok: boolean; message: string }>("set_timeout");
const setService = callable<[string], { ok: boolean; message: string }>("set_service");

function Content() {
  const [status, setStatus] = useState<Status | null>(null);
  const [themes, setThemes] = useState<string[]>([]);

  const refresh = async () => {
    setStatus(await getStatus());
    setThemes(await listThemes());
  };

  useEffect(() => {
    refresh();
  }, []);

  const osOptions = [
    { data: "windows", label: "Windows" },
    { data: "steamos", label: "SteamOS" },
    { data: "bazzite", label: "Bazzite" },
    { data: "lastos", label: "Last used" },
  ];
  const resOptions = ["auto", "1280x800", "1920x1080", "1920x1200", "2560x1600"].map((r) => ({
    data: r,
    label: r === "auto" ? "Auto-detect" : r,
  }));
  const timeoutOptions = [1, 5, 10, 15, 60].map((t) => ({ data: t, label: `${t}s` }));

  return (
    <>
      <PanelSection title="Status">
        <PanelSectionRow>
          <Field label="Default boot">{status?.default_os ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label="Resolution">{status?.resolution ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label="Theme">{status?.theme ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label="Service">{status?.service ?? "..."}</Field>
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title="Default boot OS">
        <PanelSectionRow>
          <DropdownItem
            rgOptions={osOptions}
            selectedOption={status?.default_os}
            onChange={async (o) => {
              await setDefaultOs(o.data);
              refresh();
            }}
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title="Display">
        <PanelSectionRow>
          <DropdownItem
            rgOptions={resOptions}
            selectedOption={status?.resolution}
            onChange={async (o) => {
              await setResolution(o.data);
              refresh();
            }}
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title="Theme">
        <PanelSectionRow>
          <DropdownItem
            rgOptions={themes.map((t) => ({ data: t, label: t }))}
            selectedOption={status?.theme}
            onChange={async (o) => {
              await setTheme(o.data);
              refresh();
            }}
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title="Boot menu timeout">
        <PanelSectionRow>
          <DropdownItem
            rgOptions={timeoutOptions}
            selectedOption={status?.timeout ? parseInt(status.timeout, 10) : undefined}
            onChange={async (o) => {
              await setTimeoutSecs(o.data);
              refresh();
            }}
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title="Boot control">
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={async () => {
              await setService("disable");
              refresh();
            }}
          >
            Boot to Windows next
          </ButtonItem>
        </PanelSectionRow>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={async () => {
              await setService("enable");
              refresh();
            }}
          >
            Re-enable Clover
          </ButtonItem>
        </PanelSectionRow>
      </PanelSection>
    </>
  );
}

export default definePlugin(() => ({
  name: "Clover Dual Boot",
  titleView: <div>Clover Dual Boot</div>,
  content: <Content />,
  icon: <FaHdd />,
}));

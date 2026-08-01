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
const getLang = callable<[], string>("get_lang");
const setLang = callable<[string], { ok: boolean }>("set_lang");

const STRINGS: Record<string, Record<string, string>> = {
  es: {
    language: "Idioma",
    status: "Estado",
    default_boot: "Arranque por defecto",
    resolution: "Resolución",
    theme: "Tema",
    service: "Servicio",
    default_boot_os: "SO de arranque por defecto",
    display: "Pantalla",
    boot_timeout: "Tiempo del menú de arranque",
    boot_control: "Control de arranque",
    boot_windows: "Arrancar en Windows la próxima vez",
    reenable: "Reactivar Clover",
    lastused: "Última usada",
    autodetect: "Detección automática",
  },
  en: {
    language: "Language",
    status: "Status",
    default_boot: "Default boot",
    resolution: "Resolution",
    theme: "Theme",
    service: "Service",
    default_boot_os: "Default boot OS",
    display: "Display",
    boot_timeout: "Boot menu timeout",
    boot_control: "Boot control",
    boot_windows: "Boot to Windows next",
    reenable: "Re-enable Clover",
    lastused: "Last used",
    autodetect: "Auto-detect",
  },
};

function Content() {
  const [status, setStatus] = useState<Status | null>(null);
  const [themes, setThemes] = useState<string[]>([]);
  const [lang, setLangState] = useState<string>("es");

  const t = (key: string) => (STRINGS[lang] ?? STRINGS.en)[key] ?? STRINGS.en[key] ?? key;

  const refresh = async () => {
    setStatus(await getStatus());
  };

  useEffect(() => {
    refresh();
    listThemes().then(setThemes);
    getLang().then(setLangState);
  }, []);

  const langOptions = [
    { data: "es", label: "Español" },
    { data: "en", label: "English" },
  ];
  const osOptions = [
    { data: "windows", label: "Windows" },
    { data: "steamos", label: "SteamOS" },
    { data: "bazzite", label: "Bazzite" },
    { data: "lastos", label: t("lastused") },
  ];
  const resOptions = ["auto", "1280x800", "1920x1080", "1920x1200", "2560x1600"].map((r) => ({
    data: r,
    label: r === "auto" ? t("autodetect") : r,
  }));
  const timeoutOptions = [1, 5, 10, 15, 60].map((s) => ({ data: s, label: `${s}s` }));

  return (
    <>
      <PanelSection title={t("language")}>
        <PanelSectionRow>
          <DropdownItem
            rgOptions={langOptions}
            selectedOption={lang}
            onChange={async (o) => {
              await setLang(o.data);
              setLangState(o.data);
            }}
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title={t("status")}>
        <PanelSectionRow>
          <Field label={t("default_boot")}>{status?.default_os ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label={t("resolution")}>{status?.resolution ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label={t("theme")}>{status?.theme ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label={t("service")}>{status?.service ?? "..."}</Field>
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title={t("default_boot_os")}>
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

      <PanelSection title={t("display")}>
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

      <PanelSection title={t("theme")}>
        <PanelSectionRow>
          <DropdownItem
            rgOptions={themes.map((th) => ({ data: th, label: th }))}
            selectedOption={status?.theme}
            onChange={async (o) => {
              await setTheme(o.data);
              refresh();
            }}
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title={t("boot_timeout")}>
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

      <PanelSection title={t("boot_control")}>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={async () => {
              await setService("disable");
              refresh();
            }}
          >
            {t("boot_windows")}
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
            {t("reenable")}
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

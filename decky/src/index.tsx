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
  loader_kind?: string;
  clover_status?: string;
  clover_first?: boolean;
  repair_needed?: boolean;
  layout_safe?: boolean;
  layout_requires_confirmation?: boolean;
  layout_problems?: string[];
  available_os?: Array<{
    id: string;
    label: string;
    loader?: string;
    validated?: boolean;
  }>;
  error?: string;
}

const getStatus = callable<[], Status>("get_status");
const getMaintenanceLog = callable<[], { ok: boolean; message: string }>("get_maintenance_log");
const listThemes = callable<[], string[]>("list_themes");
const setDefaultOs = callable<[string], { ok: boolean; message: string }>("set_default_os");
const setDefaultLoader = callable<[string], { ok: boolean; message: string }>("set_default_loader");
const repairBootPriority = callable<[boolean], { ok: boolean; message: string }>("repair_boot_priority");
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
    loader: "Cargador Linux",
    clover_state: "Estado de Clover",
    clover_first: "Clover primero",
    repair: "Reparar prioridad de arranque",
    problems: "Problemas detectados",
    result: "Resultado",
    latest_log: "Último registro",
    view_log: "Ver último registro",
    unvalidated: "no validado",
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
    loader: "Linux loader",
    clover_state: "Clover state",
    clover_first: "Clover first",
    repair: "Repair boot priority",
    problems: "Detected problems",
    result: "Result",
    latest_log: "Latest log",
    view_log: "View latest log",
    unvalidated: "unvalidated",
    lastused: "Last used",
    autodetect: "Auto-detect",
  },
};

function Content() {
  const [status, setStatus] = useState<Status | null>(null);
  const [themes, setThemes] = useState<string[]>([]);
  const [lang, setLangState] = useState<string>("es");
  const [actionMessage, setActionMessage] = useState<string>("");
  const [maintenanceLog, setMaintenanceLog] = useState<string>("");

  const t = (key: string) => (STRINGS[lang] ?? STRINGS.en)[key] ?? STRINGS.en[key] ?? key;

  const refresh = async () => {
    setStatus(await getStatus());
  };

  const applyAction = async (action: Promise<{ ok: boolean; message: string }>) => {
    const result = await action;
    setActionMessage(`${result.ok ? "✓" : "⚠"} ${result.message}`);
    await refresh();
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
  const availableOs = status?.available_os ?? [
    { id: "windows", label: "Windows" },
    { id: "steamos", label: "SteamOS" },
    { id: "bazzite", label: "Bazzite" },
    { id: "lastos", label: t("lastused") },
  ];
  const osOptions = availableOs.map((entry) => ({
    data: entry.id,
    label:
      entry.id === "lastos"
        ? t("lastused")
        : `${entry.label}${entry.validated === false ? ` (${t("unvalidated")})` : ""}`,
  }));
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
              const result = await setLang(o.data);
              if (result.ok) setLangState(o.data);
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
        <PanelSectionRow>
          <Field label={t("loader")}>{status?.loader_kind ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label={t("clover_state")}>{status?.clover_status ?? "..."}</Field>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field label={t("clover_first")}>{status?.clover_first === true ? "✓" : "—"}</Field>
        </PanelSectionRow>
        {(status?.layout_problems?.length ?? 0) > 0 && (
          <PanelSectionRow>
            <Field label={t("problems")}>{status?.layout_problems?.join(", ")}</Field>
          </PanelSectionRow>
        )}
        {(status?.error || actionMessage) && (
          <PanelSectionRow>
            <Field label={t("result")}>{status?.error || actionMessage}</Field>
          </PanelSectionRow>
        )}
      </PanelSection>

      <PanelSection title={t("default_boot_os")}>
        <PanelSectionRow>
          <DropdownItem
            rgOptions={osOptions}
            selectedOption={status?.default_os}
            onChange={async (o) => {
              const selected = availableOs.find((entry) => entry.id === o.data);
              if (selected?.loader) {
                await applyAction(setDefaultLoader(selected.loader));
              } else {
                await applyAction(setDefaultOs(o.data));
              }
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
              await applyAction(setResolution(o.data));
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
              await applyAction(setTheme(o.data));
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
              await applyAction(setTimeoutSecs(o.data));
            }}
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title={t("boot_control")}>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            disabled={!status?.repair_needed || !status?.layout_safe}
            onClick={async () => {
              await applyAction(repairBootPriority(status?.layout_requires_confirmation === true));
            }}
          >
            {t("repair")}
          </ButtonItem>
        </PanelSectionRow>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={async () => {
              await applyAction(setService("disable"));
            }}
          >
            {t("boot_windows")}
          </ButtonItem>
        </PanelSectionRow>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={async () => {
              await applyAction(setService("enable"));
            }}
          >
            {t("reenable")}
          </ButtonItem>
        </PanelSectionRow>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={async () => {
              const result = await getMaintenanceLog();
              setMaintenanceLog(result.message);
              if (!result.ok) setActionMessage(`⚠ ${result.message}`);
            }}
          >
            {t("view_log")}
          </ButtonItem>
        </PanelSectionRow>
        {maintenanceLog && (
          <PanelSectionRow>
            <Field label={t("latest_log")}>{maintenanceLog}</Field>
          </PanelSectionRow>
        )}
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

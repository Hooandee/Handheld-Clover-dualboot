# Clover Dual Boot para portátiles, SteamOS / Bazzite + Windows

> 🇬🇧 Prefer English? Follow the English guide here: [README.en.md](README.en.md)

> 🚧 **Aviso:** hay una actualización gorda del proyecto en camino. Algunas cosas van a cambiar pronto, así que ten un poco de paciencia si algo no termina de cuadrar.

Instala [Clover](https://github.com/CloverHackyColor/CloverBootloader), un gestor de arranque gráfico, para tener SteamOS (o Bazzite) y Windows en el mismo equipo (y de paso otros sistemas) en la Steam Deck y en otras portátiles x86. El instalador detecta tu dispositivo, toca lo mínimo del sistema y añade un menú de arranque que se repara solo cuando una actualización de la BIOS, del sistema o de Windows te rompe las entradas de arranque.

Este proyecto parte del trabajo original de ryanrudolf, [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot). Aquí lo he ampliado para que funcione en más portátiles y para que instalarlo sea más sencillo.

## Qué incluye
* **Clover**, el gestor de arranque gráfico que hace el trabajo de verdad.
* **Clover Toolbox**, una interfaz sencilla para configurar Clover (temas, resolución, desinstalar y más cosas).
* **Servicio de arranque** que revisa el dual boot en cada inicio y repara solo las entradas si se rompen.
* **Controlador UEFI del mando XBOX 360** por [SkorionOS](https://github.com/SkorionOS/UsbXbox360Dxe) y [chenx-dust](https://github.com/chenx-dust/UsbXbox360Dxe), para que el mando integrado de las portátiles que no son Steam Deck funcione dentro del menú de Clover.
* **Tema Eclipse** de [chris1111](https://github.com/chris1111/).

## Dispositivos compatibles

| Portátil | Se detecta como | Resolución en Clover |
|---|---|---|
| Steam Deck LCD / OLED | `Jupiter` / `Galileo` | 1280x800 (por defecto) |
| ASUS ROG Ally | `RC71L` | 1920x1080 |
| ASUS ROG Ally X | `RC72LA` | 1920x1080 |
| ASUS ROG Xbox Ally | `RC73YA` | 1920x1080 |
| ASUS ROG Xbox Ally X | `RC73XA` | 1920x1080 |
| Lenovo Legion Go | `83E1` | 2560x1600 |
| Lenovo Legion Go 2 | `83N0` / `83N1` | 1920x1200 |
| Lenovo Legion Go S | `83L3` / `83Q2` / `83Q3` | 1920x1200 |
| OneXPlayer 2 Pro | `ONEXPLAYER 2 PRO ARP23P` | 2560x1600 |

¿Tienes **otra portátil**? Funciona en modo genérico: el instalador lee la resolución nativa del panel desde el kernel y te pregunta si quieres continuar, así que la mayoría de portátiles x86 se instalan sin tocar nada de código.

> ⚠️ **No compatible:** la Lenovo Legion Go S `83N6` está bloqueada porque el controlador UEFI del mando XBOX 360 no es compatible con ella.

### Usar el mando dentro del menú de Clover
En todas las portátiles menos la Steam Deck, el instalador añade el controlador UEFI del mando XBOX 360 para que el mando integrado funcione en el menú de arranque:
* **Cruceta**: moverse (teclas de flecha)
* **A** = Intro, **B** = Esc
* **Gatillo derecho** = clic izquierdo, **gatillo izquierdo** = clic derecho
* Si la cruceta no responde, usa el joystick izquierdo para mover el puntero del ratón.

Si Clover se queda colgado en una Legion Go (el controlador a veces se queda sondeando el mando), borra el controlador y reinicia:
```bash
sudo rm /esp/efi/clover/drivers/uefi/UsbXbox360Dxe.efi
```

## Aviso legal
Hazlo bajo tu propia responsabilidad. Esto se ofrece solo con fines educativos y de investigación, sin ninguna garantía.

## Instalación

### Requisitos, léelos primero
* **Instala SteamOS / Bazzite _antes_ que Windows.** El instalador no se ejecuta si Windows es el dueño de la partición EFI.
* **Desactiva el Secure Boot** en la BIOS/UEFI. Es obligatorio en las portátiles que no son Steam Deck (ROG Ally, Legion Go, etc.).
* **Pon una contraseña de sudo** en SteamOS / Bazzite. El instalador la necesita y se detiene si está en blanco.

### 1. Preparar Windows
Arranca en Windows, abre un Símbolo del sistema o PowerShell como administrador y ejecuta:
```cmd
bcdedit.exe -set "{globalsettings}" highestmode on
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
```

### 2. Instalar en SteamOS / Bazzite
Entra en el Modo Escritorio, abre una terminal (Konsole) y pega este comando de una sola línea:

```bash
cd ~ && rm -rf Handheld-Clover-dualboot && git clone https://github.com/Hooandee/Handheld-Clover-dualboot && cd Handheld-Clover-dualboot && chmod +x install-clover.sh && ./install-clover.sh
```

Borra cualquier copia anterior, clona el repositorio y lanza el instalador. El script comprueba tu contraseña de sudo y va haciendo verificaciones por el camino. Cuando termine, **reinicia** y verás el menú de Clover para elegir sistema (cruceta y **A** para confirmar).

<details>
<summary><b>Opcional: Windows en microSD o SSD externo</b></summary>

Si tienes Windows en una microSD o en un SSD externo, después de instalar ejecuta:
```bash
sudo cp custom/config_sdcard.plist /esp/efi/clover/config.plist
```

Si aun así Windows sigue secuestrando el arranque, configura la tarea programada en el lado de Windows: ejecuta `CloverWindows/CloverWindows.bat` como Administrador. Crea la carpeta `C:\1Clover-tools`, instala una tarea programada llamada `CloverTask-donotdelete` y, en el Programador de tareas, abre las propiedades de la tarea, marca **Ejecutar tanto si el usuario inició sesión como si no** y **No almacenar la contraseña**, y ejecútala una vez.
</details>

### Actualizar a una versión nueva
Abre Clover Toolbox, pulsa **Desinstalar**, vuelve a clonar el repositorio y repite la instalación.

## Problemas conocidos
**Pantalla externa por encima de 1080p (1440p, 4K).** La pantalla de Clover puede salir girada y Windows puede no arrancar o darte un pantallazo azul. Si puedes, usa una pantalla de 1080p o menos. Como apaño: Clover Toolbox, **Resolución**, opción **DeckSight** (ojo: esto gira la pantalla de Clover en el panel interno de la Deck cuando no hay pantalla externa conectada).

## Preguntas frecuentes (guía original, en proceso)
> Estas respuestas vienen del proyecto original [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot) y todavía las estoy revisando y adaptando a este fork. Algunos pasos son específicos de la Steam Deck y puede que aún no encajen con otras portátiles. Trabajo en proceso.

<details>
<summary><b>No detecta Windows en microSD o SSD externo</b></summary>
Asegúrate de haberlo preparado como GPT y Windows-To-Go en Rufus.
</details>

<details>
<summary><b>Windows arranca con líneas verticales o gráficos corruptos</b></summary>
En Windows (Símbolo del sistema como administrador): <code>bcdedit.exe -set {globalsettings} highestmode on</code>. Si sigue corrupto, arranca a Windows directamente una vez (Clover Toolbox, Service, Disable), arregla la pantalla y vuelve a activar el servicio.
</details>

<details>
<summary><b>Windows arranca directo en lugar de Clover (tras reinstalar o actualizar Windows)</b></summary>
Apaga el equipo. Con el equipo apagado, pulsa <b>VOL ABAJO + ENCENDIDO</b> y elige SteamOS. El servicio de arranque repara las entradas solo. Reinicia y vuelve Clover.
</details>

<details>
<summary><b>Una actualización de SteamOS me borró las entradas de arranque</b></summary>
Apaga el equipo. Con el equipo apagado, pulsa <b>VOL ARRIBA + ENCENDIDO</b> y entra en <b>Boot from File &gt; efi &gt; steamos &gt; steamcl.efi</b>. El servicio repara las entradas en el siguiente arranque.
</details>

<details>
<summary><b>El reloj se descuadra constantemente</b></summary>
En Windows (Símbolo del sistema como administrador): <code>reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f</code> y reinicia.
</details>

<details>
<summary><b>Me sale 'Error mounting ISO!' al ejecutar el script</b></summary>
Puede que a tu SteamOS le falte 7zip (suele pasar en instalaciones desde la imagen de recuperación). Haz una actualización del sistema (Steam, Ajustes, Sistema, Buscar actualizaciones), reinicia y vuelve a lanzar el script.
</details>

<details>
<summary><b>Quiero desinstalar Clover</b></summary>
Clover Toolbox, <b>Desinstalar</b>. En el siguiente reinicio arranca directo a Windows. Listo.
</details>

## Créditos
Basado en el proyecto original [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot).

Y mil gracias a la comunidad de mi canal, [youtube.com/c/hooandee](https://youtube.com/c/hooandee), por el apoyo de siempre. 💚

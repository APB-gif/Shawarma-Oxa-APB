# Instrucciones rápidas desde este chat

Este archivo contiene los comandos y pasos principales que discutimos en el chat. Puedes abrir este archivo en la otra laptop (tras clonar el repo) y copiar/pegar los comandos en PowerShell.

---

## Clonar el repositorio

Usa HTTPS (rápido):

```powershell
cd C:\ruta\donde\quieres\proyecto
git clone https://github.com/APB-gif/Shawarma-Oxa-APB.git
cd Shawarma-Oxa-APB
```

Si la carpeta actual está vacía y quieres clonar aquí:

```powershell
git clone https://github.com/APB-gif/Shawarma-Oxa-APB.git .
```

## Configurar identidad Git (una vez por laptop)

```powershell
git config --global user.name "Tu Nombre"
git config --global user.email "tu@correo"
```

## Obtener dependencias y ejecutar

```powershell
flutter pub get
flutter run
```

## Flujo de trabajo básico (crear rama y push)

```powershell
git checkout -b feature/mi-cambio
# editar archivos
git add .
git commit -m "feat: descripción breve"
git push -u origin feature/mi-cambio
```

## Backup de una carpeta antigua y clonar (si tenías proyecto anterior)

```powershell
cd 'C:\ruta\que\tiene\la\carpeta\antigua'
Rename-Item -Path 'proyecto-antiguo' -NewName "proyecto-antiguo-backup-$(Get-Date -Format yyyy-MM-dd-HH-mm)"
cd 'C:\ruta\donde\quieres\el\proyecto'
git clone https://github.com/APB-gif/Shawarma-Oxa-APB.git
cd Shawarma-Oxa-APB
flutter pub get
```

## Opcional: generar y usar llave SSH

```powershell
ssh-keygen -t ed25519 -C "tu@correo"
notepad $env:USERPROFILE\.ssh\id_ed25519.pub
# Copia el contenido y pégalo en GitHub > Settings > SSH and GPG keys
git clone git@github.com:APB-gif/Shawarma-Oxa-APB.git
```

## Instalar gh (opcional, útil)

```powershell
winget install --id GitHub.cli -e
gh auth login
```

---

Consejo: en la otra laptop abre VSCode, selecciona File → Open Folder y abre la carpeta `Shawarma-Oxa-APB`. El archivo `docs/CHAT_INSTRUCCIONES.md` estará ahí con los comandos listos para copiar.

Si quieres que copie TODO el contenido del chat (transcripción completa) al repo, dímelo y lo agrego en `docs/CHAT_TRANSCRIPT.md`.

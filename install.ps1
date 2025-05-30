#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automatisiert die Einrichtung einer lokalen Entwicklungsumgebung mit XAMPP und einem GitHub-Projekt.
.DESCRIPTION
    Dieses Skript führt folgende Aktionen aus:
    1. Installiert XAMPP (Version 8.2 angegeben).
    2. Installiert Git.
    3. Klont das GitHub-Repository "vrsestudio/gradelens" in den htdocs-Ordner von XAMPP.
    4. Deinstalliert Git.
    5. Startet die Apache- und MySQL-Dienste von XAMPP über Hilfsskripte.
    6. Führt ein 'creation.sql'-Skript (erwartet im geklonten Repository) über den MySQL-Client aus.

    WICHTIG:
    - Führen Sie dieses Skript als Administrator aus.
    - Überprüfen Sie die Variable '$XamppInstallDir', falls XAMPP an einem nicht standardmäßigen Ort installiert ist/wird.
    - Geht davon aus, dass der MySQL 'root'-Benutzer kein Passwort hat (Standard für XAMPP).
    - Internetverbindung ist für winget- und git-Operationen erforderlich.
#>

# --- Konfiguration ---
$XamppInstallDir = "C:\xampp" # WICHTIG: Überprüfen oder ändern Sie diesen Pfad, falls XAMPP woanders installiert wird/ist.
$ProjectRepoUrl = "https://github.com/vrsestudio/gradelens"
$ProjectFolderName = "gradelens" # Der Ordnername innerhalb von htdocs für das geklonte Projekt

# --- Skriptstart ---
Write-Host "Starte Skript zur Einrichtung der Entwicklungsumgebung..."
Write-Host "Stellen Sie sicher, dass dieses Skript mit Administratorrechten ausgeführt wird."
Write-Host "------------------------------------------------------------"

# --- Abgeleitete Pfade ---
$HtdocsDir = Join-Path -Path $XamppInstallDir -ChildPath "htdocs"
$ProjectDir = Join-Path -Path $HtdocsDir -ChildPath $ProjectFolderName
$SqlFileRelativePath = "creation.sql" # Relativ zu $ProjectDir
$SqlFileFullPath = Join-Path -Path $ProjectDir -ChildPath $SqlFileRelativePath
$MySqlBinDir = Join-Path -Path $XamppInstallDir -ChildPath "mysql\bin"
$MySqlClient = Join-Path -Path $MySqlBinDir -ChildPath "mysql.exe"
$ApacheStartScript = Join-Path -Path $XamppInstallDir -ChildPath "apache_start.bat"
$MySqlStartScript = Join-Path -Path $XamppInstallDir -ChildPath "mysql_start.bat"

# --- Hilfsfunktionen ---
function Test-CommandExists {
    param ([string]$command)
    return (Get-Command $command -ErrorAction SilentlyContinue) -ne $null
}

function Install-WingetPackage {
    param (
        [string]$PackageId,
        [string]$PackageName
    )
    Write-Host "Installiere $PackageName (ID: $PackageId)..."
    # Die ID "ApacheFriends.Xampp.8.2" ist spezifisch. Wenn nicht gefunden, könnte "ApacheFriends.XAMPP --version 8.2.x" eine Alternative sein.
    winget install --id $PackageId --accept-package-agreements --accept-source-agreements --source winget --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$PackageName Installation fehlgeschlagen mit Exit-Code: $LASTEXITCODE. Bitte winget-Logs prüfen oder manuell versuchen."
    } else {
        Write-Host "$PackageName erfolgreich installiert."
    }
}

function Uninstall-WingetPackage {
    param (
        [string]$PackageId,
        [string]$PackageName
    )
    Write-Host "Deinstalliere $PackageName (ID: $PackageId)..."
    winget uninstall --id $PackageId --accept-source-agreements --source winget --disable-interactivity --force
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "$PackageName Deinstallation möglicherweise fehlgeschlagen oder erforderte Interaktion (Exit-Code: $LASTEXITCODE). Ggf. manuell deinstallieren."
    } else {
        Write-Host "$PackageName erfolgreich deinstalliert."
    }
}

# --- Vorabprüfungen ---
if (-not (Test-CommandExists "winget")) {
    Write-Error "Winget-Befehl nicht gefunden. Bitte stellen Sie sicher, dass der App Installer (winget) installiert und im PATH ist."
    exit 1
}

# --- Hauptausführung ---

# 1. XAMPP installieren
Write-Host ""
Write-Host "Schritt 1: Installiere XAMPP..."
if (-not (Test-Path $XamppInstallDir -PathType Container)) {
    Install-WingetPackage -PackageId "ApacheFriends.Xampp.8.2" -PackageName "XAMPP 8.2"
    Write-Host "XAMPP-Installationsbefehl über winget abgesetzt."
    Write-Host "Der XAMPP-Installer erfordert möglicherweise Benutzereingaben (z.B. Sprache, Komponenten)."
    Write-Host "Bitte schließen Sie die XAMPP-Installation ab, falls entsprechende Fenster erscheinen."
    Write-Host "Das Skript geht davon aus, dass XAMPP nach '$XamppInstallDir' installiert wird."
    Write-Host "Falls ein anderer Pfad gewählt wird, passen Sie die Variable im Skript an und führen Sie es ggf. erneut aus."
    Write-Host "Pausiere für 60 Sekunden, um dem XAMPP-Installationsprozess Zeit für den Start und initiale Abfragen zu geben..."
    Start-Sleep -Seconds 60
    if (-not (Test-Path $XamppInstallDir -PathType Container)) {
        Write-Error "XAMPP-Installationsverzeichnis '$XamppInstallDir' nach Wartezeit nicht gefunden. Bitte stellen Sie sicher, dass XAMPP korrekt in diesen Pfad installiert wurde oder passen Sie das Skript an."
        # exit 1 # Auskommentiert, um Fortsetzung zu ermöglichen, falls Benutzer den Pfad später korrigiert.
    }
} else {
    Write-Host "XAMPP-Verzeichnis '$XamppInstallDir' existiert bereits. Überspringe XAMPP-Installation."
}

# Sicherstellen, dass das htdocs-Verzeichnis existiert, bevor fortgefahren wird
if (-not (Test-Path $HtdocsDir -PathType Container)) {
    Write-Error "XAMPP htdocs-Verzeichnis nicht unter '$HtdocsDir' gefunden. Möglicherweise wurde XAMPP nicht nach '$XamppInstallDir' installiert oder die Installation ist unvollständig. Bitte prüfen und erneut ausführen."
    # exit 1 # Auskommentiert, um Flexibilität zu ermöglichen.
} else {
    Write-Host "XAMPP htdocs-Verzeichnis unter '$HtdocsDir' bestätigt."
}

# 2. Git installieren
Write-Host ""
Write-Host "Schritt 2: Installiere Git..."
Install-WingetPackage -PackageId "Microsoft.Git" -PackageName "Git"
# Die Git-Installation über winget ist normalerweise nicht interaktiv mit den entsprechenden Flags.

# 3. GitHub-Repository klonen
Write-Host ""
Write-Host "Schritt 3: Klone GitHub-Repository '$ProjectRepoUrl'..."
if (-not (Test-Path $HtdocsDir -PathType Container)) {
     Write-Error "Kann Repository nicht klonen, da das htdocs-Verzeichnis '$HtdocsDir' nicht existiert. Stellen Sie sicher, dass XAMPP korrekt installiert ist."
} elseif (Test-Path $ProjectDir -PathType Container) {
    Write-Warning "Projektverzeichnis '$ProjectDir' existiert bereits. Überspringe Klonen. Für eine frische Kopie löschen Sie bitte den Ordner und führen das Skript erneut aus."
} else {
    Write-Host "Klone nach '$ProjectDir'..."
    try {
        # Versuche, git aus dem PATH zu verwenden.
        # Nach der Installation von Git ist möglicherweise eine neue PowerShell-Sitzung erforderlich, damit 'git' überall im PATH verfügbar ist.
        # Für die direkte Verwendung im Skript sollte es jedoch meist funktionieren.
        git clone $ProjectRepoUrl $ProjectDir
        if ($LASTEXITCODE -ne 0) { # $LASTEXITCODE für externe Befehle prüfen
            Write-Error "Git clone fehlgeschlagen. Exit-Code: $LASTEXITCODE. Stellen Sie sicher, dass Git installiert ist und '$ProjectRepoUrl' erreichbar ist."
        } else {
            Write-Host "Repository erfolgreich nach '$ProjectDir' geklont."
        }
    } catch {
        Write-Error "Ein Fehler ist beim Klonen via Git aufgetreten: $($_.Exception.Message)"
        Write-Warning "Stellen Sie sicher, dass Git installiert und im PATH verfügbar ist. Ein Neustart von PowerShell könnte nach der Git-Installation erforderlich sein."
    }
}

# 4. Git deinstallieren
Write-Host ""
Write-Host "Schritt 4: Deinstalliere Git..."
Uninstall-WingetPackage -PackageId "Microsoft.Git" -PackageName "Git"

# 5. XAMPP-Dienste starten (Apache & MySQL)
Write-Host ""
Write-Host "Schritt 5: Starte XAMPP Apache- und MySQL-Dienste..."

# Prüfen, ob Startskripte vorhanden sind
if (-not (Test-Path $ApacheStartScript -PathType Leaf)) {
    Write-Error "Apache-Startskript nicht gefunden: '$ApacheStartScript'. Apache kann nicht gestartet werden."
} else {
    Write-Host "Starte Apache-Dienst..."
    Start-Process -FilePath $ApacheStartScript -WindowStyle Minimized
    Write-Host "Apache-Startbefehl abgesetzt."
}

if (-not (Test-Path $MySqlStartScript -PathType Leaf)) {
    Write-Error "MySQL-Startskript nicht gefunden: '$MySqlStartScript'. MySQL kann nicht gestartet werden."
} else {
    Write-Host "Starte MySQL-Dienst..."
    Start-Process -FilePath $MySqlStartScript -WindowStyle Minimized
    Write-Host "MySQL-Startbefehl abgesetzt."
}

Write-Host "Warte 30 Sekunden, damit die Dienste initialisieren können..."
Start-Sleep -Seconds 30 # Anpassen, falls Dienste länger zum Starten benötigen

# 6. SQL-Skript über MySQL-Client ausführen
Write-Host ""
Write-Host "Schritt 6: Führe SQL-Setup-Skript '$SqlFileFullPath' aus..."

if (-not (Test-Path $ProjectDir -PathType Container)) {
    Write-Error "Projektverzeichnis '$ProjectDir' nicht gefunden. SQL-Skript kann nicht lokalisiert werden."
} elseif (-not (Test-Path $SqlFileFullPath -PathType Leaf)) {
    Write-Error "SQL-Skript '$SqlFileFullPath' nicht im Projektverzeichnis gefunden."
} elseif (-not (Test-Path $MySqlClient -PathType Leaf)) {
    Write-Error "MySQL-Client '$MySqlClient' nicht gefunden. Stellen Sie sicher, dass XAMPP korrekt installiert und der Pfad gesetzt ist."
} else {
    Write-Host "Versuche, SQL-Skript auszuführen. Dies setzt voraus, dass der MySQL 'root'-Benutzer kein Passwort hat (XAMPP-Standard)."
    
    # Pfad für MySQL anpassen (MySQL bevorzugt Forward-Slashes) und für den Befehl korrekt quoten.
    $SqlFilePathForMySql = $SqlFileFullPath.Replace('\', '/')
    $MySqlStatement = "SOURCE `'$SqlFilePathForMySql`'" # Der Pfad wird in einfache Anführungszeichen für MySQL gesetzt.

    # Überprüfen, ob der MySQL-Dienst tatsächlich läuft (einfache Prüfung, nicht narrensicher)
    $mysqlProcess = Get-Process mysqld -ErrorAction SilentlyContinue
    if (-not $mysqlProcess) {
        Write-Warning "MySQL-Prozess (mysqld) nicht erkannt. Die SQL-Skriptausführung könnte fehlschlagen."
        Write-Warning "Bitte stellen Sie sicher, dass MySQL erfolgreich über das XAMPP Control Panel oder die Skripte gestartet wurde."
    }

    try {
        # Den Befehl direkt mit dem Call-Operator '&' und Argumenten ausführen.
        & $MySqlClient -u "root" --execute=$MySqlStatement
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Ausführung des MySQL-Skripts fehlgeschlagen. Exit-Code: $LASTEXITCODE."
            Write-Warning "Tipps: "
            Write-Warning " - Stellen Sie sicher, dass der MySQL-Dienst läuft."
            Write-Warning " - Prüfen Sie, ob der 'root'-Benutzer ein Passwort hat (Skript nimmt keines an)."
            Write-Warning " - Überprüfen Sie den Inhalt von '$SqlFileFullPath' auf SQL-Fehler."
            Write-Warning " - Das SQL-Skript sollte die Datenbankerstellung/-auswahl selbst behandeln (z.B. CREATE DATABASE dbname; USE dbname;)."
        } else {
            Write-Host "SQL-Skript erfolgreich ausgeführt."
        }
    } catch {
        Write-Error "Ein Fehler ist bei der Ausführung des SQL-Skripts mit '$MySqlClient' aufgetreten: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "Setup-Skript beendet."
Write-Host "Zur Überprüfung:"
Write-Host "1. Öffnen Sie das XAMPP Control Panel und prüfen Sie, ob die Apache- und MySQL-Dienste laufen (grün)."
Write-Host "2. Greifen Sie auf das Projekt zu unter: http://localhost/$ProjectFolderName"
Write-Host "3. Überprüfen Sie Ihre MySQL-Datenbanken (z.B. via phpMyAdmin unter http://localhost/phpmyadmin) auf die durch '$SqlFileRelativePath' erstellten Tabellen."
Write-Host "Bei Problemen überprüfen Sie die Skriptausgabe auf Fehler und die XAMPP-Logs."
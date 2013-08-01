#!/bin/bash



# Backup Script fuer taegliche Backups mit rsnapshot & tar
# rsnapshot mit optionaler Benachrichtigung auf den Desktop eines Users
# Zur Benutzung mit cron als root
#
# Erfordert rsnapshot, libnotify, perl-Lchown, tar, mt, mcrypt
#
# --> HDD fuer rsnapshot Daten in der /etc/fstab eintragen!
# --> Anpassung der /etc/rsnapshot.conf nicht vergessen!
#     Bitte passendes Beispiel conf Datei beachten (s.u.) 
#
# Sppedpoint nG GmbH (FW,JP), Stand: Juli 2013



### Folgende Werte bitte anpassen: #############################################
#
user=david                             # Empfaenger fuer Nachrichten & Mails
message=true                           # Desktop Benachrichtigung senden? 
#
volume=/dev/sdc1                       # Partition fuer rsnapshot Backups
hdd=/mnt/snapshots                     # Mountpoint fuer Snapshot Partition
hddout=true                            # nach rsnapshot aushaengen?
godown=false                            # Shutdown nach Backup?
#
mirror=true                            # Sync der Spiegelplatte vor dem Backup
toolpfad=/install/skripte
tool=mirror_hdd.sh                     # Pfad & Name des Sync Scripts
#
### Ende der Anpassungen #######################################################






# Ab hier bitte Finger weg!





echo ""

# Duerfen wir das alles?
if [ "$(id -u)" != "0" ]; then
   echo "ABBRUCH, Ausfuehrung nur durch root!" 
   echo "Script als root starten!" | mail -s "WARNUNG: Backup nicht korrekt konfiguriert!" $user@localhost
   echo ""
   exit 1
fi

# Fuer Display Benachrichtigungen
export DISPLAY=:0.0 ;
export XAUTHORITY=$(/usr/bin/find /var/run/gdm -path "*$user*/database") ;

# Fehlerlog anlegen
jetzt=`date`
errorlog="$hdd/Fehler.manuell.log"

# Wurde die config fuer rsnapshot korrekt angegeben?
if   [ ! -e /etc/rsnapshot.manuell.conf ]; then
	 echo "/etc/rsnapshot.manuell.conf nicht gefunden." 2>>$errorlog
	 if $message ; then
		su - $user -c "notify-send 'WARNUNG: Konfigurationsdatei nicht gefunden!' -i /usr/share/icons/gnome/32x32/status/dialog-error.png"
	 fi
fi


# Schritt 0: HDD 1 auf Spiegelplatte synchronisieren ---------------------------
if $mirror ; then 
   hier=`pwd`2>>$errorlog
   if $message ; then 
	  su - $user -c "notify-send 'Spiegelplatte wird aktualisiert...' -i /usr/share/icons/gnome/32x32/actions/go-jump.png --hint=int:transient:1"
   fi
   echo "Spiegelplatte wird synchronisiert..." 2>>$errorlog
   cd $toolpfad 2>>$errorlog
   sh $tool 2>>$errorlog
   if [ ! $? -eq 0 ]; then
      echo "WARNUNG: Fehler beim Synchronisieren der Spiegelplatte!" 2>>$errorlog
   fi
   cd $hier 2>>$errorlog
else
   echo "Synchronisation der HDDs nicht aktiviert." 2>>$errorlog
fi   


# Schritt 1: Lokalen Snapshot erstellen ----------------------------------------

# rsnapshot HDD ggf. einhaengen
mount | grep "on ${volume} type" > /dev/null 
if [ $? -ne 0 ]; then 
   mount $volume &> /dev/null 2>>$errorlog
fi

# Startnachricht an User
if $message ; then
   su - $user -c "notify-send 'Starte Backup auf Festplatte...' -i /usr/share/icons/gnome/32x32/actions/go-jump.png --hint=int:transient:1"
fi
echo "Starte Backup auf die Festplatte..." 2>>$errorlog

here=`pwd` 2>>$errorlog
cd /home/david 2>>$errorlog
./iquit 2>>$errorlog

# Snapshot erstellen
rsnapshot -c /etc/rsnapshot.manuell.conf -v manuell 2>>$errorlog

if [ $? -eq 0 ]; then
   backup_success=true
else
   backup_success=false
fi

./isam 2>>$errorlog
cd $here 2>>$errorlog

# Erfolgsmeldung auf Desktop
if  $backup_success ; then
		if $message ; then
			su - $user -c "notify-send 'Backup erfolgreich :-)' -i /usr/share/icons/gnome/32x32/emblems/emblem-default.png --hint=int:transient:1"
		fi
	echo "Backup erfolgreich :-)" | mail -s "Quickbackup erfolgreich beendet :-)" $user@localhost 2>>$errorlog
else
		if $message ; then
			su - $user -c "notify-send 'WARNUNG: Backup mit Fehlern beendet :-(    Bitte $errorlog beachten!' -i /usr/share/icons/gnome/32x32/status/dialog-error.png"
		fi
	echo "Backup fehlgeschlagen :-(" | mail -s "Quickbackup fehlgeschlagen :-(" $user@localhost 2>>$errorlog
fi



# HDD ggf. aushaengen
if $hddout ; then
   cd && sleep 5	
   umount $volume &> /dev/null 2>>$errorlog
fi

if $godown ; then
   su - $user -c "notify-send 'Das System schaltet in 20 Sekunden ab...' -i /usr/share/icons/gnome/32x32/actions/go-jump.png --hint=int:transient:1"
   ansage="Das System schaltet in 20 Sekunden ab..."
   echo $ansage && sleep 20
   /sbin/shutdown -h now
fi
echo ""

exit 0

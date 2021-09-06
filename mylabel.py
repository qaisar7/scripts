#!/usr/bin/env python3
import signal
import os
import sys
import datetime
import gi
import getpass

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')

import time
from threading import Thread
from gi.repository import Gtk, AppIndicator3, GObject, GLib

user=os.popen('logname').read()[0:-1]
print("The user is %s" % user)
fileName = datetime.date.today().strftime("%Y_%m_%d.time")
filePath = "/home/"+user+"/times/"+fileName

def readMinutesLeft():
    minutesFile = open(filePath,'r')
    m = minutesFile.readline()
    minutesFile.close()
    return m.split()

class Indicator():
    def __init__(self):
        self.app = 'test123'
        iconpath = "/home/qaisar/Downloads/leaf.png"
        self.indicator = AppIndicator3.Indicator.new(
            self.app, iconpath,
            AppIndicator3.IndicatorCategory.OTHER)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.create_menu())
        self.indicator.set_label("---", self.app)
        # the thread:
        self.update = Thread(target=self.show_seconds)
        # daemonize the thread to make the indicator stopable
        self.update.setDaemon(True)
        self.update.start()

    def create_menu(self):
        menu = Gtk.Menu()
        menu_sep = Gtk.SeparatorMenuItem()
        menu.append(menu_sep)
        # start squid
        item_squid = Gtk.MenuItem(label='Internet')
        item_squid.connect('activate', self.start_squid)
        menu.append(item_squid)
        # quit
        item_quit = Gtk.MenuItem(label='Quit')
        item_quit.connect('activate', self.stop)
        menu.append(item_quit)

        menu.show_all()
        return menu

    def show_seconds(self):
        while True:
            mention = '--'
            if user != 'qaisar1':
                l = readMinutesLeft()
                mention = l[0] + " mins (" + l[1]+")"
            # apply the interface update using  GObject.idle_add()
            GLib.idle_add(
                self.indicator.set_label,
                mention, self.app,
                priority=GLib.PRIORITY_DEFAULT
                )
            time.sleep(5)

    def stop(self, source):
        os.system("sudo /home/qaisar/scripts/logout.sh " + user )
        sys.exit(0)

    def start_squid(self, source):
        os.system("sudo /home/qaisar/scripts/restartSquid.sh")

import os, signal

def kill_process(pstring):
    # Kills every process except the last one.
    lines = os.popen("ps ax | grep " + pstring + " | grep -v grep").readlines()
    for i in range(len(lines)):
        print(lines[i])
        if i == len(lines)-1:
            continue
        fields = lines[i].split()
        pid = fields[0]
        os.kill(int(pid), signal.SIGKILL)

kill_process("/usr/local/bin/mylabel.py")
Indicator()
signal.signal(signal.SIGINT, signal.SIG_DFL)
Gtk.main()

